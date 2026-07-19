/// Keep in sync with askmi_app/functions/lib/role_permissions.js
const Map<String, Map<String, bool>> kRolePermissions = {
  'Owner': {
    'dashboard_view': true,
    'sales_view': true,
    'sales_manage': true,
    'inventory_view': true,
    'inventory_manage': true,
    'products_view': true,
    'products_manage': true,
    'reports_view': true,
    'reports_export': true,
    'branches_view': true,
    'users_view': true,
    'users_manage': true,
    'settings_manage': true,
  },
  'Manager': {
    'dashboard_view': true,
    'sales_view': true,
    'sales_manage': true,
    'inventory_view': true,
    'inventory_manage': true,
    'products_view': true,
    'products_manage': false,
    'reports_view': true,
    'reports_export': false,
    'branches_view': true,
    'users_view': true,
    'users_manage': false,
    'settings_manage': false,
  },
  'Cashier': {
    'dashboard_view': true,
    'sales_view': true,
    'sales_manage': true,
    'inventory_view': true,
    'inventory_manage': false,
    'products_view': true,
    'products_manage': false,
    'reports_view': false,
    'reports_export': false,
    'branches_view': false,
    'users_view': false,
    'users_manage': false,
    'settings_manage': false,
  },
};

const Map<String, String> kPermissionLabels = {
  'dashboard_view': 'Dashboard',
  'sales_view': 'Sales View',
  'sales_manage': 'Sales Manage',
  'inventory_view': 'Inventory View',
  'inventory_manage': 'Inventory Manage',
  'products_view': 'Products View',
  'products_manage': 'Products Manage',
  'reports_view': 'Reports View',
  'reports_export': 'Reports Export',
  'branches_view': 'Branches View',
  'users_view': 'Users View',
  'users_manage': 'Users Manage',
  'settings_manage': 'Settings Manage',
};

Map<String, bool> defaultPermissionsForRole(String role) {
  final normalized = role == 'Staff' ? 'Cashier' : role;
  return Map<String, bool>.from(
    kRolePermissions[normalized] ?? kRolePermissions['Cashier']!,
  );
}