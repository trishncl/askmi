import 'package:flutter/foundation.dart';
import '../../models/menu_item_model.dart';
import '../../models/sale_transaction_model.dart';
import 'cart_item.dart';

enum PosPaymentSelection { cash, gcash }

extension PosPaymentSelectionValue on PosPaymentSelection {
  String get storedValue =>
      this == PosPaymentSelection.cash ? PosPaymentMethod.cash : PosPaymentMethod.gcash;
}

/// All in-progress POS state for one checkout: cart lines, payment method,
/// and (for Cash) the amount tendered.
///
/// A plain ChangeNotifier consumed via `provider` — the same
/// state-management approach AuthState/BranchScope already use in this app
/// (see app_providers.dart), rather than introducing a second state
/// framework just for this screen. Scoped to CashierPosPage's lifetime via
/// ChangeNotifierProvider, so it resets automatically if the cashier
/// navigates away mid-sale.
class PosCartController extends ChangeNotifier {
  final Map<String, CartItem> _lines = {}; // keyed by menuItem.id

  List<CartItem> get lines => _lines.values.toList(growable: false);
  bool get isEmpty => _lines.isEmpty;
  int get totalQuantity => _lines.values.fold(0, (sum, l) => sum + l.quantity);
  double get subtotal => _lines.values.fold(0.0, (sum, l) => sum + l.subtotal);
  double get total => subtotal; // no tax/discount modeled in this schema

  PosPaymentSelection paymentMethod = PosPaymentSelection.cash;
  double cashReceived = 0;

  double get change => paymentMethod == PosPaymentSelection.cash
      ? (cashReceived - total).clamp(0, double.infinity)
      : 0;

  /// The single gate the Checkout button is disabled/enabled on.
  bool get isPaymentValid {
    if (isEmpty) return false;
    if (paymentMethod == PosPaymentSelection.gcash) return true;
    return total > 0 && cashReceived >= total;
  }

  int quantityFor(String menuItemId) => _lines[menuItemId]?.quantity ?? 0;

  void add(MenuItemModel item) {
    final existing = _lines[item.id];
    _lines[item.id] = existing == null
        ? CartItem(menuItem: item, quantity: 1)
        : existing.copyWith(quantity: existing.quantity + 1);
    notifyListeners();
  }

  void increment(String menuItemId) {
    final existing = _lines[menuItemId];
    if (existing == null) return;
    _lines[menuItemId] = existing.copyWith(quantity: existing.quantity + 1);
    notifyListeners();
  }

  /// Quantity 1 → 0 removes the line entirely, same as tapping Remove.
  void decrement(String menuItemId) {
    final existing = _lines[menuItemId];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      _lines.remove(menuItemId);
    } else {
      _lines[menuItemId] = existing.copyWith(quantity: existing.quantity - 1);
    }
    notifyListeners();
  }

  void removeLine(String menuItemId) {
    _lines.remove(menuItemId);
    notifyListeners();
  }

  /// Drops any line whose menu item is no longer sellable (hidden, marked
  /// out of stock, or no longer scoped to this branch since the cart was
  /// built) — called right before checkout so a stale cart can't ring up an
  /// item the stream has since disqualified. Returns the names removed, so
  /// the caller can tell the cashier what changed.
  List<String> pruneUnsellable(List<MenuItemModel> currentMenu, String branch) {
    final byId = {for (final m in currentMenu) m.id: m};
    final removed = <String>[];
    for (final id in _lines.keys.toList()) {
      final fresh = byId[id];
      if (fresh == null || !fresh.isSellableAt(branch)) {
        removed.add(_lines[id]!.menuItem.name);
        _lines.remove(id);
      } else if (fresh.price != _lines[id]!.menuItem.price) {
        // Price changed since it was added — keep the line but refresh it
        // to the current price so the receipt reflects what's charged now.
        _lines[id] = CartItem(menuItem: fresh, quantity: _lines[id]!.quantity);
      }
    }
    if (removed.isNotEmpty) notifyListeners();
    return removed;
  }

  void clear() {
    _lines.clear();
    paymentMethod = PosPaymentSelection.cash;
    cashReceived = 0;
    notifyListeners();
  }

  void setPaymentMethod(PosPaymentSelection method) {
    paymentMethod = method;
    if (method == PosPaymentSelection.gcash) cashReceived = 0;
    notifyListeners();
  }

  void setCashReceived(double amount) {
    cashReceived = amount;
    notifyListeners();
  }
}
