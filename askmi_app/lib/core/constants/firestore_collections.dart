/// Collection name constants matching the finalized Firestore schema
/// (AA_Lomi_Firestore_Schema.docx). Use these instead of typing collection
/// name strings directly — a typo in a raw string ("usres") silently
/// creates a new empty collection instead of erroring.
class FirestoreCollections {
  FirestoreCollections._();

  static const users = 'users';
  static const sales = 'sales';
  static const products = 'products'; // movement tracking, NOT the POS catalog
  static const inventory = 'inventory';
  static const menuItems = 'menuItems'; // POS catalog — separate from products
  static const branches = 'branches';
  static const reports = 'reports';
  static const notifications = 'notifications';
}
