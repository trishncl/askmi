import '../../models/menu_item_model.dart';
import '../../models/sale_transaction_model.dart';

/// One line in the cashier's in-progress cart — a menu item plus how many
/// the cashier has tapped in. Distinct from [SaleLineItem]: this one still
/// carries the live [MenuItemModel] (for re-checking active/outOfStock right
/// up to checkout), where SaleLineItem is the frozen, already-sold record.
class CartItem {
  final MenuItemModel menuItem;
  final int quantity;

  const CartItem({required this.menuItem, required this.quantity});

  double get subtotal => menuItem.price * quantity;

  CartItem copyWith({int? quantity}) =>
      CartItem(menuItem: menuItem, quantity: quantity ?? this.quantity);

  SaleLineItem toSaleLineItem() => SaleLineItem(
        menuItemId: menuItem.id,
        name: menuItem.name,
        category: menuItem.category,
        unitPrice: menuItem.price,
        quantity: quantity,
      );
}
