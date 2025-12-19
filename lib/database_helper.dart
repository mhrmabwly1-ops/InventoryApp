import 'dart:convert';
import 'dart:io';
import "package:sqflite/sqflite.dart";
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class DatabaseHelper {
  static Database? _db;
  double safeParseDouble(dynamic value) => _safeParse<double>(value, 0.0);

  int safeParseInt(dynamic value) => _safeParse<int>(value, 0);

  T _safeParse<T>(dynamic value, T defaultValue) {
    if (value == null) return defaultValue;

    if (T == double) {
      if (value is double) return value as T;
      if (value is int) return value.toDouble() as T;
      if (value is String) return double.tryParse(value) as T? ?? defaultValue;
    }

    if (T == int) {
      if (value is int) return value as T;
      if (value is double) return value.toInt() as T;
      if (value is String) return int.tryParse(value) as T? ?? defaultValue;
    }

    return defaultValue;
  }

  Future<Database> get database async => _db ??= await initDb();

  Future<Database> initDb() async {
    String path = join(await getDatabasesPath(), 'inventory_system.db');

    _db = await openDatabase(
      path,
      version: 11,
      onCreate: _createAllTables,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    return _db!;
  }

  Future<void> _createAllTables(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');

    // 1. جدول المخازن
    await db.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        code TEXT UNIQUE,
        address TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 2. جدول الموردين
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        balance REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 3. جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        tax_number TEXT,
        balance REAL DEFAULT 0,
        credit_limit REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 4. جدول الفئات
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        parent_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (parent_id) REFERENCES categories (id)
      )
    ''');

    // 5. جدول المنتجات
    // في قسم إنشاء جدول products، أضف هذه الحقول:
    await db.execute('''
  CREATE TABLE products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode TEXT UNIQUE,
    name TEXT NOT NULL,
    description TEXT,
    category_id INTEGER,
    supplier_id INTEGER,
    unit TEXT DEFAULT 'قطعة',
    purchase_price REAL DEFAULT 0,
    sell_price REAL DEFAULT 0,
    min_stock_level INTEGER DEFAULT 0,
    initial_quantity INTEGER DEFAULT 0,
    current_quantity INTEGER DEFAULT 0,
    last_purchase_date TEXT,
    image_path TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories (id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
  )
''');
    // أضف هذا الجدول بعد جدول products:
    await db.execute('''
  CREATE TABLE product_movements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    supplier_id INTEGER,
    movement_type TEXT CHECK(movement_type IN ('purchase', 'sale', 'return', 'adjustment', 'transfer')) NOT NULL,
    quantity INTEGER NOT NULL,
    price REAL,
    total_amount REAL,
    reference_type TEXT,
    reference_id INTEGER,
    notes TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products (id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
  )
''');

    // 6. جدول مخزون المنتجات في المخازن
    await db.execute('''
      CREATE TABLE warehouse_stock (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (product_id) REFERENCES products (id),
        UNIQUE(warehouse_id, product_id)
      )
    ''');

    // 7. جدول فواتير الشراء
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER NOT NULL,
        warehouse_id INTEGER NOT NULL,
        total_amount REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        notes TEXT,
        invoice_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id)
      )
    ''');

    // 8. جدول بنود فواتير الشراء
    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 9. جدول فواتير البيع
    // 9. جدول فواتير البيع - النسخة المحدثة
    await db.execute('''
  CREATE TABLE sale_invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_number TEXT UNIQUE NOT NULL,
    customer_id INTEGER,
    warehouse_id INTEGER NOT NULL,
    sub_total REAL NOT NULL DEFAULT 0 CHECK(sub_total >= 0),
    discount_amount REAL DEFAULT 0 CHECK(discount_amount >= 0),
    discount_percent REAL DEFAULT 0 CHECK(discount_percent BETWEEN 0 AND 100),
    tax_amount REAL DEFAULT 0 CHECK(tax_amount >= 0),
    tax_percent REAL DEFAULT 0 CHECK(tax_percent BETWEEN 0 AND 100),
    total_amount REAL NOT NULL DEFAULT 0 CHECK(total_amount >= 0),
    paid_amount REAL DEFAULT 0 CHECK(paid_amount >= 0),
    remaining_amount REAL DEFAULT 0 CHECK(remaining_amount >= 0),
    
    -- الأعمدة الجديدة:
    due_date TEXT,               
    transfer_reference TEXT,         
    transfer_bank TEXT,              
    transfer_date TEXT,         
    guarantee_details TEXT,          
    cash_received INTEGER DEFAULT 0, 
    transfer_confirmed INTEGER DEFAULT 0, 
    
    payment_method TEXT NOT NULL CHECK(payment_method IN ('cash', 'transfer', 'credit')),
    status TEXT NOT NULL DEFAULT 'draft' CHECK(status IN (
      'draft', 'pending', 'approved', 'cancelled', 'partial', 'refunded'
    )),
    notes TEXT,
    invoice_date TEXT NOT NULL,
    created_by INTEGER NOT NULL,
    approved_by INTEGER,
    approved_at TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
    FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE RESTRICT,
    FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE RESTRICT,
    FOREIGN KEY (approved_by) REFERENCES users (id) ON DELETE SET NULL,
    CHECK(paid_amount <= total_amount),
    CHECK(total_amount = sub_total - discount_amount + tax_amount)
  )
''');
    // 10. جدول بنود فواتير البيع
    await db.execute('''
  CREATE TABLE sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_invoice_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    unit_price REAL NOT NULL CHECK(unit_price >= 0),
    unit_cost REAL NOT NULL CHECK(unit_cost >= 0),
    discount_amount REAL DEFAULT 0 CHECK(discount_amount >= 0),
    discount_percent REAL DEFAULT 0 CHECK(discount_percent BETWEEN 0 AND 100),
    tax_amount REAL DEFAULT 0 CHECK(tax_amount >= 0),
    tax_percent REAL DEFAULT 0 CHECK(tax_percent BETWEEN 0 AND 100),
    net_price REAL DEFAULT 0,
    total_price REAL DEFAULT 0,
    profit REAL DEFAULT 0,
    total_cost REAL DEFAULT 0,  
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sale_invoice_id) REFERENCES sale_invoices (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT,
    UNIQUE(sale_invoice_id, product_id),
    CHECK(discount_amount <= unit_price),
    CHECK(unit_price >= unit_cost)
  )
''');
    // 11. جدول مرتجعات البيع
    await db.execute('''
      CREATE TABLE sale_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_number TEXT UNIQUE NOT NULL,
        sale_invoice_id INTEGER NOT NULL,
        customer_id INTEGER,
        warehouse_id INTEGER NOT NULL,
        total_amount REAL DEFAULT 0,
        reason TEXT,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        return_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_invoice_id) REFERENCES sale_invoices (id),
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id)
      )
    ''');

    // 12. جدول بنود مرتجعات البيع
    await db.execute('''
      CREATE TABLE sale_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (sale_return_id) REFERENCES sale_returns (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 13. جدول سندات القبض
    await db.execute('''
      CREATE TABLE receipt_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_number TEXT UNIQUE NOT NULL,
        customer_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT CHECK(payment_method IN ('cash', 'transfer', 'check')) DEFAULT 'cash',
        payment_date TEXT NOT NULL,
        notes TEXT,
        reference_type TEXT CHECK(reference_type IN ('invoice', 'advance', 'other')),
        reference_id INTEGER,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers (id)
      )
    ''');

    // 14. جدول سندات الصرف
    await db.execute('''
      CREATE TABLE payment_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT CHECK(payment_method IN ('cash', 'transfer', 'check')) DEFAULT 'cash',
        payment_date TEXT NOT NULL,
        notes TEXT,
        reference_type TEXT CHECK(reference_type IN ('invoice', 'expense', 'salary', 'other')),
        reference_id INTEGER,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // 15. جدول تحويلات المخزون
    await db.execute('''
      CREATE TABLE stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_number TEXT UNIQUE NOT NULL,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id INTEGER NOT NULL,
        total_items INTEGER DEFAULT 0,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        transfer_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses (id),
        FOREIGN KEY (to_warehouse_id) REFERENCES warehouses (id)
      )
    ''');

    // 16. جدول بنود تحويلات المخزون
    await db.execute('''
      CREATE TABLE stock_transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_transfer_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (stock_transfer_id) REFERENCES stock_transfers (id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // 17. جدول تعديلات الجرد
    await db.execute('''
      CREATE TABLE inventory_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        adjustment_number TEXT UNIQUE NOT NULL,
        warehouse_id INTEGER NOT NULL,
        adjustment_type TEXT CHECK(adjustment_type IN ('increase', 'decrease', 'correction')) NOT NULL,
        total_items INTEGER DEFAULT 0,
        reason TEXT NOT NULL,
        status TEXT CHECK(status IN ('draft', 'approved', 'cancelled')) DEFAULT 'draft',
        adjustment_date TEXT NOT NULL,
        created_by INTEGER,
        approved_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses (id)
      )
    ''');

    // 18. جدول بنود تعديلات الجرد
    // 18. جدول بنود تعديلات الجرد - الكود المصحح
    await db.execute('''
  CREATE TABLE adjustment_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    adjustment_id INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    current_quantity INTEGER NOT NULL,
    new_quantity INTEGER NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (adjustment_id) REFERENCES inventory_adjustments (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id)
  )
''');

    // 19. جدول سجل الصندوق
    await db.execute('''
      CREATE TABLE cash_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_type TEXT CHECK(transaction_type IN ('receipt', 'payment', 'opening_balance')) NOT NULL,
        amount REAL NOT NULL,
        balance_after REAL NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        description TEXT,
        transaction_date TEXT NOT NULL,
        created_by INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 20. جدول سجل التدقيق
    await db.execute('''
  CREATE TABLE audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    action TEXT NOT NULL,
    table_name TEXT,
    record_id INTEGER,
    description TEXT, 
    old_values TEXT,
    new_values TEXT,
    ip_address TEXT,
    user_agent TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');


    // جدول ترقيم الفواتير
    await db.execute('''
  CREATE TABLE invoice_numbering (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_type TEXT NOT NULL CHECK(invoice_type IN (
      'sale', 'purchase', 'sale_return', 'purchase_return', 
      'stock_transfer', 'inventory_adjustment'
    )),
    prefix TEXT DEFAULT '',
    suffix TEXT DEFAULT '',
    current_number INTEGER DEFAULT 1,
    number_length INTEGER DEFAULT 5,
    reset_frequency TEXT CHECK(reset_frequency IN (
      'never', 'daily', 'weekly', 'monthly', 'yearly'
    )) DEFAULT 'never',
    last_reset_date TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(invoice_type)
  )
''');

// جدول شروط الدفع (موجود بالفعل، سنضيف بعض البيانات الافتراضية)

// جدول سياسات الإرجاع (موجود بالفعل، سنضيف بعض البيانات الافتراضية)

// جدول أرقام الفواتير المحفوظة
    await db.execute('''
  CREATE TABLE invoice_sequences (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    invoice_type TEXT NOT NULL,
    invoice_number TEXT NOT NULL UNIQUE,
    invoice_date TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (invoice_type) REFERENCES invoice_numbering (invoice_type)
  )
''');
// أضف هذه الجداول قبل إنشاء الفهارس

// جدول تنبيهات المخزون المنخفض
    await db.execute('''
  CREATE TABLE IF NOT EXISTS stock_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER NOT NULL,
    warehouse_id INTEGER NOT NULL,
    threshold INTEGER DEFAULT 10,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products (id),
    FOREIGN KEY (warehouse_id) REFERENCES warehouses (id)
  )
''');

// جدول إعدادات الطابعة
    await db.execute('''
  CREATE TABLE IF NOT EXISTS printer_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    printer_name TEXT,
    printer_type TEXT DEFAULT 'thermal',
    paper_width INTEGER DEFAULT 58,
    copies INTEGER DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

// جدول إعدادات النظام المتقدمة
    await db.execute('''
  CREATE TABLE IF NOT EXISTS advanced_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type TEXT DEFAULT 'string',
    category TEXT,
    description TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');
//createPurchaseInvoiceWithItems
    await db.execute('''
  CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT CHECK(role IN ('admin', 'manager', 'warehouse', 'cashier', 'viewer')) DEFAULT 'cashier',
    permissions TEXT,
    is_active INTEGER DEFAULT 1,
    last_login TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

    // في دالة _createAllTables
    await db.execute('''
  CREATE TABLE units (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    abbreviation TEXT,
    base_unit_id INTEGER,
    conversion_factor REAL DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (base_unit_id) REFERENCES units (id)
  )
''');

    await db.execute('''
  CREATE TABLE barcode_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    barcode_type TEXT DEFAULT 'CODE128',
    width INTEGER DEFAULT 2,
    height INTEGER DEFAULT 100,
    include_price INTEGER DEFAULT 0,
    include_name INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

    await db.execute('''
  CREATE TABLE payment_terms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    due_days INTEGER DEFAULT 0,
    discount_percent REAL DEFAULT 0,
    discount_days INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

    await db.execute('''
  CREATE TABLE return_policies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    return_days INTEGER DEFAULT 0,
    restocking_fee REAL DEFAULT 0,
    conditions TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

// في دالة _createAllTables في DatabaseHelper
    await db.execute('''
  CREATE TABLE system_settings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    setting_key TEXT UNIQUE NOT NULL,
    setting_value TEXT,
    setting_type TEXT DEFAULT 'string',
    description TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
  )
''');

// في دالة _seedInitialData
    await db.insert('system_settings', {
      'setting_key': 'company_name',
      'setting_value': 'شركة إدارة المخزون',
      'setting_type': 'string',
      'description': 'اسم الشركة الذي يظهر في التقارير والفواتير',
    });

    await db.insert('system_settings', {
      'setting_key': 'default_currency',
      'setting_value': 'ريال',
      'setting_type': 'string',
      'description': 'العملة الافتراضية للنظام',
    });

    await db.insert('system_settings', {
      'setting_key': 'default_tax_rate',
      'setting_value': '15.0',
      'setting_type': 'double',
      'description': 'نسبة الضريبة الافتراضية',
    });

    await db.insert('system_settings', {
      'setting_key': 'enable_notifications',
      'setting_value': '1',
      'setting_type': 'boolean',
      'description': 'تفعيل التنبيهات',
    });

// إضافة صلاحيات مفصلة
    await db.execute('''
  CREATE TABLE user_permissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    permission_key TEXT NOT NULL,
    granted INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  )
''');
    // إنشاء الفهارس
    await _createIndexes(db);

    // إضافة البيانات الأساسية
    await _seedInitialData(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX idx_warehouse_stock_product ON warehouse_stock(product_id)');
    await db.execute(
        'CREATE INDEX idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)');
    await db.execute(
        'CREATE INDEX idx_purchase_invoice_date ON purchase_invoices(invoice_date)');
    await db.execute(
        'CREATE INDEX idx_sale_invoice_date ON sale_invoices(invoice_date)');
    await db.execute(
        'CREATE INDEX idx_audit_log_created_at ON audit_log(created_at)');
    await db.execute(
        'CREATE INDEX idx_cash_ledger_date ON cash_ledger(transaction_date)');
  }

  Future<void> _seedInitialData(Database db) async {
    // إضافة مخزن افتراضي
    await db.insert('warehouses', {
      'name': 'المخزن الرئيسي',
      'code': 'MAIN',
      'is_active': 1,
    });

    // إضافة مستخدم مدير
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'name': 'مدير النظام',
      'role': 'admin',
      'is_active': 1,
    });
  }

  // ========== دوال إحصائيات Dashboard ==========
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;

    final totalProducts = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE is_active = 1');
    final totalCustomers = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers WHERE is_active = 1');
    final totalSuppliers = await db.rawQuery(
        'SELECT COUNT(*) as count FROM suppliers WHERE is_active = 1');

    final todaySales = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) as amount 
      FROM sale_invoices 
      WHERE status = "approved" AND date(invoice_date) = date("now")
    ''');

    final lowStockProducts = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM products p 
      WHERE p.is_active = 1 AND p.min_stock_level > 0 
      AND EXISTS (
        SELECT 1 FROM warehouse_stock ws 
        WHERE ws.product_id = p.id AND ws.quantity <= p.min_stock_level
      )
    ''');

    final totalAlerts = await db.rawQuery(
        'SELECT COUNT(*) as count FROM alerts WHERE is_read = 0');
    final todayTransactions = await db.rawQuery('''
      SELECT COUNT(*) as count FROM sale_invoices 
      WHERE date(created_at) = date("now")
    ''');

    return {
      'total_products': totalProducts.first['count'] as int,
      'total_customers': totalCustomers.first['count'] as int,
      'total_suppliers': totalSuppliers.first['count'] as int,
      'today_sales': todaySales.first['amount'] as double,
      'low_stock_products': lowStockProducts.first['count'] as int,
      'total_alerts': totalAlerts.first['count'] as int,
      'today_transactions': todayTransactions.first['count'] as int,
    };
  }

  // ========== دوال إدارة المخازن ==========
  Future<int> insertWarehouse(Map<String, dynamic> warehouse) async {
    final db = await database;
    return await db.insert('warehouses', {
      ...warehouse,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getWarehouses() async {
    final db = await database;
    return await db.query('warehouses',
        where: 'is_active = 1',
        orderBy: 'name ASC'
    );
  }

  // ========== دوال إدارة المنتجات ==========
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    final productId = await db.insert('products', {
      ...product,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // إضافة السجل في جميع المخازن
    final warehouses = await getWarehouses();
    for (final warehouse in warehouses) {
      await db.insert('warehouse_stock', {
        'warehouse_id': warehouse['id'],
        'product_id': productId,
        'quantity': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return productId;
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id 
      WHERE p.is_active = 1 
      ORDER BY p.name ASC
    ''');
  }

  Future<Map<String, dynamic>?> getProductStock(int productId,
      int warehouseId) async {
    final db = await database;
    final result = await db.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // ========== دوال فواتير البيع ==========
  // في قسم فواتير البيع في DatabaseHelper - نضيف هذه الدوال:

// الحصول على جميع فواتير البيع
  Future<List<Map<String, dynamic>>> getSaleInvoices({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
    SELECT si.*, 
           c.name as customer_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM sale_invoices si
    LEFT JOIN customers c ON si.customer_id = c.id
    LEFT JOIN warehouses w ON si.warehouse_id = w.id
    LEFT JOIN users u ON si.created_by = u.id
    WHERE $whereClause
    ORDER BY si.created_at DESC
  ''', whereArgs);
  }

// الحصول على فاتورة بيع مع بنودها
  Future<Map<String, dynamic>?> getSaleInvoiceWithItems(int invoiceId) async {
    final db = await database;

    final invoice = await db.rawQuery('''
    SELECT si.*, 
           c.name as customer_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM sale_invoices si
    LEFT JOIN customers c ON si.customer_id = c.id
    LEFT JOIN warehouses w ON si.warehouse_id = w.id
    LEFT JOIN users u ON si.created_by = u.id
    WHERE si.id = ?
  ''', [invoiceId]);

    if (invoice.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT si.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price,
           p.purchase_price
    FROM sale_items si
    JOIN products p ON si.product_id = p.id
    WHERE si.sale_invoice_id = ?
  ''', [invoiceId]);

    return {
      'invoice': invoice.first,
      'items': items,
    };
  }

// إنشاء فاتورة بيع جديدة

// حذف فاتورة البيع
  Future<Map<String, dynamic>> deleteSaleInvoice(int invoiceId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'sale_invoices',
        where: 'id = ? AND status = ?',
        whereArgs: [invoiceId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف الفاتورة بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف فاتورة معتمدة'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف الفاتورة: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> createSaleInvoice(
      Map<String, dynamic> invoice) async {
    final db = await database;

    try {
      // إنشاء رقم فاتورة تلقائي
      final invoiceNumber = 'S${DateTime
          .now()
          .millisecondsSinceEpoch}';

      // إضافة الفاتورة
      final invoiceId = await db.insert('sale_invoices', {
        ...invoice,
        'invoice_number': invoiceNumber,
        'invoice_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'invoice_id': invoiceId,
        'invoice_number': invoiceNumber,
        'message': 'تم إنشاء الفاتورة بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء الفاتورة: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT p.*, c.name as category_name 
    FROM products p 
    LEFT JOIN categories c ON p.category_id = c.id 
    WHERE p.barcode = ? AND p.is_active = 1
  ''', [barcode]);

    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>> approveSaleInvoice(int invoiceId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // الحصول على الفاتورة والبنود
        final invoice = await txn.query(
          'sale_invoices',
          where: 'id = ? AND status = ?',
          whereArgs: [invoiceId, 'draft'],
        );

        if (invoice.isEmpty) {
          throw Exception('الفاتورة غير موجودة أو غير قابلة للاعتماد');
        }

        final items = await txn.query(
          'sale_items',
          where: 'sale_invoice_id = ?',
          whereArgs: [invoiceId],
        );

        // التحقق من توفر الكميات
        for (final item in items) {
          final stock = await txn.query(
            'warehouse_stock',
            where: 'product_id = ? AND warehouse_id = ?',
            whereArgs: [item['product_id'], invoice.first['warehouse_id']],
          );

          if (stock.isEmpty ||
              (stock.first['quantity'] as int) < (item['quantity'] as int)) {
            throw Exception('الكمية غير متوفرة للمنتج: ${item['product_id']}');
          }
        }

        // تحديث الكميات في المخزون
        // for (final item in items) {
        //   await txn.update(
        //     'warehouse_stock',
        //     {'quantity': (stock.first['quantity'] as int) - (item['quantity'] as int)},
        //     where: 'product_id = ? AND warehouse_id = ?',
        //     whereArgs: [item['product_id'], invoice.first['warehouse_id']],
        //   );
        // }

        // تحديث حالة الفاتورة
        await txn.update(
          'sale_invoices',
          {
            'status': 'approved',
            'approved_by': 1,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // تسجيل في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': 1,
          'action': 'APPROVE_SALE_INVOICE',
          'table_name': 'sale_invoices',
          'record_id': invoiceId,
          'created_at': DateTime.now().toIso8601String(),
        });
      });

      return {
        'success': true,
        'message': 'تم اعتماد الفاتورة بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد الفاتورة: ${e.toString()}'
      };
    }
  }

  //الدوال الاحقة
  // دوال إضافية مطلوبة للشاشات الجديدة

// الحصول على الفئات

// الحصول على العملاء
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final db = await database;
    return await db.query(
        'customers', where: 'is_active = 1', orderBy: 'name ASC');
  }

// تحديث مخزون المخزن
  Future<void> updateWarehouseStock(int warehouseId, int productId,
      int quantity) async {
    final db = await database;
    await db.update(
      'warehouse_stock',
      {'quantity': quantity},
      where: 'warehouse_id = ? AND product_id = ?',
      whereArgs: [warehouseId, productId],
    );
  }

// إضافة بند فاتورة بيع
  Future<int> insertSaleItem(Map<String, dynamic> item) async {
    final db = await database;
    return await db.insert('sale_items', item);
  }

// الحصول على المعاملات الأخيرة
  Future<List<Map<String, dynamic>>> getRecentTransactions() async {
    final db = await database;
    return await db.rawQuery('''
    SELECT t.*, p.name as product_name, c.name as customer_name
    FROM transactions t
    LEFT JOIN products p ON t.product_id = p.id
    LEFT JOIN customers c ON t.customer_id = c.id
    ORDER BY t.date DESC
    LIMIT 100
  ''');
  }

// الحصول على جميع المنتجات مع معلومات الفئة

// حذف منتج
  Future<int> deleteProduct(int productId) async {
    final db = await database;
    return await db.update(
      'products',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

// الحصول على الفئات

// دوال العملاء
  Future<int> insertCustomer(Map<String, dynamic> customer) async {
    final db = await database;
    return await db.insert('customers', {
      ...customer,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

// في قسم فواتير الشراء في DatabaseHelper - نضيف هذه الدوال:

// الحصول على جميع فواتير الشراء
  Future<List<Map<String, dynamic>>> getPurchaseInvoices(
      {String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
    SELECT pi.*, 
           s.name as supplier_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM purchase_invoices pi
    LEFT JOIN suppliers s ON pi.supplier_id = s.id
    LEFT JOIN warehouses w ON pi.warehouse_id = w.id
    LEFT JOIN users u ON pi.created_by = u.id
    WHERE $whereClause
    ORDER BY pi.created_at DESC
  ''', whereArgs);
  }

// الحصول على فاتورة شراء مع بنودها
  Future<Map<String, dynamic>?> getPurchaseInvoiceWithItems(
      int invoiceId) async {
    final db = await database;

    final invoice = await db.rawQuery('''
    SELECT pi.*, 
           s.name as supplier_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM purchase_invoices pi
    LEFT JOIN suppliers s ON pi.supplier_id = s.id
    LEFT JOIN warehouses w ON pi.warehouse_id = w.id
    LEFT JOIN users u ON pi.created_by = u.id
    WHERE pi.id = ?
  ''', [invoiceId]);

    if (invoice.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT pi.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price
    FROM purchase_items pi
    JOIN products p ON pi.product_id = p.id
    WHERE pi.purchase_invoice_id = ?
  ''', [invoiceId]);

    return {
      'invoice': invoice.first,
      'items': items,
    };
  }

// ========== دوال الفئات ==========

  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final db = await database;
      return await db.query(
        'categories',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
    } catch (e) {
      print('❌ خطأ في جلب الفئات: $e');
      return [];
    }
  }

  Future<int> insertCategory(Map<String, dynamic> category) async {
    try {
      final db = await database;

      // تحقق من عدم تكرار اسم الفئة
      final existing = await db.query(
        'categories',
        where: 'name = ? AND is_active = 1',
        whereArgs: [category['name']],
      );

      if (existing.isNotEmpty) {
        throw Exception('الفئة "${category['name']}" موجودة بالفعل');
      }

      final id = await db.insert('categories', {
        ...category,
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ تم إضافة الفئة برقم ID: $id - ${category['name']}');
      return id;
    } catch (e) {
      print('❌ خطأ في إضافة الفئة: $e');
      rethrow;
    }
  }

  Future<int> updateCategory(int id, Map<String, dynamic> category) async {
    try {
      final db = await database;

      final result = await db.update(
        'categories',
        {
          ...category,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ تم تحديث الفئة برقم: $id');
      return result;
    } catch (e) {
      print('❌ خطأ في تحديث الفئة: $e');
      rethrow;
    }
  }

  Future<int> deleteCategory(int id) async {
    try {
      final db = await database;

      // بدلاً من الحذف الكامل، نقوم بتعطيل الفئة
      final result = await db.update(
        'categories',
        {
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      print('✅ تم تعطيل الفئة برقم: $id');
      return result;
    } catch (e) {
      print('❌ خطأ في حذف الفئة: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCategoryById(int id) async {
    try {
      final db = await database;

      final result = await db.query(
        'categories',
        where: 'id = ? AND is_active = 1',
        whereArgs: [id],
      );

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ خطأ في جلب الفئة: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCategoriesWithParent() async {
    try {
      final db = await database;

      return await db.rawQuery('''
      SELECT 
        c1.*,
        c2.name as parent_name
      FROM categories c1
      LEFT JOIN categories c2 ON c1.parent_id = c2.id
      WHERE c1.is_active = 1
      ORDER BY c1.name ASC
    ''');
    } catch (e) {
      print('❌ خطأ في جلب الفئات مع الأباء: $e');
      return [];
    }
  }

  Future<int> getCategoryProductCount(int categoryId) async {
    try {
      final db = await database;

      final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM products 
      WHERE category_id = ? AND is_active = 1
    ''', [categoryId]);

      return result.isNotEmpty ? result.first['count'] as int : 0;
    } catch (e) {
      print('❌ خطأ في حساب عدد منتجات الفئة: $e');
      return 0;
    }
  }

// إنشاء فاتورة شراء جديدة
  Future<Map<String, dynamic>> createPurchaseInvoiceWithItems(
      Map<String, dynamic> invoice,
      List<Map<String, dynamic>> items) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم الفاتورة
        final invoiceNumber = 'P${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2. إدخال الفاتورة
        final invoiceId = await txn.insert('purchase_invoices', {
          ...invoice,
          'invoice_number': invoiceNumber,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود
        double totalAmount = 0;
        for (final item in items) {
          final totalPrice = (item['quantity'] as int) *
              (item['unit_price'] as double);
          totalAmount += totalPrice;

          await txn.insert('purchase_items', {
            ...item,
            'purchase_invoice_id': invoiceId,
            'total_price': totalPrice,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج ✅ التصحيح هنا
          await _updateProductStock(
              txn, // ⬅️ لا تستخدم as Database هنا
              item['product_id'] as int,
              invoice['warehouse_id'] as int,
              item['quantity'] as int,
              true // زيادة المخزون
          );
        }

        // 5. تحديث المبلغ الإجمالي
        await txn.update(
          'purchase_invoices',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [invoiceId],
        );

        // 6. تحديث رصيد المورد ✅ التصحيح هنا
        await _updateSupplierBalance(
            txn, // ⬅️ لا تستخدم as Database هنا
            invoice['supplier_id'] as int,
            totalAmount,
            true // زيادة الدائن
        );

        return {
          'success': true,
          'invoice_id': invoiceId,
          'invoice_number': invoiceNumber,
          'total_amount': totalAmount,
        };
      });

      return result;
    } catch (e) {
      print('❌ خطأ في حفظ فاتورة الشراء: $e');
      return {
        'success': false,
        'error': 'فشل في إنشاء الفاتورة: ${e.toString()}'
      };
    }
  }

//_updateProductStock
  //_updateSupplierBalance:
// دالة مساعدة لتحديث مخزون المنتج
  Future<void> _updateProductStock(dynamic txn,
      // ⬅️ استخدم dynamic بدلاً من DatabaseExecutor
      int productId,
      int warehouseId,
      int quantity,
      bool isIncrease) async {
    final stock = await txn.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
    );

    if (stock.isNotEmpty) {
      final currentQty = stock.first['quantity'] as int;
      final newQty = isIncrease ? currentQty + quantity : currentQty - quantity;

      await txn.update(
        'warehouse_stock',
        {
          'quantity': newQty,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId],
      );
    }
  }

// دالة مساعدة لتحديث رصيد المورد
  Future<void> _updateSupplierBalance(dynamic txn,
      // ⬅️ استخدم dynamic بدلاً من DatabaseExecutor
      int supplierId,
      double amount,
      bool isIncrease) async {
    final supplier = await txn.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    if (supplier.isNotEmpty) {
      final currentBalance = supplier.first['balance'] as double;
      final newBalance = isIncrease ? currentBalance + amount : currentBalance -
          amount;

      await txn.update(
        'suppliers',
        {
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [supplierId],
      );
    }
  }

// حذف فاتورة الشراء
  Future<Map<String, dynamic>> deletePurchaseInvoice(int invoiceId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'purchase_invoices',
        where: 'id = ? AND status = ?',
        whereArgs: [invoiceId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف الفاتورة بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف فاتورة معتمدة'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف الفاتورة: ${e.toString()}'
      };
    }
  }

// اعتماد فاتورة الشراء
  Future<Map<String, dynamic>> approvePurchaseInvoice(int invoiceId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // تحديث حالة الفاتورة
        await txn.update(
          'purchase_invoices',
          {
            'status': 'approved',
            'approved_by': 1, // TODO: استخدام ID المستخدم الحالي
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [invoiceId],
        );
      });

      return {
        'success': true,
        'message': 'تم اعتماد الفاتورة بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد الفاتورة: ${e.toString()}'
      };
    }
  }

  Future<int> updateCustomer(int id, Map<String, dynamic> customer) async {
    final db = await database;
    return await db.update(
      'customers',
      {
        ...customer,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.update(
      'customers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// دوال المعاملات
  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// دوال المخازن

  Future<int> updateWarehouse(int id, Map<String, dynamic> warehouse) async {
    final db = await database;
    return await db.update(
      'warehouses',
      warehouse,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// في قسم مرتجعات البيع في DatabaseHelper

// الحصول على جميع مرتجعات البيع
  Future<List<Map<String, dynamic>>> getSalesReturns({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
    SELECT sr.*, 
           si.invoice_number as sale_invoice_number,
           c.name as customer_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM sale_returns sr
    LEFT JOIN sale_invoices si ON sr.sale_invoice_id = si.id
    LEFT JOIN customers c ON sr.customer_id = c.id
    LEFT JOIN warehouses w ON sr.warehouse_id = w.id
    LEFT JOIN users u ON sr.created_by = u.id
    WHERE $whereClause
    ORDER BY sr.created_at DESC
  ''', whereArgs);
  }

// الحصول على مرتجع بيع مع بنوده
  Future<Map<String, dynamic>?> getSalesReturnWithItems(int returnId) async {
    final db = await database;

    final salesReturn = await db.rawQuery('''
    SELECT sr.*, 
           si.invoice_number as sale_invoice_number,
           c.name as customer_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM sale_returns sr
    LEFT JOIN sale_invoices si ON sr.sale_invoice_id = si.id
    LEFT JOIN customers c ON sr.customer_id = c.id
    LEFT JOIN warehouses w ON sr.warehouse_id = w.id
    LEFT JOIN users u ON sr.created_by = u.id
    WHERE sr.id = ?
  ''', [returnId]);

    if (salesReturn.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT sri.*, 
           p.name as product_name,
           p.barcode
    FROM sale_return_items sri
    JOIN products p ON sri.product_id = p.id
    WHERE sri.sale_return_id = ?
  ''', [returnId]);

    return {
      'sales_return': salesReturn.first,
      'items': items,
    };
  }

// إنشاء مرتجع بيع جديد
  Future<Map<String, dynamic>> createSalesReturnWithItems(
      Map<String, dynamic> salesReturn,
      List<Map<String, dynamic>> items) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم المرتجع
        final returnNumber = 'SR${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2. إدخال المرتجع
        final returnId = await txn.insert('sale_returns', {
          ...salesReturn,
          'return_number': returnNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود
        double totalAmount = 0;
        for (final item in items) {
          final totalPrice = (item['quantity'] as int) *
              (item['unit_price'] as double);
          totalAmount += totalPrice;

          await txn.insert('sale_return_items', {
            ...item,
            'sale_return_id': returnId,
            'total_price': totalPrice,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج (زيادة لأنه مرتجع)
          await _updateProductStock(
              txn,
              item['product_id'],
              salesReturn['warehouse_id'],
              item['quantity'],
              true // زيادة المخزون
          );
        }

        // 5. تحديث المبلغ الإجمالي
        await txn.update(
          'sale_returns',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [returnId],
        );

        return {
          'success': true,
          'return_id': returnId,
          'return_number': returnNumber,
          'total_amount': totalAmount,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء مرتجع البيع: ${e.toString()}'
      };
    }
  }

// في DatabaseHelper أضف هذه الدوال:

// 1. دالة جلب عميل
  Future<Map<String, dynamic>?> getCustomer(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'customers',
        where: 'id = ? AND is_active = 1',
        whereArgs: [id],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ خطأ في جلب العميل: $e');
      return null;
    }
  }

// 2. دالة إنشاء فاتورة بسيطة
  Future<Map<String, dynamic>> createSaleInvoiceWithItems(
      Map<String, dynamic> invoice,
      List<Map<String, dynamic>> items) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 🔹 1. التحقق من رقم الفاتورة (استخدم الرقم من invoice)
        final invoiceNumber = invoice['invoice_number'] as String?;
        if (invoiceNumber == null || invoiceNumber.isEmpty) {
          throw Exception('رقم الفاتورة مطلوب');
        }

        // 🔹 2. حساب المبالغ بشكل صحيح
        double subTotal = 0;
        double totalCost = 0;

        for (final item in items) {
          final quantity = item['quantity'] as int;
          final unitPrice = item['unit_price'] as double;
          final costPrice = item['cost_price'] as double? ?? 0.0;

          subTotal += quantity * unitPrice;
          totalCost += quantity * costPrice;
        }

        // 🔹 3. حساب الخصم والضريبة
        final discountAmount = (invoice['discount'] as double?) ?? 0.0;
        final taxPercent = (invoice['tax_percent'] as double?) ?? 15.0;
        final taxAmount = (subTotal - discountAmount) * (taxPercent / 100);
        final totalAmount = subTotal - discountAmount + taxAmount;
        final paidAmount = (invoice['paid_amount'] as double?) ?? 0.0;
        final remainingAmount = totalAmount - paidAmount;

        // 🔹 4. إدخال الفاتورة (استخدام البيانات التي أرسلتها من الشاشة)
        final invoiceId = await txn.insert('sale_invoices', {
          'invoice_number': invoiceNumber, // ⬅️ الرقم من الشاشة
          'customer_id': invoice['customer_id'],
          'warehouse_id': invoice['warehouse_id'],
          'payment_method': invoice['payment_method'],
          'sub_total': subTotal,
          'discount_amount': discountAmount,
          'tax_percent': taxPercent,
          'tax_amount': taxAmount,
          'total_amount': totalAmount,
          'paid_amount': paidAmount,
          'remaining_amount': remainingAmount,
          'status': invoice['status'] ?? 'approved',
          'notes': invoice['notes'],
          'invoice_date': invoice['invoice_date'],
          'created_by': invoice['created_by'] ?? 1,

          // إذا كانت هذه الحقول موجودة في جدولك
          'due_date': invoice['due_date'],
          'transfer_reference': invoice['transfer_reference'],
          'transfer_bank': invoice['transfer_bank'],
          'transfer_date': invoice['transfer_date'],
          'guarantee_details': invoice['guarantee_details'],
          'cash_received': invoice['cash_received'] ?? 0,
          'transfer_confirmed': invoice['transfer_confirmed'] ?? 0,

          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // 🔹 5. إدخال البنود مع حسابات دقيقة
        for (final item in items) {
          final quantity = item['quantity'] as int;
          final unitPrice = item['unit_price'] as double;
          final costPrice = item['cost_price'] as double? ?? 0.0;
          final productId = item['product_id'] as int;

          final totalPrice = quantity * unitPrice;
          final totalItemCost = quantity * costPrice;
          final profit = totalPrice - totalItemCost;

          await txn.insert('sale_items', {
            'sale_invoice_id': invoiceId,
            'product_id': productId,
            'quantity': quantity,
            'unit_price': unitPrice,
            'unit_cost': costPrice,
            'discount_amount': 0,
            // أو item['discount_amount'] إذا كان هناك خصم على المنتج
            'tax_amount': 0,
            // أو حسب الحاجة
            'total_price': totalPrice,
            'total_cost': totalItemCost,
            'profit': profit,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 🔹 6. تحديث مخزون المنتج (إذا الفاتورة معتمدة)
          if ((invoice['status'] as String? ?? 'approved') == 'approved') {
            await _updateProductStock(
                txn,
                productId,
                invoice['warehouse_id'] as int,
                quantity,
                false // ⬅️ نقصان المخزون للبيع
            );
          }
        }

        // 🔹 7. تحديث رصيد العميل إذا كان البيع آجل
        if (invoice['customer_id'] != null &&
            (invoice['payment_method'] as String? ?? 'cash') == 'credit') {
          await _updateCustomerBalance(
              txn,
              invoice['customer_id'] as int,
              totalAmount,
              true // ⬅️ زيادة مدين العميل
          );
        }

        // 🔹 8. تسجيل في سجل التدقيق
        await txn.insert('audit_log', {
          'user_id': invoice['created_by'] ?? 1,
          'action': 'CREATE_SALE_INVOICE',
          'table_name': 'sale_invoices',
          'record_id': invoiceId,
          'description': 'تم إنشاء فاتورة بيع رقم $invoiceNumber',
          'created_at': DateTime.now().toIso8601String(),
        });

        return {
          'success': true,
          'invoice_id': invoiceId,
          'invoice_number': invoiceNumber,
          'total_amount': totalAmount,
          'message': 'تم إنشاء الفاتورة بنجاح'
        };
      });

      return result;
    } catch (e) {
      print('❌ خطأ في إنشاء فاتورة البيع: $e');
      return {
        'success': false,
        'error': 'فشل في إنشاء الفاتورة: ${e.toString()}'
      };
    }
  }

// حذف مرتجع البيع
  Future<Map<String, dynamic>> deleteSalesReturn(int returnId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'sale_returns',
        where: 'id = ? AND status = ?',
        whereArgs: [returnId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف المرتجع بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف مرتجع معتمد'};
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف المرتجع: ${e.toString()}'};
    }
  }

  // في قسم مرتجعات الشراء في DatabaseHelper

// الحصول على جميع مرتجعات الشراء
  Future<List<Map<String, dynamic>>> getPurchaseReturns(
      {String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
    SELECT pr.*, 
           pi.invoice_number as purchase_invoice_number,
           s.name as supplier_name,
           w.name as warehouse_name,
           u.name as created_by_name
    FROM purchase_returns pr
    LEFT JOIN purchase_invoices pi ON pr.purchase_invoice_id = pi.id
    LEFT JOIN suppliers s ON pr.supplier_id = s.id
    LEFT JOIN warehouses w ON pr.warehouse_id = w.id
    LEFT JOIN users u ON pr.created_by = u.id
    WHERE $whereClause
    ORDER BY pr.created_at DESC
  ''', whereArgs);
  }

// إنشاء مرتجع شراء جديد
  Future<Map<String, dynamic>> createPurchaseReturnWithItems(
      Map<String, dynamic> purchaseReturn,
      List<Map<String, dynamic>> items) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم المرتجع
        final returnNumber = 'PR${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2. إدخال المرتجع
        final returnId = await txn.insert('purchase_returns', {
          ...purchaseReturn,
          'return_number': returnNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود
        double totalAmount = 0;
        for (final item in items) {
          final totalPrice = (item['quantity'] as int) *
              (item['unit_price'] as double);
          totalAmount += totalPrice;

          await txn.insert('purchase_return_items', {
            ...item,
            'purchase_return_id': returnId,
            'total_price': totalPrice,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج (نقصان لأنه مرتجع شراء)
          await _updateProductStock(
              txn,
              item['product_id'],
              purchaseReturn['warehouse_id'],
              item['quantity'],
              false // نقصان المخزون
          );
        }

        // 5. تحديث المبلغ الإجمالي
        await txn.update(
          'purchase_returns',
          {'total_amount': totalAmount},
          where: 'id = ?',
          whereArgs: [returnId],
        );

        return {
          'success': true,
          'return_id': returnId,
          'return_number': returnNumber,
          'total_amount': totalAmount,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء مرتجع الشراء: ${e.toString()}'
      };
    }
  }

// حذف مرتجع الشراء
  Future<Map<String, dynamic>> deletePurchaseReturn(int returnId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'purchase_returns',
        where: 'id = ? AND status = ?',
        whereArgs: [returnId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف المرتجع بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف مرتجع معتمد'};
      }
    } catch (e) {
      return {'success': false, 'error': 'فشل في حذف المرتجع: ${e.toString()}'};
    }
  }

  // في قسم تعديلات الجرد في DatabaseHelper

// الحصول على جميع تعديلات الجرد
  Future<List<Map<String, dynamic>>> getInventoryAdjustments(
      {String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
    SELECT ia.*, 
           w.name as warehouse_name,
           u.name as created_by_name,
           COUNT(ai.id) as items_count
    FROM inventory_adjustments ia
    LEFT JOIN warehouses w ON ia.warehouse_id = w.id
    LEFT JOIN users u ON ia.created_by = u.id
    LEFT JOIN adjustment_items ai ON ia.id = ai.adjustment_id
    WHERE $whereClause
    GROUP BY ia.id
    ORDER BY ia.created_at DESC
  ''', whereArgs);
  }

// الحصول على تعديل جرد مع بنوده
  Future<Map<String, dynamic>?> getInventoryAdjustmentWithItems(
      int adjustmentId) async {
    final db = await database;

    final adjustment = await db.rawQuery('''
    SELECT ia.*, 
           w.name as warehouse_name,
           u.name as created_by_name
    FROM inventory_adjustments ia
    LEFT JOIN warehouses w ON ia.warehouse_id = w.id
    LEFT JOIN users u ON ia.created_by = u.id
    WHERE ia.id = ?
  ''', [adjustmentId]);

    if (adjustment.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT ai.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price,
           ws.quantity as current_stock
    FROM adjustment_items ai
    JOIN products p ON ai.product_id = p.id
    LEFT JOIN warehouse_stock ws ON ai.product_id = ws.product_id AND ws.warehouse_id = ?
    WHERE ai.adjustment_id = ?
  ''', [adjustment.first['warehouse_id'], adjustmentId]);

    return {
      'adjustment': adjustment.first,
      'items': items,
    };
  }

// إنشاء تعديل جرد جديد
  Future<Map<String, dynamic>> createInventoryAdjustmentWithItems(
      Map<String, dynamic> adjustment,
      List<Map<String, dynamic>> items,) async {
    final Database db = await database;
//_updateProductStockForAdjustment
    try {
      return await db.transaction((Transaction txn) async {
        // 1️⃣ إنشاء رقم التعديل
        final String adjustmentNumber =
            'ADJ${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2️⃣ إدخال التعديل الرئيسي
        final int adjustmentId = await txn.insert(
          'inventory_adjustments',
          {
            ...adjustment,
            'adjustment_number': adjustmentNumber,
            'total_items': items.length,
            'created_at': DateTime.now().toIso8601String(),
          },
        );

        // 3️⃣ إدخال البنود + تحديث المخزون
        for (final Map<String, dynamic> item in items) {
          await txn.insert(
            'adjustment_items',
            {
              ...item,
              'adjustment_id': adjustmentId,
              'created_at': DateTime.now().toIso8601String(),
            },
          );

          // 4️⃣ تحديث مخزون المنتج ✅
          await _updateProductStockForAdjustment(
            txn, // ✅ الآن صحيح
            item['product_id'] as int,
            adjustment['warehouse_id'] as int,
            item['new_quantity'] as int,
          );
        }

        // ✅ نجاح العملية
        return {
          'success': true,
          'adjustment_id': adjustmentId,
          'adjustment_number': adjustmentNumber,
          'total_items': items.length,
        };
      });
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء تعديل الجرد: $e',
      };
    }
  }

// دالة مساعدة لتحديث مخزون المنتج للتعديل
  Future<void> _updateProductStockForAdjustment(DatabaseExecutor txn,
      int productId,
      int warehouseId,
      int newQuantity) async {
    final stock = await txn.query(
      'warehouse_stock',
      where: 'product_id = ? AND warehouse_id = ?',
      whereArgs: [productId, warehouseId],
    );

    if (stock.isNotEmpty) {
      await txn.update(
        'warehouse_stock',
        {
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'product_id = ? AND warehouse_id = ?',
        whereArgs: [productId, warehouseId],
      );
    } else {
      await txn.insert('warehouse_stock', {
        'warehouse_id': warehouseId,
        'product_id': productId,
        'quantity': newQuantity,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

// الحصول على مخزون المخزن للمنتجات
  Future<List<Map<String, dynamic>>> getWarehouseStockForAdjustment(
      int warehouseId) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      p.min_stock_level,
      ws.quantity as current_quantity,
      c.name as category_name
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id AND ws.warehouse_id = ?
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = 1
    ORDER BY p.name ASC
  ''', [warehouseId]);
  }

// اعتماد تعديل الجرد
  Future<Map<String, dynamic>> approveInventoryAdjustment(
      int adjustmentId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // تحديث حالة التعديل
        await txn.update(
          'inventory_adjustments',
          {
            'status': 'approved',
            'approved_by': 1, // TODO: استخدام ID المستخدم الحالي
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [adjustmentId],
        );
      });

      return {
        'success': true,
        'message': 'تم اعتماد تعديل الجرد بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد تعديل الجرد: ${e.toString()}'
      };
    }
  }

// حذف تعديل الجرد
  Future<Map<String, dynamic>> deleteInventoryAdjustment(
      int adjustmentId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'inventory_adjustments',
        where: 'id = ? AND status = ?',
        whereArgs: [adjustmentId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف تعديل الجرد بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف تعديل معتمد'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف تعديل الجرد: ${e.toString()}'
      };
    }
  }

  // في قسم تحويلات المخزون في DatabaseHelper

// الحصول على جميع تحويلات المخزون
  Future<List<Map<String, dynamic>>> getStockTransfers({String? status}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    return await db.rawQuery('''
    SELECT st.*, 
           w1.name as from_warehouse_name,
           w2.name as to_warehouse_name,
           u.name as created_by_name,
           COUNT(sti.id) as items_count
    FROM stock_transfers st
    LEFT JOIN warehouses w1 ON st.from_warehouse_id = w1.id
    LEFT JOIN warehouses w2 ON st.to_warehouse_id = w2.id
    LEFT JOIN users u ON st.created_by = u.id
    LEFT JOIN stock_transfer_items sti ON st.id = sti.stock_transfer_id
    WHERE $whereClause
    GROUP BY st.id
    ORDER BY st.created_at DESC
  ''', whereArgs);
  }

// الحصول على تحويل مخزون مع بنوده
  Future<Map<String, dynamic>?> getStockTransferWithItems(
      int transferId) async {
    final db = await database;

    final transfer = await db.rawQuery('''
    SELECT st.*, 
           w1.name as from_warehouse_name,
           w2.name as to_warehouse_name,
           u.name as created_by_name
    FROM stock_transfers st
    LEFT JOIN warehouses w1 ON st.from_warehouse_id = w1.id
    LEFT JOIN warehouses w2 ON st.to_warehouse_id = w2.id
    LEFT JOIN users u ON st.created_by = u.id
    WHERE st.id = ?
  ''', [transferId]);

    if (transfer.isEmpty) return null;

    final items = await db.rawQuery('''
    SELECT sti.*, 
           p.name as product_name,
           p.barcode,
           p.sell_price
    FROM stock_transfer_items sti
    JOIN products p ON sti.product_id = p.id
    WHERE sti.stock_transfer_id = ?
  ''', [transferId]);

    return {
      'transfer': transfer.first,
      'items': items,
    };
  }

// إنشاء تحويل مخزون جديد
  Future<Map<String, dynamic>> createStockTransferWithItems(
      Map<String, dynamic> transfer,
      List<Map<String, dynamic>> items) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم التحويل
        final transferNumber = 'TR${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2. إدخال التحويل
        final transferId = await txn.insert('stock_transfers', {
          ...transfer,
          'transfer_number': transferNumber,
          'total_items': items.length,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. إدخال البنود وتحديث المخزون
        for (final item in items) {
          await txn.insert('stock_transfer_items', {
            ...item,
            'stock_transfer_id': transferId,
            'created_at': DateTime.now().toIso8601String(),
          });

          // 4. تحديث مخزون المنتج في المخزن المصدر (نقصان)
          await _updateProductStock(
              txn,
              item['product_id'],
              transfer['from_warehouse_id'],
              item['quantity'],
              false // نقصان المخزون
          );

          // 5. تحديث مخزون المنتج في المخزن الهدف (زيادة)
          await _updateProductStock(
              txn,
              item['product_id'],
              transfer['to_warehouse_id'],
              item['quantity'],
              true // زيادة المخزون
          );
        }

        return {
          'success': true,
          'transfer_id': transferId,
          'transfer_number': transferNumber,
          'total_items': items.length,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء تحويل المخزون: ${e.toString()}'
      };
    }
  }

// اعتماد تحويل المخزون
  Future<Map<String, dynamic>> approveStockTransfer(int transferId) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        // تحديث حالة التحويل
        await txn.update(
          'stock_transfers',
          {
            'status': 'approved',
            'approved_by': 1, // TODO: استخدام ID المستخدم الحالي
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [transferId],
        );
      });

      return {
        'success': true,
        'message': 'تم اعتماد تحويل المخزون بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في اعتماد تحويل المخزون: ${e.toString()}'
      };
    }
  }

// حذف تحويل المخزون
  Future<Map<String, dynamic>> deleteStockTransfer(int transferId) async {
    final db = await database;

    try {
      final affectedRows = await db.delete(
        'stock_transfers',
        where: 'id = ? AND status = ?',
        whereArgs: [transferId, 'draft'],
      );

      if (affectedRows > 0) {
        return {'success': true, 'message': 'تم حذف تحويل المخزون بنجاح'};
      } else {
        return {'success': false, 'error': 'لا يمكن حذف تحويل معتمد'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف تحويل المخزون: ${e.toString()}'
      };
    }
  }

// الحصول على مخزون المخزن للمنتجات لتحويل المخزون
  Future<List<Map<String, dynamic>>> getWarehouseStockForTransfer(
      int warehouseId) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      p.min_stock_level,
      ws.quantity as current_quantity,
      c.name as category_name
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id AND ws.warehouse_id = ?
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE p.is_active = 1 AND ws.quantity > 0
    ORDER BY p.name ASC
  ''', [warehouseId]);
  }

  // في قسم سندات القبض في DatabaseHelper

// الحصول على جميع سندات القبض
  Future<List<Map<String, dynamic>>> getReceiptVouchers(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date(payment_date) BETWEEN ? AND ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery('''
    SELECT rv.*, 
           c.name as customer_name,
           u.name as created_by_name
    FROM receipt_vouchers rv
    LEFT JOIN customers c ON rv.customer_id = c.id
    LEFT JOIN users u ON rv.created_by = u.id
    WHERE $whereClause
    ORDER BY rv.payment_date DESC, rv.created_at DESC
  ''', whereArgs);
  }

// إنشاء سند قبض جديد
  Future<Map<String, dynamic>> createReceiptVoucher(
      Map<String, dynamic> voucher) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم السند
        final voucherNumber = 'RCV${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2. إدخال السند
        final voucherId = await txn.insert('receipt_vouchers', {
          ...voucher,
          'voucher_number': voucherNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. تحديث رصيد العميل (تخفيض المدين)
        if (voucher['customer_id'] != null) {
          await _updateCustomerBalance(
              txn,
              voucher['customer_id'],
              voucher['amount'],
              false // تخفيض المدين
          );
        }

        // 4. تسجيل في سجل الصندوق
        await _addCashLedgerEntry(
          txn,
          'receipt',
          voucher['amount'],
          'سند قبض - ${voucher['voucher_number']}',
          'receipt_voucher',
          voucherId,
        );

        return {
          'success': true,
          'voucher_id': voucherId,
          'voucher_number': voucherNumber,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء سند القبض: ${e.toString()}'
      };
    }
  }

// دالة مساعدة لتحديث رصيد العميل
  Future<void> _updateCustomerBalance(DatabaseExecutor txn,
      int customerId,
      double amount,
      bool isIncrease) async {
    final customer = await txn.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
    );

    if (customer.isNotEmpty) {
      final currentBalance = customer.first['balance'] as double;
      final newBalance = isIncrease ? currentBalance + amount : currentBalance -
          amount;

      await txn.update(
        'customers',
        {
          'balance': newBalance,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [customerId],
      );
    }
  }

// دالة مساعدة لإضافة مدخل في سجل الصندوق
  Future<void> _addCashLedgerEntry(DatabaseExecutor txn,
      String transactionType,
      double amount,
      String description,
      String referenceType,
      int referenceId,) async {
    // الحصول على آخر رصيد
    final lastBalance = await txn.rawQuery('''
    SELECT balance_after FROM cash_ledger 
    ORDER BY id DESC LIMIT 1
  ''');

    double currentBalance = 0;
    if (lastBalance.isNotEmpty) {
      currentBalance = lastBalance.first['balance_after'] as double;
    }

    double newBalance = currentBalance;
    if (transactionType == 'receipt') {
      newBalance = currentBalance + amount;
    } else if (transactionType == 'payment') {
      newBalance = currentBalance - amount;
    }

    await txn.insert('cash_ledger', {
      'transaction_type': transactionType,
      'amount': amount,
      'balance_after': newBalance,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'description': description,
      'transaction_date': DateTime.now().toIso8601String(),
      'created_by': 1, // TODO: استخدام ID المستخدم الحالي
      'created_at': DateTime.now().toIso8601String(),
    });
  }

// حذف سند القبض
  Future<Map<String, dynamic>> deleteReceiptVoucher(int voucherId) async {
    final db = await database;

    try {
      final voucher = await db.query(
        'receipt_vouchers',
        where: 'id = ?',
        whereArgs: [voucherId],
      );

      if (voucher.isEmpty) {
        return {'success': false, 'error': 'السند غير موجود'};
      }

      final customerId = (voucher.first['customer_id'] as int?);
      final amount = (voucher.first['amount'] as num?)?.toDouble() ?? 0.0;

      await db.transaction((txn) async {
        // التراجع عن تحديث رصيد العميل
        if (customerId != null) {
          await _updateCustomerBalance(
            txn,
            customerId,
            amount,
            true, // زيادة المدين
          );
        }

        // حذف السند
        await txn.delete(
          'receipt_vouchers',
          where: 'id = ?',
          whereArgs: [voucherId],
        );
      });

      return {'success': true, 'message': 'تم حذف سند القبض بنجاح'};
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف سند القبض: ${e.toString()}'
      };
    }
  }

// في قسم سندات الصرف في DatabaseHelper

// الحصول على جميع سندات الصرف
  Future<List<Map<String, dynamic>>> getPaymentVouchers(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date(payment_date) BETWEEN ? AND ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery('''
    SELECT pv.*, 
           s.name as supplier_name,
           u.name as created_by_name
    FROM payment_vouchers pv
    LEFT JOIN suppliers s ON pv.supplier_id = s.id
    LEFT JOIN users u ON pv.created_by = u.id
    WHERE $whereClause
    ORDER BY pv.payment_date DESC, pv.created_at DESC
  ''', whereArgs);
  }

// إنشاء سند صرف جديد
  Future<Map<String, dynamic>> createPaymentVoucher(
      Map<String, dynamic> voucher) async {
    final db = await database;

    try {
      final result = await db.transaction((txn) async {
        // 1. إنشاء رقم السند
        final voucherNumber = 'PAY${DateTime
            .now()
            .millisecondsSinceEpoch}';

        // 2. إدخال السند
        final voucherId = await txn.insert('payment_vouchers', {
          ...voucher,
          'voucher_number': voucherNumber,
          'created_at': DateTime.now().toIso8601String(),
        });

        // 3. تحديث رصيد المورد (تخفيض الدائن)
        if (voucher['supplier_id'] != null) {
          await _updateSupplierBalance(
              txn,
              voucher['supplier_id'],
              voucher['amount'],
              false // تخفيض الدائن
          );
        }

        // 4. تسجيل في سجل الصندوق
        await _addCashLedgerEntry(
          txn,
          'payment',
          voucher['amount'],
          'سند صرف - ${voucher['voucher_number']}',
          'payment_voucher',
          voucherId,
        );

        return {
          'success': true,
          'voucher_id': voucherId,
          'voucher_number': voucherNumber,
        };
      });

      return result;
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إنشاء سند الصرف: ${e.toString()}'
      };
    }
  }

// حذف سند الصرف
  Future<Map<String, dynamic>> deletePaymentVoucher(int voucherId) async {
    final db = await database;

    try {
      final voucher = await db.query(
        'payment_vouchers',
        where: 'id = ?',
        whereArgs: [voucherId],
      );

      if (voucher.isEmpty) {
        return {'success': false, 'error': 'السند غير موجود'};
      }

      final supplierId = (voucher.first['supplier_id'] as int?);
      final amount = (voucher.first['amount'] as num?)?.toDouble() ?? 0.0;

      await db.transaction((txn) async {
        // التراجع عن تحديث رصيد المورد
        if (supplierId != null) {
          await _updateSupplierBalance(
            txn,
            supplierId,
            amount,
            true, // زيادة الدائن
          );
        }

        // حذف السند
        await txn.delete(
          'payment_vouchers',
          where: 'id = ?',
          whereArgs: [voucherId],
        );
      });

      return {'success': true, 'message': 'تم حذف سند الصرف بنجاح'};
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف سند الصرف: ${e.toString()}'
      };
    }
  }

  // في قسم سجل الصندوق في DatabaseHelper

// الحصول على سجل الصندوق
  Future<List<Map<String, dynamic>>> getCashLedger(
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause += ' AND date(transaction_date) BETWEEN ? AND ?';
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate));
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate));
    }

    return await db.rawQuery('''
    SELECT cl.*, u.name as created_by_name
    FROM cash_ledger cl
    LEFT JOIN users u ON cl.created_by = u.id
    WHERE $whereClause
    ORDER BY cl.transaction_date DESC, cl.created_at DESC
  ''', whereArgs);
  }

// الحصول على رصيد الصندوق الحالي
  Future<double> getCurrentCashBalance() async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT balance_after FROM cash_ledger 
    ORDER BY id DESC LIMIT 1
  ''');

    if (result.isNotEmpty) {
      return result.first['balance_after'] as double;
    }

    return 0;
  }

// إضافة رصيد افتتاحي
  Future<Map<String, dynamic>> addOpeningBalance(double amount,
      DateTime date) async {
    final db = await database;

    try {
      await db.insert('cash_ledger', {
        'transaction_type': 'opening_balance',
        'amount': amount,
        'balance_after': amount,
        'description': 'رصيد افتتاحي',
        'transaction_date': date.toIso8601String(),
        'created_by': 1, // TODO: استخدام ID المستخدم الحالي
        'created_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'تم إضافة الرصيد الافتتاحي بنجاح'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إضافة الرصيد الافتتاحي: ${e.toString()}'
      };
    }
  }

  // في قسم التقارير في DatabaseHelper

// الحصول على إحصائيات المبيعات الشهرية
  Future<List<Map<String, dynamic>>> getMonthlySalesReport(int year) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      strftime('%m', invoice_date) as month,
      COUNT(*) as invoices_count,
      SUM(total_amount) as total_sales,
      SUM(paid_amount) as total_paid,
      AVG(total_amount) as avg_sale,
      MAX(total_amount) as max_sale,
      MIN(total_amount) as min_sale
    FROM sale_invoices 
    WHERE status = 'approved' 
      AND strftime('%Y', invoice_date) = ?
    GROUP BY strftime('%m', invoice_date)
    ORDER BY month ASC
  ''', [year.toString()]);
  }

// الحصول على تقرير المبيعات اليومية
  Future<List<Map<String, dynamic>>> getDailySalesReport(DateTime date) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      si.invoice_number,
      si.invoice_date,
      c.name as customer_name,
      si.total_amount,
      si.paid_amount,
      si.payment_method,
      COUNT(si.id) as items_count,
      u.name as cashier_name
    FROM sale_invoices si
    LEFT JOIN customers c ON si.customer_id = c.id
    LEFT JOIN users u ON si.created_by = u.id
    WHERE si.status = 'approved' 
      AND date(si.invoice_date) = date(?)
    ORDER BY si.invoice_date DESC
  ''', [date.toIso8601String()]);
  }

// الحصول على أفضل المنتجات مبيعاً
  Future<List<Map<String, dynamic>>> getTopSellingProducts(
      {int limit = 10, String period = 'month'}) async {
    final db = await database;

    String dateFilter = '';
    switch (period) {
      case 'day':
        dateFilter = "AND date(si.invoice_date) = date('now')";
        break;
      case 'week':
        dateFilter = "AND date(si.invoice_date) >= date('now', '-7 days')";
        break;
      case 'month':
        dateFilter =
        "AND strftime('%Y-%m', si.invoice_date) = strftime('%Y-%m', 'now')";
        break;
      case 'year':
        dateFilter =
        "AND strftime('%Y', si.invoice_date) = strftime('%Y', 'now')";
        break;
    }

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      c.name as category_name,
      SUM(si.quantity) as total_sold,
      SUM(si.total_price) as total_revenue,
      AVG(si.unit_price) as avg_price,
      COUNT(DISTINCT si.sale_invoice_id) as invoices_count
    FROM sale_items si
    JOIN products p ON si.product_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved'
      $dateFilter
    GROUP BY p.id
    ORDER BY total_sold DESC
    LIMIT ?
  ''', [limit]);
  }

// الحصول على تقرير العملاء
  Future<List<Map<String, dynamic>>> getCustomersReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      c.id,
      c.name,
      c.phone,
      c.balance,
      COUNT(si.id) as total_invoices,
      SUM(si.total_amount) as total_purchases,
      MAX(si.invoice_date) as last_purchase_date,
      AVG(si.total_amount) as avg_purchase
    FROM customers c
    LEFT JOIN sale_invoices si ON c.id = si.customer_id AND si.status = 'approved'
    WHERE c.is_active = 1
    GROUP BY c.id
    ORDER BY total_purchases DESC
  ''');
  }

// الحصول على تقرير الموردين
  Future<List<Map<String, dynamic>>> getSuppliersReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      s.id,
      s.name,
      s.phone,
      s.balance,
      COUNT(pi.id) as total_invoices,
      SUM(pi.total_amount) as total_purchases,
      MAX(pi.invoice_date) as last_purchase_date,
      AVG(pi.total_amount) as avg_purchase
    FROM suppliers s
    LEFT JOIN purchase_invoices pi ON s.id = pi.supplier_id AND pi.status = 'approved'
    WHERE s.is_active = 1
    GROUP BY s.id
    ORDER BY total_purchases DESC
  ''');
  }

// الحصول على تقرير المخزون
  Future<List<Map<String, dynamic>>> getInventoryReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      c.name as category_name,
      p.purchase_price,
      p.sell_price,
      SUM(ws.quantity) as total_stock,
      COUNT(DISTINCT ws.warehouse_id) as warehouses_count,
      (p.sell_price - p.purchase_price) as profit_margin,
      (p.sell_price - p.purchase_price) / p.purchase_price * 100 as profit_percentage
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    WHERE p.is_active = 1
    GROUP BY p.id
    ORDER BY total_stock DESC
  ''');
  }

// الحصول على المنتجات منخفضة المخزون
  Future<List<Map<String, dynamic>>> getLowStockProducts(
      {int threshold = 10}) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      c.name as category_name,
      p.min_stock_level,
      SUM(ws.quantity) as total_stock,
      GROUP_CONCAT(w.name) as warehouse_names
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    LEFT JOIN warehouses w ON ws.warehouse_id = w.id
    WHERE p.is_active = 1 
      AND p.min_stock_level > 0
    GROUP BY p.id
    HAVING total_stock <= p.min_stock_level OR total_stock <= ?
    ORDER BY total_stock ASC
  ''', [threshold]);
  }

// الحصول على إحصائيات سريعة للتقرير
  Future<Map<String, dynamic>> getReportsSummary() async {
    final db = await database;

    final monthlySales = await db.rawQuery('''
    SELECT 
      COALESCE(SUM(total_amount), 0) as monthly_sales,
      COALESCE(COUNT(*), 0) as monthly_invoices
    FROM sale_invoices 
    WHERE status = 'approved' 
      AND strftime('%Y-%m', invoice_date) = strftime('%Y-%m', 'now')
  ''');

    final todaySales = await db.rawQuery('''
    SELECT 
      COALESCE(SUM(total_amount), 0) as today_sales,
      COALESCE(COUNT(*), 0) as today_invoices
    FROM sale_invoices 
    WHERE status = 'approved' 
      AND date(invoice_date) = date('now')
  ''');

    final inventoryStats = await db.rawQuery('''
    SELECT 
      COUNT(*) as total_products,
      SUM(ws.quantity) as total_stock,
      SUM(ws.quantity * p.purchase_price) as inventory_value
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    WHERE p.is_active = 1
  ''');

    final customerStats = await db.rawQuery('''
    SELECT 
      COUNT(*) as total_customers,
      SUM(balance) as total_balance
    FROM customers 
    WHERE is_active = 1
  ''');

    return {
      'monthly_sales': monthlySales.first['monthly_sales'] ?? 0,
      'monthly_invoices': monthlySales.first['monthly_invoices'] ?? 0,
      'today_sales': todaySales.first['today_sales'] ?? 0,
      'today_invoices': todaySales.first['today_invoices'] ?? 0,
      'total_products': inventoryStats.first['total_products'] ?? 0,
      'total_stock': inventoryStats.first['total_stock'] ?? 0,
      'inventory_value': inventoryStats.first['inventory_value'] ?? 0,
      'total_customers': customerStats.first['total_customers'] ?? 0,
      'total_balance': customerStats.first['total_balance'] ?? 0,
    };
  }

  // في قسم تقارير الأرباح في DatabaseHelper

// الحصول على تقرير الأرباح الشامل
  Future<Map<String, dynamic>> getProfitReport(DateTime startDate,
      DateTime endDate) async {
    final db = await database;

    // إحصائيات المبيعات
    final salesStats = await db.rawQuery('''
    SELECT
      COUNT(*) as total_invoices,
      SUM(total_amount) as total_sales,
      SUM(paid_amount) as total_paid,
      SUM(discount) as total_discount,
      AVG(total_amount) as avg_sale
    FROM sale_invoices
    WHERE status = 'approved'
      AND date(invoice_date) BETWEEN ? AND ?
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // إحصائيات المشتريات
    final purchaseStats = await db.rawQuery('''
    SELECT
      COUNT(*) as total_invoices,
      SUM(total_amount) as total_purchases,
      SUM(paid_amount) as total_paid
    FROM purchase_invoices
    WHERE status = 'approved'
      AND date(invoice_date) BETWEEN ? AND ?
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // حساب الأرباح من بنود المبيعات
    final profitStats = await db.rawQuery('''
    SELECT
      SUM(si.quantity * (si.unit_price - si.cost_price)) as total_profit,
      SUM(si.quantity * si.unit_price) as total_revenue,
      SUM(si.quantity * si.cost_price) as total_cost,
      COUNT(DISTINCT si.sale_invoice_id) as invoices_count
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved'
      AND date(s.invoice_date) BETWEEN ? AND ?
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // الأرباح الشهرية
    final monthlyProfit = await db.rawQuery('''
    SELECT
      strftime('%Y-%m', s.invoice_date) as month,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as profit,
      SUM(si.quantity * si.unit_price) as revenue,
      SUM(si.quantity * si.cost_price) as cost
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved'
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY strftime('%Y-%m', s.invoice_date)
    ORDER BY month ASC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    return {
      'sales_stats': salesStats.first,
      'purchase_stats': purchaseStats.first,
      'profit_stats': profitStats.first,
      'monthly_profit': monthlyProfit,
    };
  }

// الحصول على أرباح الموردين
  Future<List<Map<String, dynamic>>> getSupplierProfitReport(DateTime startDate,
      DateTime endDate) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      s.id,
      s.name,
      s.phone,
      COUNT(pi.id) as purchase_invoices,
      SUM(pi.total_amount) as total_purchases,
      SUM(pi.paid_amount) as total_paid,
      (
        SELECT COALESCE(SUM(si.quantity * (si.unit_price - p.purchase_price)), 0)
        FROM sale_items si
        JOIN sale_invoices sinv ON si.sale_invoice_id = sinv.id
        JOIN products p ON si.product_id = p.id
        WHERE p.id IN (
          SELECT product_id FROM purchase_items WHERE purchase_invoice_id IN (
            SELECT id FROM purchase_invoices WHERE supplier_id = s.id
          )
        )
        AND sinv.status = 'approved'
        AND date(sinv.invoice_date) BETWEEN ? AND ?
      ) as generated_profit
    FROM suppliers s
    LEFT JOIN purchase_invoices pi ON s.id = pi.supplier_id 
      AND pi.status = 'approved'
      AND date(pi.invoice_date) BETWEEN ? AND ?
    WHERE s.is_active = 1
    GROUP BY s.id
    ORDER BY generated_profit DESC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate),
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);
  }

// الحصول على أرباح المنتجات
  Future<List<Map<String, dynamic>>> getProductProfitReport(DateTime startDate,
      DateTime endDate) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.barcode,
      c.name as category_name,
      SUM(si.quantity) as total_sold,
      SUM(si.quantity * si.unit_price) as total_revenue,
      SUM(si.quantity * si.cost_price) as total_cost,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as total_profit,
      AVG(si.unit_price - si.cost_price) as avg_profit_per_unit,
      (SUM(si.quantity * (si.unit_price - si.cost_price)) / SUM(si.quantity * si.unit_price)) * 100 as profit_margin
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    JOIN products p ON si.product_id = p.id
    LEFT JOIN categories c ON p.category_id = c.id
    WHERE s.status = 'approved' 
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY p.id
    HAVING total_sold > 0
    ORDER BY total_profit DESC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);
  }

// الحصول على تقرير الأرباح اليومية
  Future<List<Map<String, dynamic>>> getDailyProfitReport(DateTime startDate,
      DateTime endDate) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      date(s.invoice_date) as date,
      COUNT(DISTINCT s.id) as invoices_count,
      SUM(si.quantity) as items_sold,
      SUM(si.quantity * si.unit_price) as daily_revenue,
      SUM(si.quantity * si.cost_price) as daily_cost,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as daily_profit,
      (SUM(si.quantity * (si.unit_price - si.cost_price)) / SUM(si.quantity * si.unit_price)) * 100 as daily_margin
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved' 
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY date(s.invoice_date)
    ORDER BY date(s.invoice_date) DESC
  ''', [
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);
  }

// الحصول على تقرير هوامش الربح
  Future<List<Map<String, dynamic>>> getProfitMarginReport() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      p.purchase_price,
      p.sell_price,
      (p.sell_price - p.purchase_price) as profit_per_unit,
      ((p.sell_price - p.purchase_price) / p.purchase_price) * 100 as profit_margin,
      COALESCE(SUM(ws.quantity), 0) as current_stock,
      (COALESCE(SUM(ws.quantity), 0) * (p.sell_price - p.purchase_price)) as potential_profit
    FROM products p
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    WHERE p.is_active = 1
    GROUP BY p.id
    HAVING profit_margin > 0
    ORDER BY profit_margin DESC
  ''');
  }

  // في قسم تقارير الموردين في DatabaseHelper

// الحصول على تقرير مفصل لمورد معين
  Future<Map<String, dynamic>> getSupplierDetailedReport(int supplierId,
      DateTime startDate, DateTime endDate) async {
    final db = await database;

    // معلومات المورد الأساسية
    final supplierInfo = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [supplierId],
    );

    // فواتير الشراء من المورد
    final purchaseInvoices = await db.rawQuery('''
    SELECT 
      pi.*,
      w.name as warehouse_name,
      u.name as created_by_name
    FROM purchase_invoices pi
    LEFT JOIN warehouses w ON pi.warehouse_id = w.id
    LEFT JOIN users u ON pi.created_by = u.id
    WHERE pi.supplier_id = ? 
      AND pi.status = 'approved'
      AND date(pi.invoice_date) BETWEEN ? AND ?
    ORDER BY pi.invoice_date DESC
  ''', [
      supplierId,
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // بنود فواتير الشراء
    List<Map<String, dynamic>> purchaseItems = [];
    double totalPurchases = 0.0;
    double totalPaid = 0.0;
    int totalItems = 0;

    for (final invoice in purchaseInvoices) {
      final items = await db.rawQuery('''
      SELECT 
        pi.*,
        p.name as product_name,
        p.barcode,
        p.sell_price
      FROM purchase_items pi
      JOIN products p ON pi.product_id = p.id
      WHERE pi.purchase_invoice_id = ?
    ''', [invoice['id']]);

      purchaseItems.addAll(items);

      // تحويل آمن للقيم الرقمية
      totalPurchases += (invoice['total_amount'] as num?)?.toDouble() ?? 0.0;
      totalPaid += (invoice['paid_amount'] as num?)?.toDouble() ?? 0.0;
      totalItems += items.length;
    }

    // المنتجات المشتراة من المورد ومبيعاتها
    final supplierProducts = await db.rawQuery('''
    SELECT DISTINCT
      p.id,
      p.name,
      p.barcode,
      p.purchase_price,
      p.sell_price,
      (SELECT SUM(quantity) FROM purchase_items WHERE product_id = p.id AND purchase_invoice_id IN (
        SELECT id FROM purchase_invoices WHERE supplier_id = ?
      )) as total_purchased_quantity,
      (SELECT COALESCE(SUM(quantity), 0) FROM sale_items WHERE product_id = p.id AND sale_invoice_id IN (
        SELECT id FROM sale_invoices WHERE status = 'approved'
      )) as total_sold_quantity,
      (SELECT COALESCE(SUM(quantity * unit_price), 0) FROM sale_items WHERE product_id = p.id AND sale_invoice_id IN (
        SELECT id FROM sale_invoices WHERE status = 'approved'
      )) as total_sales_revenue,
      (SELECT COALESCE(SUM(quantity * cost_price), 0) FROM sale_items WHERE product_id = p.id AND sale_invoice_id IN (
        SELECT id FROM sale_invoices WHERE status = 'approved'
      )) as total_sales_cost
    FROM products p
    WHERE p.id IN (
      SELECT DISTINCT product_id FROM purchase_items WHERE purchase_invoice_id IN (
        SELECT id FROM purchase_invoices WHERE supplier_id = ?
      )
    )
  ''', [supplierId, supplierId]);

    // حساب الأرباح من منتجات المورد
    double totalGeneratedProfit = 0.0;
    double totalGeneratedRevenue = 0.0;
    int totalProductsSold = 0;

    for (final product in supplierProducts) {
      final revenue = (product['total_sales_revenue'] as num?)?.toDouble() ??
          0.0;
      final cost = (product['total_sales_cost'] as num?)?.toDouble() ?? 0.0;
      totalGeneratedProfit += (revenue - cost);
      totalGeneratedRevenue += revenue;
      totalProductsSold += (product['total_sold_quantity'] as int?) ?? 0;
    }

    // المبيعات الشهرية لمنتجات المورد
    final monthlySales = await db.rawQuery('''
    SELECT 
      strftime('%Y-%m', s.invoice_date) as month,
      SUM(si.quantity) as items_sold,
      SUM(si.quantity * si.unit_price) as revenue,
      SUM(si.quantity * si.cost_price) as cost,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as profit
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved'
      AND si.product_id IN (
        SELECT DISTINCT product_id FROM purchase_items WHERE purchase_invoice_id IN (
          SELECT id FROM purchase_invoices WHERE supplier_id = ?
        )
      )
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY strftime('%Y-%m', s.invoice_date)
    ORDER BY month ASC
  ''', [
      supplierId,
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    // أفضل المنتجات أداءً من هذا المورد
    final topProducts = await db.rawQuery('''
    SELECT 
      p.id,
      p.name,
      SUM(si.quantity) as total_sold,
      SUM(si.quantity * si.unit_price) as revenue,
      SUM(si.quantity * si.cost_price) as cost,
      SUM(si.quantity * (si.unit_price - si.cost_price)) as profit,
      (SUM(si.quantity * (si.unit_price - si.cost_price)) / SUM(si.quantity * si.unit_price)) * 100 as profit_margin
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    JOIN products p ON si.product_id = p.id
    WHERE s.status = 'approved'
      AND p.id IN (
        SELECT DISTINCT product_id FROM purchase_items WHERE purchase_invoice_id IN (
          SELECT id FROM purchase_invoices WHERE supplier_id = ?
        )
      )
      AND date(s.invoice_date) BETWEEN ? AND ?
    GROUP BY p.id
    HAVING total_sold > 0
    ORDER BY profit DESC
    LIMIT 10
  ''', [
      supplierId,
      DateFormat('yyyy-MM-dd').format(startDate),
      DateFormat('yyyy-MM-dd').format(endDate)
    ]);

    return {
      'supplier_info': supplierInfo.isNotEmpty ? supplierInfo.first : {},
      'purchase_invoices': purchaseInvoices,
      'purchase_items': purchaseItems,
      'supplier_products': supplierProducts,
      'summary': {
        'total_purchases': totalPurchases,
        'total_paid': totalPaid,
        'remaining_balance': totalPurchases - totalPaid,
        'total_items_purchased': totalItems,
        'total_products': supplierProducts.length,
        'total_generated_profit': totalGeneratedProfit,
        'total_generated_revenue': totalGeneratedRevenue,
        'total_products_sold': totalProductsSold,
        'profit_margin': totalGeneratedRevenue > 0
            ? (totalGeneratedProfit / totalGeneratedRevenue) * 100
            : 0.0,
      },
      'monthly_sales': monthlySales,
      'top_products': topProducts,
    };
  }


// الحصول على قائمة جميع الموردين مع إحصائيات مختصرة
  Future<List<Map<String, dynamic>>> getAllSuppliersSummary() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      s.id,
      s.name,
      s.phone,
      s.balance,
      COUNT(pi.id) as total_invoices,
      COALESCE(SUM(pi.total_amount), 0) as total_purchases,
      COALESCE(SUM(pi.paid_amount), 0) as total_paid,
      MAX(pi.invoice_date) as last_purchase_date,
      (
        SELECT COUNT(DISTINCT product_id) 
        FROM purchase_items 
        WHERE purchase_invoice_id IN (
          SELECT id FROM purchase_invoices WHERE supplier_id = s.id
        )
      ) as unique_products,
      (
        SELECT COALESCE(SUM(si.quantity * (si.unit_price - p.purchase_price)), 0)
        FROM sale_items si
        JOIN sale_invoices sinv ON si.sale_invoice_id = sinv.id
        JOIN products p ON si.product_id = p.id
        WHERE p.id IN (
          SELECT product_id FROM purchase_items WHERE purchase_invoice_id IN (
            SELECT id FROM purchase_invoices WHERE supplier_id = s.id
          )
        )
        AND sinv.status = 'approved'
      ) as generated_profit
    FROM suppliers s
    LEFT JOIN purchase_invoices pi ON s.id = pi.supplier_id AND pi.status = 'approved'
    WHERE s.is_active = 1
    GROUP BY s.id
    ORDER BY total_purchases DESC
  ''');
  }

  // في قسم دوال الداشبورد في DatabaseHelper

// الحصول على إحصائيات متقدمة للداشبورد
  Future<Map<String, dynamic>> getAdvancedDashboardStats() async {
    final db = await database;

    // الإحصائيات الأساسية
    final totalProducts = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE is_active = 1');
    final totalCustomers = await db.rawQuery(
        'SELECT COUNT(*) as count FROM customers WHERE is_active = 1');
    final totalSuppliers = await db.rawQuery(
        'SELECT COUNT(*) as count FROM suppliers WHERE is_active = 1');
    final totalWarehouses = await db.rawQuery(
        'SELECT COUNT(*) as count FROM warehouses WHERE is_active = 1');

    // مبيعات اليوم
    final todaySales = await db.rawQuery('''
    SELECT COALESCE(SUM(total_amount), 0) as amount 
    FROM sale_invoices 
    WHERE status = "approved" AND date(invoice_date) = date("now")
  ''');

    // مشتريات اليوم
    final todayPurchases = await db.rawQuery('''
    SELECT COALESCE(SUM(total_amount), 0) as amount 
    FROM purchase_invoices 
    WHERE status = "approved" AND date(invoice_date) = date("now")
  ''');

    // المنتجات منخفضة المخزون
    final lowStockProducts = await db.rawQuery('''
    SELECT COUNT(DISTINCT p.id) as count 
    FROM products p 
    JOIN warehouse_stock ws ON p.id = ws.product_id 
    WHERE p.is_active = 1 AND p.min_stock_level > 0 AND ws.quantity <= p.min_stock_level
  ''');

    // عدد فواتير اليوم
    final todayTransactions = await db.rawQuery('''
    SELECT COUNT(*) as count FROM (
      SELECT id FROM sale_invoices WHERE date(created_at) = date("now")
      UNION ALL
      SELECT id FROM purchase_invoices WHERE date(created_at) = date("now")
    )
  ''');

    // الرصيد النقدي
    final cashBalance = await db.rawQuery('''
    SELECT balance_after FROM cash_ledger ORDER BY id DESC LIMIT 1
  ''');

    // أرباح اليوم
    final todayProfit = await db.rawQuery('''
    SELECT COALESCE(SUM(si.quantity * (si.unit_price - si.cost_price)), 0) as profit
    FROM sale_items si
    JOIN sale_invoices s ON si.sale_invoice_id = s.id
    WHERE s.status = 'approved' AND date(s.invoice_date) = date('now')
  ''');

    // فواتير معلقة
    final pendingInvoices = await db.rawQuery('''
    SELECT COUNT(*) as count FROM sale_invoices WHERE status = 'draft'
  ''');

    return {
      'total_products': totalProducts.first['count'] as int,
      'total_customers': totalCustomers.first['count'] as int,
      'total_suppliers': totalSuppliers.first['count'] as int,
      'total_warehouses': totalWarehouses.first['count'] as int,
      'today_sales': todaySales.first['amount'] as double,
      'today_purchases': todayPurchases.first['amount'] as double,
      'low_stock_products': lowStockProducts.first['count'] as int,
      'today_transactions': todayTransactions.first['count'] as int,
      'cash_balance': cashBalance.isNotEmpty ? cashBalance
          .first['balance_after'] as double : 0,
      'today_profit': todayProfit.first['profit'] as double,
      'pending_invoices': pendingInvoices.first['count'] as int,
    };
  }

// في قسم دوال العملاء في DatabaseHelper

// دالة جلب عميل بواسطة ID


// دالة بديلة أكثر تفصيلاً
  Future<Map<String, dynamic>?> getCustomerDetails(int customerId) async {
    final db = await database;

    try {
      final result = await db.rawQuery('''
      SELECT 
        c.*,
        (SELECT COUNT(*) FROM sale_invoices 
         WHERE customer_id = ? AND status = 'approved') as total_invoices,
        (SELECT COALESCE(SUM(total_amount), 0) FROM sale_invoices 
         WHERE customer_id = ? AND status = 'approved') as total_purchases,
        (SELECT MAX(invoice_date) FROM sale_invoices 
         WHERE customer_id = ? AND status = 'approved') as last_purchase_date
      FROM customers c
      WHERE c.id = ? AND c.is_active = 1
    ''', [customerId, customerId, customerId, customerId]);

      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ خطأ في جلب تفاصيل العميل: $e');
      return null;
    }
  }

// الحصول على المبيعات الشهرية
  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      strftime('%m', invoice_date) as month,
      SUM(total_amount) as sales
    FROM sale_invoices 
    WHERE status = 'approved' AND strftime('%Y', invoice_date) = strftime('%Y', 'now')
    GROUP BY strftime('%m', invoice_date)
    ORDER BY month ASC
  ''');
  }

  Future<int> deleteWarehouse(int id) async {
    final db = await database;
    return await db.update(
      'warehouses',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

//_updateSupplierBalance
// الحصول على ملخص مخزون المخزن
  Future<Map<String, dynamic>> getWarehouseStockSummary(int warehouseId) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT 
      COUNT(*) as total_products,
      SUM(ws.quantity) as total_quantity,
      SUM(ws.quantity * p.sell_price) as total_value,
      SUM(CASE WHEN ws.quantity <= p.min_stock_level AND ws.quantity > 0 THEN 1 ELSE 0 END) as low_stock_products,
      SUM(CASE WHEN ws.quantity = 0 THEN 1 ELSE 0 END) as out_of_stock_products
    FROM warehouse_stock ws
    JOIN products p ON ws.product_id = p.id
    WHERE ws.warehouse_id = ?
  ''', [warehouseId]);

    return result.isNotEmpty ? result.first : {};
  }

// الحصول على مخزون مخزن معين
  Future<List<Map<String, dynamic>>> getWarehouseStock(int warehouseId) async {
    final db = await database;
    return await db.rawQuery('''
    SELECT 
      ws.*,
      p.name as product_name,
      p.barcode,
      p.sell_price,
      p.min_stock_level
    FROM warehouse_stock ws
    JOIN products p ON ws.product_id = p.id
    WHERE ws.warehouse_id = ?
    ORDER BY p.name ASC
  ''', [warehouseId]);
  }

// دوال الموردين
  Future<int> insertSupplier(Map<String, dynamic> supplier) async {
    final db = await database;
    return await db.insert('suppliers', {
      ...supplier,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateSupplier(int id, Map<String, dynamic> supplier) async {
    final db = await database;
    return await db.update(
      'suppliers',
      {
        ...supplier,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return await db.update(
      'suppliers',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getSuppliers() async {
    final db = await database;
    return await db.query(
      'suppliers',
      orderBy: 'name ASC',
    );
  }

// الحصول على إحصائيات المورد
  Future<Map<String, dynamic>> getSupplierStats(int supplierId) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT 
      COUNT(*) as total_invoices,
      COALESCE(SUM(total_amount), 0) as total_purchases,
      MAX(invoice_date) as last_purchase_date,
      AVG(total_amount) as avg_purchase_amount
    FROM purchase_invoices 
    WHERE supplier_id = ? AND status = 'approved'
  ''', [supplierId]);

    return result.isNotEmpty ? result.first : {};
  }

  // ========== دوال التقارير ==========
  // Future<List<Map<String, dynamic>>> getProfitReport(DateTime startDate, DateTime endDate) async {
  //   final db = await database;
  //
  //   return await db.rawQuery('''
  //     SELECT
  //       si.invoice_date,
  //       si.invoice_number,
  //       SUM(si.total_amount) as revenue,
  //       SUM(si.cost_amount) as cost,
  //       SUM(si.total_amount - si.cost_amount) as profit,
  //       (SUM(si.total_amount - si.cost_amount) / SUM(si.total_amount)) * 100 as profit_margin
  //     FROM sale_invoices si
  //     WHERE si.status = 'approved'
  //       AND date(si.invoice_date) BETWEEN ? AND ?
  //     GROUP BY si.invoice_date, si.invoice_number
  //     ORDER BY si.invoice_date DESC
  //   ''', [
  //     DateFormat('yyyy-MM-dd').format(startDate),
  //     DateFormat('yyyy-MM-dd').format(endDate)
  //   ]);
  // }
// في نهاية DatabaseHelper، أضف هذه الدوال الجديدة:

// 1. دالة تحديث رصيد المورد بشكل منفصل
  Future<void> updateSupplierBalance(int supplierId, double amount,
      bool isIncrease) async {
    final db = await database;

    await db.transaction((txn) async {
      final supplier = await txn.query(
        'suppliers',
        where: 'id = ?',
        whereArgs: [supplierId],
      );

      if (supplier.isNotEmpty) {
        final currentBalance = supplier.first['balance'] as double;
        final newBalance = isIncrease
            ? currentBalance + amount
            : currentBalance - amount;

        await txn.update(
          'suppliers',
          {
            'balance': newBalance,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [supplierId],
        );
      }
    });
  }

// 2. دالة تحديث كمية المنتج مع التسجيل
  Future<void> updateProductQuantity(int productId,
      int quantityChange,
      String movementType, {
        int? supplierId,
        String? notes,
        double? price,
      }) async {
    final db = await database;

    await db.transaction((txn) async {
      // 1. تحديث الكمية في جدول المنتجات
      final product = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );

      if (product.isNotEmpty) {
        final currentQty = product.first['current_quantity'] as int;
        final newQty = currentQty + quantityChange;

        // تحديث الكمية الحالية
        await txn.update(
          'products',
          {
            'current_quantity': newQty,
            'updated_at': DateTime.now().toIso8601String(),
            if (movementType == 'purchase') 'last_purchase_date': DateTime
                .now()
                .toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      // 2. تسجيل الحركة
      final totalAmount = (price ?? 0) * quantityChange.abs();

      await txn.insert('product_movements', {
        'product_id': productId,
        'supplier_id': supplierId,
        'movement_type': movementType,
        'quantity': quantityChange,
        'price': price ?? 0,
        'total_amount': totalAmount,
        'notes': notes ?? '',
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. تسجيل في سجل التدقيق
      await txn.insert('audit_log', {
        'user_id': 1,
        'action': 'PRODUCT_QUANTITY_UPDATE',
        'table_name': 'products',
        'record_id': productId,
        'new_values': json.encode({
          'quantity_change': quantityChange,
          'movement_type': movementType,
          'notes': notes,
        }),
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

// 3. دالة جلب المنتجات مع المورد والكمية
  Future<List<Map<String, dynamic>>> getProductsWithDetails() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      p.*,
      c.name as category_name,
      s.name as supplier_name,
      s.phone as supplier_phone,
      s.email as supplier_email,
      COALESCE(SUM(ws.quantity), 0) as warehouse_quantity
    FROM products p
    LEFT JOIN categories c ON p.category_id = c.id
    LEFT JOIN suppliers s ON p.supplier_id = s.id
    LEFT JOIN warehouse_stock ws ON p.id = ws.product_id
    WHERE p.is_active = 1
    GROUP BY p.id
    ORDER BY p.created_at DESC
  ''');
  }

// 4. دالة الحصول على حركات المنتج
  Future<List<Map<String, dynamic>>> getProductMovements(int productId) async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      pm.*,
      s.name as supplier_name,
      DATE(pm.created_at) as date
    FROM product_movements pm
    LEFT JOIN suppliers s ON pm.supplier_id = s.id
    WHERE pm.product_id = ?
    ORDER BY pm.created_at DESC
  ''', [productId]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // في ملف database_helper.dart، أضف هذه الدوال لجلب بيانات محددة للوحة التحكم

// الحصول على إجمالي المبيعات اليوم
  Future<double> getTodaySales() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COALESCE(SUM(total_amount), 0) as total
    FROM sale_invoices
    WHERE status = 'approved' AND date(invoice_date) = date('now')
  ''');
    return result.first['total'] as double;
  }

// الحصول على إجمالي المشتريات اليوم
  Future<double> getTodayPurchases() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COALESCE(SUM(total_amount), 0) as total
    FROM purchase_invoices
    WHERE status = 'approved' AND date(invoice_date) = date('now')
  ''');
    return result.first['total'] as double;
  }

// الحصول على قيمة المخزون الإجمالية
  Future<double> getTotalStockValue() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT COALESCE(SUM(ws.quantity * p.purchase_price), 0) as total_value
    FROM warehouse_stock ws
    JOIN products p ON ws.product_id = p.id
    WHERE ws.quantity > 0
  ''');
    return result.first['total_value'] as double;
  }

// دوال إدارة الإعدادات
  Future<Map<String, dynamic>> getSystemSettings() async {
    final db = await database;
    final settings = await db.query('system_settings');

    Map<String, dynamic> settingsMap = {};
    for (final setting in settings) {
      final key = setting['setting_key'] as String;
      final value = setting['setting_value'];
      final type = setting['setting_type'] as String;

      switch (type) {
        case 'boolean':
          settingsMap[key] = value == '1';
          break;
        case 'int':
          settingsMap[key] = int.tryParse(value.toString()) ?? 0;
          break;
        case 'double':
          settingsMap[key] = double.tryParse(value.toString()) ?? 0.0;
          break;
        default:
          settingsMap[key] = value;
      }
    }

    return settingsMap;
  }

  Future<void> updateSystemSetting(String key, dynamic value) async {
    final db = await database;

    // تحديد نوع القيمة
    String type = 'string';
    if (value is bool) {
      type = 'boolean';
      value = value ? '1' : '0';
    } else if (value is int) {
      type = 'int';
    } else if (value is double) {
      type = 'double';
    }

    await db.update(
      'system_settings',
      {
        'setting_value': value.toString(),
        'setting_type': type,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'setting_key = ?',
      whereArgs: [key],
    );
  }

// دوال إدارة المستخدمين
  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users', where: 'is_active = 1');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', {
      ...user,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;
    return await db.update(
      'users',
      user,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.update(
      'users',
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

// دوال إدارة الصلاحيات
  Future<List<Map<String, dynamic>>> getUserPermissions(int userId) async {
    final db = await database;
    return await db.query(
      'user_permissions',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updateUserPermission(int userId, String permissionKey,
      bool granted) async {
    final db = await database;

    // التحقق من وجود الصلاحية
    final existing = await db.query(
      'user_permissions',
      where: 'user_id = ? AND permission_key = ?',
      whereArgs: [userId, permissionKey],
    );

    if (existing.isNotEmpty) {
      // تحديث الصلاحية الموجودة
      await db.update(
        'user_permissions',
        {'granted': granted ? 1 : 0},
        where: 'user_id = ? AND permission_key = ?',
        whereArgs: [userId, permissionKey],
      );
    } else {
      // إضافة صلاحية جديدة
      await db.insert('user_permissions', {
        'user_id': userId,
        'permission_key': permissionKey,
        'granted': granted ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

// دوال النسخ الاحتياطي والاستعادة
  Future<String> createBackup() async {
    final db = await database;
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'inventory_system.db');

    // إنشاء نسخة من قاعدة البيانات
    final backupPath = join(databasesPath, 'backup_${DateTime
        .now()
        .millisecondsSinceEpoch}.db');
    final file = File(path);
    await file.copy(backupPath);

    return backupPath;
  }

  Future<void> restoreBackup(String backupPath) async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'inventory_system.db');

    // إغلاق قاعدة البيانات الحالية
    await _db?.close();
    _db = null;

    // استبدال قاعدة البيانات بالنسخة الاحتياطية
    final backupFile = File(backupPath);
    await backupFile.copy(path);

    // إعادة فتح قاعدة البيانات
    await database;
  }
// ========== دوال إدارة الإعدادات المتقدمة ==========

// 1. إدارة وحدات القياس
  Future<List<Map<String, dynamic>>> getUnits() async {
    try {
      final db = await database;
      return await db.query('units',
          where: 'is_active = 1',
          orderBy: 'name ASC'
      );
    } catch (e) {
      print('❌ خطأ في جلب وحدات القياس: $e');
      return [];
    }
  }

  Future<int> insertUnit(Map<String, dynamic> unit) async {
    try {
      final db = await database;

      // التحقق من عدم التكرار
      final existing = await db.query(
        'units',
        where: 'name = ? AND is_active = 1',
        whereArgs: [unit['name']],
      );

      if (existing.isNotEmpty) {
        throw Exception('الوحدة "${unit['name']}" موجودة بالفعل');
      }

      return await db.insert('units', {
        ...unit,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ خطأ في إضافة وحدة القياس: $e');
      rethrow;
    }
  }

  Future<int> updateUnit(int id, Map<String, dynamic> unit) async {
    try {
      final db = await database;
      return await db.update(
        'units',
        {
          ...unit,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ خطأ في تحديث وحدة القياس: $e');
      rethrow;
    }
  }

  Future<int> deleteUnit(int id) async {
    try {
      final db = await database;
      return await db.update(
        'units',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ خطأ في حذف وحدة القياس: $e');
      rethrow;
    }
  }

// 2. إدارة إعدادات الباركود
  Future<Map<String, dynamic>> getBarcodeSettings() async {
    try {
      final db = await database;
      final result = await db.query('barcode_settings', limit: 1);

      if (result.isNotEmpty) {
        return result.first;
      } else {
        // إعدادات افتراضية
        return {
          'id': 1,
          'barcode_type': 'CODE128',
          'width': 2,
          'height': 100,
          'include_price': 0,
          'include_name': 1,
        };
      }
    } catch (e) {
      print('❌ خطأ في جلب إعدادات الباركود: $e');
      return {
        'barcode_type': 'CODE128',
        'width': 2,
        'height': 100,
        'include_price': 0,
        'include_name': 1,
      };
    }
  }

  Future<void> updateBarcodeSettings(Map<String, dynamic> settings) async {
    try {
      final db = await database;

      // التحقق من وجود الإعدادات
      final existing = await db.query('barcode_settings', limit: 1);

      if (existing.isNotEmpty) {
        // تحديث الإعدادات الموجودة
        await db.update(
          'barcode_settings',
          {
            'barcode_type': settings['barcode_type'],
            'width': settings['width'],
            'height': settings['height'],
            'include_price': settings['include_price'],
            'include_name': settings['include_name'],
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        // إضافة إعدادات جديدة
        await db.insert('barcode_settings', {
          'barcode_type': settings['barcode_type'],
          'width': settings['width'],
          'height': settings['height'],
          'include_price': settings['include_price'],
          'include_name': settings['include_name'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('❌ خطأ في تحديث إعدادات الباركود: $e');
      rethrow;
    }
  }

// 3. إدارة شروط الدفع
  Future<List<Map<String, dynamic>>> getPaymentTerms() async {
    try {
      final db = await database;
      return await db.query('payment_terms',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
    } catch (e) {
      print('❌ خطأ في جلب شروط الدفع: $e');
      return [];
    }
  }

  Future<int> insertPaymentTerm(Map<String, dynamic> term) async {
    try {
      final db = await database;

      // التحقق من عدم التكرار
      final existing = await db.query(
        'payment_terms',
        where: 'name = ? AND is_active = 1',
        whereArgs: [term['name']],
      );

      if (existing.isNotEmpty) {
        throw Exception('شرط الدفع "${term['name']}" موجود بالفعل');
      }

      return await db.insert('payment_terms', {
        ...term,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ خطأ في إضافة شرط الدفع: $e');
      rethrow;
    }
  }

// 4. إدارة سياسات الإرجاع
  Future<List<Map<String, dynamic>>> getReturnPolicies() async {
    try {
      final db = await database;
      return await db.query('return_policies',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
    } catch (e) {
      print('❌ خطأ في جلب سياسات الإرجاع: $e');
      return [];
    }
  }

  Future<int> insertReturnPolicy(Map<String, dynamic> policy) async {
    try {
      final db = await database;

      // التحقق من عدم التكرار
      final existing = await db.query(
        'return_policies',
        where: 'name = ? AND is_active = 1',
        whereArgs: [policy['name']],
      );

      if (existing.isNotEmpty) {
        throw Exception('سياسة الإرجاع "${policy['name']}" موجودة بالفعل');
      }

      return await db.insert('return_policies', {
        ...policy,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ خطأ في إضافة سياسة الإرجاع: $e');
      rethrow;
    }
  }

// 5. دوال إدارة الإعدادات المتقدمة
  Future<Map<String, dynamic>> getAdvancedSettings() async {
    try {
      final db = await database;
      final result = await db.query('system_settings');

      Map<String, dynamic> settings = {};
      for (var setting in result) {
        final key = setting['setting_key'] as String;
        final value = setting['setting_value'];
        final type = setting['setting_type'] as String;

        switch (type) {
          case 'boolean':
            settings[key] = value == '1' || value == 1;
            break;
          case 'int':
            settings[key] = int.tryParse(value.toString()) ?? 0;
            break;
          case 'double':
            settings[key] = double.tryParse(value.toString()) ?? 0.0;
            break;
          default:
            settings[key] = value;
        }
      }

      // تعيين القيم الافتراضية للإعدادات المفقودة
      settings['auto_print_invoice'] ??= false;
      settings['track_serial_numbers'] ??= false;
      settings['track_expiry_dates'] ??= false;
      settings['auto_purchase_orders'] ??= false;
      settings['email_reports'] ??= false;
      settings['two_factor_auth'] ??= false;
      settings['ip_restriction'] ??= false;
      settings['enable_caching'] ??= true;
      settings['app_language'] ??= 'العربية';
      settings['app_theme'] ??= 'فاتح';

      return settings;
    } catch (e) {
      print('❌ خطأ في جلب الإعدادات المتقدمة: $e');
      return {};
    }
  }

  Future<void> updateAdvancedSetting(String key, dynamic value) async {
    try {
      final db = await database;

      // تحديد نوع القيمة
      String type = 'string';
      String stringValue = value.toString();

      if (value is bool) {
        type = 'boolean';
        stringValue = value ? '1' : '0';
      } else if (value is int) {
        type = 'int';
      } else if (value is double) {
        type = 'double';
      }

      // التحقق من وجود الإعداد
      final existing = await db.query(
        'system_settings',
        where: 'setting_key = ?',
        whereArgs: [key],
      );

      if (existing.isNotEmpty) {
        // تحديث الإعداد الموجود
        await db.update(
          'system_settings',
          {
            'setting_value': stringValue,
            'setting_type': type,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'setting_key = ?',
          whereArgs: [key],
        );
      } else {
        // إضافة إعداد جديد
        await db.insert('system_settings', {
          'setting_key': key,
          'setting_value': stringValue,
          'setting_type': type,
          'description': 'إعداد مضافة من شاشة الإعدادات',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      print('❌ خطأ في تحديث الإعداد المتقدم: $e');
      rethrow;
    }
  }

// 6. دوال الصيانة والإدارة
  Future<void> compressDatabase() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
      print('✅ تم ضغط قاعدة البيانات بنجاح');
    } catch (e) {
      print('❌ خطأ في ضغط قاعدة البيانات: $e');
      rethrow;
    }
  }

  Future<void> rebuildDatabaseIndexes() async {
    try {
      final db = await database;

      // حذف الفهارس الحالية
      await db.execute('DROP INDEX IF EXISTS idx_warehouse_stock_product');
      await db.execute('DROP INDEX IF EXISTS idx_warehouse_stock_warehouse');
      await db.execute('DROP INDEX IF EXISTS idx_purchase_invoice_date');
      await db.execute('DROP INDEX IF EXISTS idx_sale_invoice_date');
      await db.execute('DROP INDEX IF EXISTS idx_audit_log_created_at');
      await db.execute('DROP INDEX IF EXISTS idx_cash_ledger_date');

      // إعادة إنشاء الفهارس
      await _createIndexes(db);
      print('✅ تم إعادة بناء فهارس قاعدة البيانات بنجاح');
    } catch (e) {
      print('❌ خطأ في إعادة بناء الفهارس: $e');
      rethrow;
    }
  }

  Future<String> exportDatabaseToJson() async {
    try {
      final db = await database;

      Map<String, dynamic> exportData = {};

      // تصدير البيانات الرئيسية
      exportData['warehouses'] = await db.query('warehouses');
      exportData['suppliers'] = await db.query('suppliers');
      exportData['customers'] = await db.query('customers');
      exportData['products'] = await db.query('products');
      exportData['categories'] = await db.query('categories');
      exportData['sale_invoices'] = await db.query('sale_invoices');
      exportData['purchase_invoices'] = await db.query('purchase_invoices');

      final jsonString = jsonEncode(exportData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // حفظ في ملف
      final Directory tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/backup_$timestamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonString);

      print('✅ تم تصدير قاعدة البيانات إلى: $filePath');
      return filePath;
    } catch (e) {
      print('❌ خطأ في تصدير قاعدة البيانات: $e');
      rethrow;
    }
  }

// 7. دالة حذف قاعدة البيانات وإعادة الإنشاء (خطيرة - استخدام بحذر)
  Future<Map<String, dynamic>> resetDatabase() async {
    try {
      final db = await database;

      // الحصول على مسار قاعدة البيانات
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'inventory_system.db');

      // نسخ قاعدة البيانات احتياطياً
      final backupPath = '${path}_backup_${DateTime.now().millisecondsSinceEpoch}';
      final file = File(path);
      await file.copy(backupPath);

      // إغلاق قاعدة البيانات
      await db.close();
      _db = null;

      // حذف ملف قاعدة البيانات
      await file.delete();

      // إعادة إنشاء قاعدة البيانات
      await initDb();

      return {
        'success': true,
        'message': 'تم حذف وإعادة إنشاء قاعدة البيانات بنجاح',
        'backup_path': backupPath,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف قاعدة البيانات: ${e.toString()}',
      };
    }
  }

  Future<Map<String, dynamic>> clearAllData() async {
    try {
      final db = await database;

      await db.transaction((txn) async {
        // حذف جميع البيانات مع الحفاظ على الجداول
        await txn.delete('warehouse_stock');
        await txn.delete('sale_items');
        await txn.delete('sale_invoices');
        await txn.delete('purchase_items');
        await txn.delete('purchase_invoices');
        await txn.delete('sale_return_items');
        await txn.delete('sale_returns');
        await txn.delete('stock_transfer_items');
        await txn.delete('stock_transfers');
        await txn.delete('adjustment_items');
        await txn.delete('inventory_adjustments');
        await txn.delete('receipt_vouchers');
        await txn.delete('payment_vouchers');
        await txn.delete('cash_ledger');
        await txn.delete('audit_log');

        // إعادة تعيين المنتجات
        await txn.update('products', {'current_quantity': 0});

        // إعادة تعيين أرصدة العملاء والموردين
        await txn.update('customers', {'balance': 0});
        await txn.update('suppliers', {'balance': 0});
      });

      return {
        'success': true,
        'message': 'تم مسح جميع البيانات بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في مسح البيانات: ${e.toString()}',
      };
    }
  }

// 8. دوال التحقق من سلامة قاعدة البيانات
  Future<Map<String, dynamic>> checkDatabaseIntegrity() async {
    try {
      final db = await database;

      final integrityCheck = await db.rawQuery('PRAGMA integrity_check');
      final foreignKeysCheck = await db.rawQuery('PRAGMA foreign_key_check');

      // فحص الأخطاء الشائعة
      final missingRelations = await db.rawQuery('''
      SELECT 
        'products' as table_name,
        COUNT(*) as orphaned_records
      FROM products 
      WHERE category_id NOT IN (SELECT id FROM categories WHERE is_active = 1) 
        AND category_id IS NOT NULL
      
      UNION ALL
      
      SELECT 
        'sale_invoices' as table_name,
        COUNT(*) as orphaned_records
      FROM sale_invoices 
      WHERE customer_id NOT IN (SELECT id FROM customers WHERE is_active = 1) 
        AND customer_id IS NOT NULL
      
      UNION ALL
      
      SELECT 
        'warehouse_stock' as table_name,
        COUNT(*) as orphaned_records
      FROM warehouse_stock 
      WHERE product_id NOT IN (SELECT id FROM products WHERE is_active = 1)
    ''');

      return {
        'success': true,
        'integrity_check': integrityCheck,
        'foreign_keys_check': foreignKeysCheck,
        'data_integrity': missingRelations,
        'message': 'فحص سلامة قاعدة البيانات مكتمل',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في فحص سلامة قاعدة البيانات: ${e.toString()}',
      };
    }
  }

// 9. دوال إحصائيات قاعدة البيانات
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final db = await database;

      final stats = await db.rawQuery('''
      SELECT 
        name as table_name,
        COUNT(*) as row_count
      FROM sqlite_master 
      WHERE type = 'table' 
        AND name NOT LIKE 'sqlite_%'
      GROUP BY name
      ORDER BY row_count DESC
    ''');

      final sizeQuery = await db.rawQuery('PRAGMA page_size');
      final countQuery = await db.rawQuery('PRAGMA page_count');

      final pageSize = sizeQuery.first['page_size'] as int? ?? 4096;
      final pageCount = countQuery.first['page_count'] as int? ?? 0;
      final totalSize = pageSize * pageCount;

      return {
        'success': true,
        'table_stats': stats,
        'database_size': totalSize,
        'page_size': pageSize,
        'page_count': pageCount,
        'total_tables': stats.length,
        'total_records': stats.fold<int>(0, (sum, table) => sum + (table['row_count'] as int)),
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في جلب إحصائيات قاعدة البيانات: ${e.toString()}',
      };
    }
  }

// 10. دالة للتحقق من اتصال قاعدة البيانات
  Future<bool> testDatabaseConnection() async {
    try {
      final db = await database;

      // محاولة تنفيذ استعلام بسيط
      await db.rawQuery('SELECT 1');

      // فحص بعض الجداول الأساسية
      final tables = ['users', 'products', 'customers', 'suppliers'];

      for (final table in tables) {
        try {
          await db.rawQuery('SELECT COUNT(*) FROM $table');
        } catch (e) {
          print('❌ جدول $table غير متاح: $e');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('❌ فشل اختبار اتصال قاعدة البيانات: $e');
      return false;
    }
  }

// 11. دوال إدارة المستخدمين (توسيع)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final db = await database;
      return await db.query('users',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
    } catch (e) {
      print('❌ خطأ في جلب المستخدمين: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'id = ? AND is_active = 1',
        whereArgs: [id],
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ خطأ في جلب المستخدم: $e');
      return null;
    }
  }

  Future<int> changeUserPassword(int userId, String newPassword) async {
    try {
      final db = await database;
      return await db.update(
        'users',
        {
          'password': newPassword,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      print('❌ خطأ في تغيير كلمة المرور: $e');
      rethrow;
    }
  }

// 12. دوال تسجيل الدخول والجلسات
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      final db = await database;
      final result = await db.query(
        'users',
        where: 'username = ? AND password = ? AND is_active = 1',
        whereArgs: [username, password],
      );

      if (result.isNotEmpty) {
        // تحديث وقت آخر تسجيل دخول
        await db.update(
          'users',
          {
            'last_login': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [result.first['id']],
        );

        return result.first;
      }
      return null;
    } catch (e) {
      print('❌ خطأ في المصادقة: $e');
      return null;
    }
  }

  Future<void> logUserActivity(int userId, String action, String description) async {
    try {
      final db = await database;
      await db.insert('audit_log', {
        'user_id': userId,
        'action': action,
        'description': description,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ خطأ في تسجيل النشاط: $e');
    }
  }

  getTemporaryDirectory() {}
//
// ========== دوال ترقيم الفواتير ==========

// 1. إعدادات ترقيم الفواتير
  Future<Map<String, dynamic>> getInvoiceNumberingSettings(String invoiceType) async {
    try {
      final db = await database;
      final result = await db.query(
        'invoice_numbering',
        where: 'invoice_type = ? AND is_active = 1',
        whereArgs: [invoiceType],
      );
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      print('❌ خطأ في جلب إعدادات الترقيم: $e');
      return {};
    }
  }

// 2. الحصول على جميع إعدادات الترقيم
  Future<List<Map<String, dynamic>>> getAllInvoiceNumberingSettings() async {
    try {
      final db = await database;
      return await db.query(
        'invoice_numbering',
        where: 'is_active = 1',
        orderBy: 'invoice_type',
      );
    } catch (e) {
      print('❌ خطأ في جلب إعدادات الترقيم: $e');
      return [];
    }
  }

// 3. تحديث إعدادات الترقيم
  Future<Map<String, dynamic>> updateInvoiceNumberingSettings(
      String invoiceType, Map<String, dynamic> settings) async {
    try {
      final db = await database;

      // التحقق من وجود السجل
      final existing = await db.query(
        'invoice_numbering',
        where: 'invoice_type = ?',
        whereArgs: [invoiceType],
      );

      if (existing.isNotEmpty) {
        // تحديث السجل الموجود
        await db.update(
          'invoice_numbering',
          {
            ...settings,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'invoice_type = ?',
          whereArgs: [invoiceType],
        );
      } else {
        // إضافة سجل جديد
        await db.insert('invoice_numbering', {
          'invoice_type': invoiceType,
          ...settings,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return {
        'success': true,
        'message': 'تم تحديث إعدادات الترقيم بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في تحديث إعدادات الترقيم: ${e.toString()}',
      };
    }
  }

// 4. توليد رقم فاتورة جديد
  Future<String> generateInvoiceNumber(String invoiceType) async {
    try {
      final db = await database;

      // الحصول على إعدادات الترقيم
      final settings = await getInvoiceNumberingSettings(invoiceType);

      if (settings.isEmpty) {
        // إعدادات افتراضية
        final defaultPrefix = _getDefaultPrefix(invoiceType);
        final invoiceNumber = '${defaultPrefix}${DateTime.now().millisecondsSinceEpoch}';
        return invoiceNumber;
      }

      var currentNumber = settings['current_number'] ?? 1;
      final prefix = settings['prefix'] ?? '';
      final suffix = settings['suffix'] ?? '';
      final numberLength = settings['number_length'] ?? 5;

      // تنسيق الرقم ليكون بطول ثابت
      final formattedNumber = currentNumber.toString().padLeft(numberLength, '0');
      final invoiceNumber = '$prefix$formattedNumber$suffix';

      // زيادة الرقم الحالي
      await db.update(
        'invoice_numbering',
        {
          'current_number': currentNumber + 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'invoice_type = ?',
        whereArgs: [invoiceType],
      );

      // حفظ الرقم في سلسلة الأرقام
      await db.insert('invoice_sequences', {
        'invoice_type': invoiceType,
        'invoice_number': invoiceNumber,
        'invoice_date': DateTime.now().toIso8601String(),
      });

      return invoiceNumber;
    } catch (e) {
      print('❌ خطأ في توليد رقم الفاتورة: $e');
      return '${_getDefaultPrefix(invoiceType)}${DateTime.now().millisecondsSinceEpoch}';
    }
  }

// 5. دالة مساعدة للحصول على البادئة الافتراضية
  String _getDefaultPrefix(String invoiceType) {
    switch (invoiceType) {
      case 'sale':
        return 'SALE-';
      case 'purchase':
        return 'PUR-';
      case 'sale_return':
        return 'SR-';
      case 'purchase_return':
        return 'PR-';
      case 'stock_transfer':
        return 'ST-';
      case 'inventory_adjustment':
        return 'IA-';
      default:
        return 'INV-';
    }
  }

// 6. إعادة تعيين أرقام الفواتير
  Future<Map<String, dynamic>> resetInvoiceNumbers(String invoiceType, int newNumber) async {
    try {
      final db = await database;

      await db.update(
        'invoice_numbering',
        {
          'current_number': newNumber,
          'last_reset_date': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'invoice_type = ?',
        whereArgs: [invoiceType],
      );

      return {
        'success': true,
        'message': 'تم إعادة تعيين أرقام الفواتير بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إعادة التعيين: ${e.toString()}',
      };
    }
  }

// ========== دوال شروط الدفع ==========

// 1. الحصول على جميع شروط الدفع
  Future<List<Map<String, dynamic>>> getAllPaymentTerms() async {
    try {
      final db = await database;
      return await db.query(
        'payment_terms',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
    } catch (e) {
      print('❌ خطأ في جلب شروط الدفع: $e');
      return [];
    }
  }

// 2. إضافة شرط دفع جديد
  Future<Map<String, dynamic>> createPaymentTerm(Map<String, dynamic> term) async {
    try {
      final db = await database;

      // التحقق من عدم التكرار
      final existing = await db.query(
        'payment_terms',
        where: 'name = ?',
        whereArgs: [term['name']],
      );

      if (existing.isNotEmpty) {
        return {
          'success': false,
          'error': 'شرط الدفع "${term['name']}" موجود بالفعل',
        };
      }

      final id = await db.insert('payment_terms', {
        ...term,
        'created_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'id': id,
        'message': 'تم إضافة شرط الدفع بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إضافة شرط الدفع: ${e.toString()}',
      };
    }
  }

// 3. تحديث شرط دفع
  Future<Map<String, dynamic>> updatePaymentTerm(int id, Map<String, dynamic> term) async {
    try {
      final db = await database;

      await db.update(
        'payment_terms',
        {
          ...term,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return {
        'success': true,
        'message': 'تم تحديث شرط الدفع بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في تحديث شرط الدفع: ${e.toString()}',
      };
    }
  }

// 4. حذف شرط دفع
  Future<Map<String, dynamic>> deletePaymentTerm(int id) async {
    try {
      final db = await database;

      await db.update(
        'payment_terms',
        {
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return {
        'success': true,
        'message': 'تم حذف شرط الدفع بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف شرط الدفع: ${e.toString()}',
      };
    }
  }

// ========== دوال سياسات الإرجاع ==========

// 1. الحصول على جميع سياسات الإرجاع
  Future<List<Map<String, dynamic>>> getAllReturnPolicies() async {
    try {
      final db = await database;
      return await db.query(
        'return_policies',
        where: 'is_active = 1',
        orderBy: 'name ASC',
      );
    } catch (e) {
      print('❌ خطأ في جلب سياسات الإرجاع: $e');
      return [];
    }
  }

// 2. إضافة سياسة إرجاع جديدة
  Future<Map<String, dynamic>> createReturnPolicy(Map<String, dynamic> policy) async {
    try {
      final db = await database;

      // التحقق من عدم التكرار
      final existing = await db.query(
        'return_policies',
        where: 'name = ?',
        whereArgs: [policy['name']],
      );

      if (existing.isNotEmpty) {
        return {
          'success': false,
          'error': 'سياسة الإرجاع "${policy['name']}" موجودة بالفعل',
        };
      }

      final id = await db.insert('return_policies', {
        ...policy,
        'created_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'id': id,
        'message': 'تم إضافة سياسة الإرجاع بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في إضافة سياسة الإرجاع: ${e.toString()}',
      };
    }
  }

// 3. تحديث سياسة إرجاع
  Future<Map<String, dynamic>> updateReturnPolicy(int id, Map<String, dynamic> policy) async {
    try {
      final db = await database;

      await db.update(
        'return_policies',
        {
          ...policy,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return {
        'success': true,
        'message': 'تم تحديث سياسة الإرجاع بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في تحديث سياسة الإرجاع: ${e.toString()}',
      };
    }
  }

// 4. حذف سياسة إرجاع
  Future<Map<String, dynamic>> deleteReturnPolicy(int id) async {
    try {
      final db = await database;

      await db.update(
        'return_policies',
        {
          'is_active': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      return {
        'success': true,
        'message': 'تم حذف سياسة الإرجاع بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في حذف سياسة الإرجاع: ${e.toString()}',
      };
    }
  }

// 5. الحصول على السياسة الافتراضية للإرجاع
  Future<Map<String, dynamic>?> getDefaultReturnPolicy() async {
    try {
      final db = await database;
      final result = await db.query(
        'return_policies',
        where: 'is_active = 1',
        orderBy: 'id ASC',
        limit: 1,
      );
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      print('❌ خطأ في جلب السياسة الافتراضية للإرجاع: $e');
      return null;
    }
  }

// 6. تعيين سياسة إرجاع كافتراضية
  Future<Map<String, dynamic>> setDefaultReturnPolicy(int id) async {
    try {
      final db = await database;

      // إلغاء التعيين الافتراضي لجميع السياسات
      await db.update(
        'return_policies',
        {'is_default': 0},
        where: 'is_default = 1',
      );

      // تعيين السياسة الجديدة كافتراضية
      await db.update(
        'return_policies',
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [id],
      );

      return {
        'success': true,
        'message': 'تم تعيين السياسة كافتراضية بنجاح',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'فشل في تعيين السياسة: ${e.toString()}',
      };
    }
  }
}