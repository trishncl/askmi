// Mirrors lib/core/constants/role_permissions.dart on the Flutter side.
const ROLE_PERMISSIONS = {
  Owner: {
    dashboard_view: true,
    sales_view: true,
    sales_manage: true,
    inventory_view: true,
    inventory_manage: true,
    products_view: true,
    products_manage: true,
    reports_view: true,
    reports_export: true,
    branches_view: true,
    users_view: true,
    users_manage: true,
    settings_manage: true,
  },
  Manager: {
    dashboard_view: true,
    sales_view: true,
    sales_manage: true,
    inventory_view: true,
    inventory_manage: true,
    products_view: true,
    products_manage: false,
    reports_view: true,
    reports_export: false,
    branches_view: true,
    users_view: true,
    users_manage: false,
    settings_manage: false,
  },
  Cashier: {
    dashboard_view: true,
    sales_view: true,
    sales_manage: true,
    inventory_view: true,
    inventory_manage: false,
    products_view: true,
    products_manage: false,
    reports_view: false,
    reports_export: false,
    branches_view: false,
    users_view: false,
    users_manage: false,
    settings_manage: false,
  },
  // Legacy alias — old docs / requests may still say Staff
  Staff: null,
};

function defaultPermissionsForRole(role) {
  const normalized = role === "Staff" ? "Cashier" : role;
  return ROLE_PERMISSIONS[normalized] || ROLE_PERMISSIONS.Cashier;
}

module.exports = { defaultPermissionsForRole };