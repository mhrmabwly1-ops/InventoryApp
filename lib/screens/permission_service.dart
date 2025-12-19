class PermissionService {
  String roleName = 'مستخدم';
  Map<String, bool> permissions = {};

  // الخصائص الرئيسية
  bool get canManageProducts => _checkPermission('manage_products');
  bool get canManageCustomers => _checkPermission('manage_customers');
  bool get canManageSuppliers => _checkPermission('manage_suppliers');
  bool get canManageWarehouses => _checkPermission('manage_warehouses');
  bool get canManageUsers => _checkPermission('manage_users');
  bool get canViewReports => _checkPermission('view_reports');
  bool get canManageFinancial => _checkPermission('manage_financial');
  bool get canManageInventory => _checkPermission('manage_inventory');
  bool get canCreateSaleInvoices => _checkPermission('create_sale_invoices');
  bool get canCreatePurchaseInvoices => _checkPermission('create_purchase_invoices');
  bool get canManageSettings => _checkPermission('manage_settings');

  bool get canAccessSystemSettings => _checkPermission('manage_settings');

  void setUserPermissions(String role) {
    // مسح جميع الصلاحيات أولاً
    permissions.clear();

    switch (role.toLowerCase()) {
      case 'admin':
        roleName = 'مدير النظام';
        // إعطاء جميع الصلاحيات للمدير
        permissions = {
          'manage_products': true,
          'manage_customers': true,
          'manage_suppliers': true,
          'manage_warehouses': true,
          'manage_users': true,
          'view_reports': true,
          'manage_financial': true,
          'manage_inventory': true,
          'create_sale_invoices': true,
          'create_purchase_invoices': true,
          'manage_settings': true, // إضافة صلاحية الإعدادات
        };
        break;

      case 'manager':
        roleName = 'مدير';
        permissions = {
          'manage_products': true,
          'manage_customers': true,
          'manage_suppliers': true,
          'manage_warehouses': true,
          'manage_users': false,
          'view_reports': true,
          'manage_financial': true,
          'manage_inventory': true,
          'create_sale_invoices': true,
          'create_purchase_invoices': true,
          'manage_settings': true, // مدير النظام له صلاحيات الإعدادات
        };
        break;

      case 'cashier':
        roleName = 'أمين الصندوق';
        permissions = {
          'manage_products': false,
          'manage_customers': true,
          'manage_suppliers': false,
          'manage_warehouses': false,
          'manage_users': false,
          'view_reports': true,
          'manage_financial': true,
          'manage_inventory': false,
          'create_sale_invoices': true,
          'create_purchase_invoices': false,
          'manage_settings': false, // أمين الصندوق ليس له صلاحيات الإعدادات
        };
        break;

      case 'warehouse':
        roleName = 'مسؤول مخازن';
        permissions = {
          'manage_products': true,
          'manage_customers': false,
          'manage_suppliers': true,
          'manage_warehouses': true,
          'manage_users': false,
          'view_reports': true,
          'manage_financial': false,
          'manage_inventory': true,
          'create_sale_invoices': false,
          'create_purchase_invoices': true,
          'manage_settings': false,
        };
        break;

      case 'viewer':
        roleName = 'مراجع';
        permissions = {
          'manage_products': false,
          'manage_customers': false,
          'manage_suppliers': false,
          'manage_warehouses': false,
          'manage_users': false,
          'view_reports': true,
          'manage_financial': false,
          'manage_inventory': false,
          'create_sale_invoices': false,
          'create_purchase_invoices': false,
          'manage_settings': false,
        };
        break;

      default:
        roleName = 'مستخدم عادي';
        permissions = {
          'manage_products': false,
          'manage_customers': false,
          'manage_suppliers': false,
          'manage_warehouses': false,
          'manage_users': false,
          'view_reports': false,
          'manage_financial': false,
          'manage_inventory': false,
          'create_sale_invoices': false,
          'create_purchase_invoices': false,
          'manage_settings': false,
        };
    }

    print('✅ تم تعيين صلاحيات المستخدم: $roleName');
    print('🔐 الصلاحيات الممنوحة: $permissions');
  }

  bool _checkPermission(String permission) {
    return permissions[permission] ?? false;
  }

  // دالة للحصول على قائمة بالصلاحيات النشطة
  List<String> getActivePermissions() {
    return permissions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}