import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:untitled43/password_policy.dart';
import 'package:untitled43/payment_terms_screen.dart';
import 'package:untitled43/return_policies_screen.dart';
import 'package:untitled43/users_management.dart';

// استيراد فئة قاعدة البيانات
import 'database_helper.dart';
import 'settings_store.dart';
// استيراد الألوان
import 'app_colors.dart';
import 'invoice_numbering_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SettingsStore _store = SettingsStore();
  Map<String, dynamic> _settings = {};
  Map<String, dynamic> _advancedSettings = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _confirmDeleteController = TextEditingController();
  bool _deleteConfirmed = false;

  @override
  void initState() {
    super.initState();
    // initialize local view of settings from central store
    _store.addListener(_onStoreChanged);
    if (!_store.initialized) {
      _store.load();
    }
    _loadAllSettings();
  }

  void _onStoreChanged() {
    setState(() {
      _settings = _store.settings;
      _advancedSettings = _store.advancedSettings;
      _isLoading = false;
    });
  }

  // دالة لتحميل جميع الإعدادات من قاعدة البيانات
  Future<void> _loadAllSettings() async {
    setState(() => _isLoading = true);
    try {
      // read from central SettingsStore (which will load from DB if needed)
      _settings = _store.settings;
      _advancedSettings = _store.advancedSettings;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الإعدادات: ${e.toString()}')),
      );
    }
  }

  // دالة لتحديث إعداد معين وحفظه في قاعدة البيانات
  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _store.setSetting(key, value);
      setState(() {
        _settings[key] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حفظ الإعداد بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في حفظ الإعداد: ${e.toString()}')),
      );
    }
  }

  // دالة لتحديث إعداد متقدم
  Future<void> _updateAdvancedSetting(String key, dynamic value) async {
    try {
      await _store.setAdvanced(key, value);
      setState(() {
        _advancedSettings[key] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تحديث الإعداد المتقدم')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تحديث الإعداد: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _searchController.dispose();
    _confirmDeleteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإعدادات المتقدمة'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAllSettings,
            tooltip: 'تحديث الإعدادات',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // شريط البحث
            _buildSearchBar(),
            SizedBox(height: 20),

            // 1. الإعدادات العامة
            _buildSectionHeader('الإعدادات العامة', Icons.settings),
            _buildGeneralSettings(),
            SizedBox(height: 20),

            // 2. المنتجات والمخزون
            _buildSectionHeader('المنتجات والمخزون', Icons.inventory),
            _buildProductInventorySettings(),
            SizedBox(height: 20),

            // 3. المبيعات والفواتير
            _buildSectionHeader('المبيعات والفواتير', Icons.receipt),
            _buildSalesInvoiceSettings(),
            SizedBox(height: 20),

            // 4. المشتريات والموردين
            _buildSectionHeader('المشتريات والموردين', Icons.shopping_cart),
            _buildPurchaseSupplierSettings(),
            SizedBox(height: 20),

            // 5. التقارير والتحليلات
            _buildSectionHeader('التقارير والتحليلات', Icons.analytics),
            _buildReportsAnalyticsSettings(),
            SizedBox(height: 20),

            // 6. الأمان والمستخدمون
            _buildSectionHeader('الأمان والمستخدمون', Icons.security),
            _buildSecurityUserSettings(),
            SizedBox(height: 20),

            // 7. التخصيص والمظهر
            _buildSectionHeader('التخصيص والمظهر', Icons.palette),
            _buildCustomizationSettings(),
            SizedBox(height: 20),

            // 8. الصيانة والإدارة
            _buildSectionHeader('الصيانة والإدارة', Icons.build),
            _buildMaintenanceSettings(),
            SizedBox(height: 20),

            // 9. النسخ الاحتياطي والاستعادة
            _buildSectionHeader('النسخ الاحتياطي والاستعادة', Icons.backup),
            _buildBackupRestoreSection(),
            SizedBox(height: 20),

            // 10. حذف قاعدة البيانات (خطر)
            _buildSectionHeader('خيارات خطيرة', Icons.dangerous),
            _buildDangerZone(),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- ويدجت البحث والعناوين ---
  Widget _buildSearchBar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث في الإعدادات...',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  // يمكن إضافة منطق البحث هنا
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  FocusScope.of(context).unfocus();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.0, left: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // --- دوال بناء أقسام الإعدادات ---

  Widget _buildGeneralSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'اسم الشركة',
              value: _settings['company_name'] ?? 'شركة إدارة المخزون',
              icon: Icons.business,
              onTap: _showEditCompanyDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'العملة الافتراضية',
              value: _settings['default_currency'] ?? 'ريال',
              icon: Icons.monetization_on,
              onTap: _showEditCurrencyDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'الضرائب الافتراضية',
              value: '${_settings['default_tax_rate'] ?? 15.0}%',
              icon: Icons.percent,
              onTap: _showEditTaxDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('التنبيهات والإشعارات'),
              subtitle: Text('عرض تنبيهات المخزون المنخفض'),
              secondary: Icon(Icons.notifications_active, color: AppColors.primary),
              value: _settings['enable_notifications'] ?? true,
              onChanged: (value) => _updateSetting('enable_notifications', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInventorySettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'وحدات القياس',
              value: 'إدارة وحدات القياس',
              icon: Icons.straighten,
              onTap: _showUnitsDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'إعدادات الباركود',
              value: 'تكوين الباركود والماسح الضوئي',
              icon: Icons.qr_code_scanner,
              onTap: _showBarcodeSettings,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('تتبع الأرقام التسلسلية'),
              subtitle: Text('تفعيل تتبع الأرقام التسلسلية للمنتجات'),
              secondary: Icon(Icons.confirmation_number, color: AppColors.primary),
              value: _advancedSettings['track_serial_numbers'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('track_serial_numbers', value),
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('تتبع تاريخ انتهاء الصلاحية'),
              subtitle: Text('تفعيل تتبع تواريخ انتهاء الصلاحية'),
              secondary: Icon(Icons.calendar_today, color: AppColors.primary),
              value: _advancedSettings['track_expiry_dates'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('track_expiry_dates', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesInvoiceSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'ترقيم الفواتير',
              value: 'تكوين نمط ترقيم الفواتير',
              icon: Icons.format_list_numbered,
              onTap: _showInvoiceNumberingDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'شروط الدفع',
              value: 'إدارة شروط الدفع للعملاء',
              icon: Icons.payment,
              onTap: _showPaymentTermsDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'سياسات الإرجاع',
              value: 'تحديد شروط ومدة الإرجاع',
              icon: Icons.assignment_return,
              onTap: _showReturnPoliciesDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('طباعة تلقائية'),
              subtitle: Text('طباعة الفاتورة تلقائياً بعد إنشائها'),
              secondary: Icon(Icons.print, color: AppColors.primary),
              value: _advancedSettings['auto_print_invoice'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('auto_print_invoice', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseSupplierSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'شروط الدفع للموردين',
              value: 'إدارة شروط الدفع',
              icon: Icons.account_balance,
              onTap: _showSupplierPaymentTermsDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('طلب الشراء التلقائي'),
              subtitle: Text('إنشاء طلبات شراء عند وصول المخزون للحد الأدنى'),
              secondary: Icon(Icons.shopping_basket, color: AppColors.primary),
              value: _advancedSettings['auto_purchase_orders'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('auto_purchase_orders', value),
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'تقييم الموردين',
              value: 'معايير تقييم أداء الموردين',
              icon: Icons.star_rate,
              onTap: _showSupplierEvaluationSettings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsAnalyticsSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'التقارير المجدولة',
              value: 'جدولة إرسال التقارير',
              icon: Icons.schedule_send,
              onTap: _showScheduledReportsDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('إرسال التقارير عبر البريد'),
              subtitle: Text('تفعيل إرسال التقارير عبر البريد الإلكتروني'),
              secondary: Icon(Icons.email, color: AppColors.primary),
              value: _advancedSettings['email_reports'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('email_reports', value),
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'صيغ التصدير',
              value: 'اختيار صيغ التصدير الافتراضية',
              icon: Icons.file_download,
              onTap: _showExportFormatsDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityUserSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'إدارة المستخدمين',
              value: 'إضافة، تعديل، وحذف المستخدمين',
              icon: Icons.people,
              onTap: _showUsersManagement,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'سياسات كلمات المرور',
              value: 'تكوين متطلبات كلمات المرور',
              icon: Icons.lock,
              onTap: _showPasswordPolicyDialog,
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('المصادقة الثنائية'),
              subtitle: Text('تفعيل المصادقة الثنائية للمستخدمين'),
              secondary: Icon(Icons.verified_user, color: AppColors.primary),
              value: _advancedSettings['two_factor_auth'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('two_factor_auth', value),
            ),
            Divider(height: 20),
            SwitchListTile(
              title: Text('تقييد عنوان IP'),
              subtitle: Text('تقييد الوصول بعناوين IP محددة'),
              secondary: Icon(Icons.network_check, color: AppColors.primary),
              value: _advancedSettings['ip_restriction'] ?? false,
              onChanged: (value) => _updateAdvancedSetting('ip_restriction', value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomizationSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'لغة التطبيق',
              value: _advancedSettings['app_language'] ?? 'العربية',
              icon: Icons.language,
              onTap: _showLanguageDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'مظهر الواجهة',
              value: _advancedSettings['app_theme'] ?? 'فاتح',
              icon: Icons.palette,
              onTap: _showThemeDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'تنسيق التاريخ',
              value: 'تحديد تنسيق التاريخ والوقت',
              icon: Icons.date_range,
              onTap: _showDateTimeFormatDialog,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'تنسيق العملة',
              value: 'تحديد تنسيق الأرقام والعملة',
              icon: Icons.attach_money,
              onTap: _showNumberFormatDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSettings() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSettingItem(
              title: 'فحص سلامة قاعدة البيانات',
              value: 'فحص الأخطاء والمشاكل',
              icon: Icons.health_and_safety,
              onTap: _checkDatabaseIntegrity,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'ضغط قاعدة البيانات',
              value: 'تحسين الأداء وتقليل المساحة',
              icon: Icons.compress,
              onTap: _compressDatabase,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'إعادة بناء الفهارس',
              value: 'تحسين سرعة البحث والاستعلامات',
              icon: Icons.build,
              onTap: _rebuildIndexes,
            ),
            Divider(height: 20),
            _buildSettingItem(
              title: 'إحصائيات قاعدة البيانات',
              value: 'عرض معلومات وحجم البيانات',
              icon: Icons.storage,
              onTap: _showDatabaseStats,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRestoreSection() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.backup, size: 24),
              label: Text('إنشاء نسخة احتياطية الآن', style: TextStyle(fontSize: 16)),
              onPressed: _createBackupNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.restore, size: 24),
              label: Text('استعادة من نسخة احتياطية', style: TextStyle(fontSize: 16)),
              onPressed: _restoreBackup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              icon: Icon(Icons.download, size: 24),
              label: Text('تصدير البيانات إلى JSON', style: TextStyle(fontSize: 16)),
              onPressed: _exportDatabaseToJson,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.red, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '⚠️ تحذير: هذه الإجراءات لا يمكن التراجع عنها!',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 15),

            // مسح جميع البيانات
            ElevatedButton.icon(
              icon: Icon(Icons.delete_sweep, size: 24),
              label: Text('مسح جميع البيانات', style: TextStyle(fontSize: 16)),
              onPressed: _showClearDataConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),

            // إعادة تعيين قاعدة البيانات
            ElevatedButton.icon(
              icon: Icon(Icons.restart_alt, size: 24),
              label: Text('إعادة تعيين قاعدة البيانات', style: TextStyle(fontSize: 16)),
              onPressed: _showResetDatabaseConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            SizedBox(height: 10),

            // حذف قاعدة البيانات بالكامل
            ElevatedButton.icon(
              icon: Icon(Icons.delete_forever, size: 24),
              label: Text('حذف قاعدة البيانات بالكامل', style: TextStyle(fontSize: 16)),
              onPressed: _showDeleteDatabaseConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  // --- دوال النوافذ المنبثقة (Dialogs) الحقيقية ---

  void _showEditCompanyDialog() {
    final TextEditingController _controller = TextEditingController(
        text: _settings['company_name'] ?? 'شركة إدارة المخزون'
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل اسم الشركة'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'اسم الشركة',
            border: OutlineInputBorder(),
            hintText: 'أدخل اسم الشركة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_controller.text.trim().isNotEmpty) {
                _updateSetting('company_name', _controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditCurrencyDialog() {
    final List<String> currencies = ['ريال', 'درهم', 'دينار', 'دولار', 'يورو', 'جنيه'];
    String selectedCurrency = _settings['default_currency'] ?? 'ريال';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر العملة الافتراضية'),
            content: Container(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  return RadioListTile<String>(
                    title: Text(currency),
                    value: currency,
                    groupValue: selectedCurrency,
                    onChanged: (value) {
                      setState(() {
                        selectedCurrency = value!;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateSetting('default_currency', selectedCurrency);
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTaxDialog() {
    final TextEditingController _controller = TextEditingController(
        text: (_settings['default_tax_rate'] ?? 15.0).toString()
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل نسبة الضريبة الافتراضية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'نسبة الضريبة (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            SizedBox(height: 10),
            Text(
              'القيمة الحالية: ${_settings['default_tax_rate'] ?? 15.0}%',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final taxRate = double.tryParse(_controller.text) ?? 0.0;
              if (taxRate >= 0 && taxRate <= 100) {
                _updateSetting('default_tax_rate', taxRate);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('يجب أن تكون نسبة الضريبة بين 0 و 100')),
                );
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showUnitsDialog() async {
    try {
      final units = await _dbHelper.getUnits();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.straighten, color: AppColors.primary),
              SizedBox(width: 10),
              Text('إدارة وحدات القياس'),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                Expanded(
                  child: units.isEmpty
                      ? Center(
                    child: Text(
                      'لا توجد وحدات قياس',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: units.length,
                    itemBuilder: (context, index) {
                      final unit = units[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(unit['name']),
                          subtitle: Text(
                            unit['abbreviation'] ?? '',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  _showEditUnitDialog(unit);
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteUnitConfirmation(unit);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 10),
                Divider(),
                ElevatedButton.icon(
                  icon: Icon(Icons.add),
                  label: Text('إضافة وحدة جديدة'),
                  onPressed: _showAddUnitDialog,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 45),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل وحدات القياس: ${e.toString()}')),
      );
    }
  }

  void _showAddUnitDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController abbreviationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة وحدة قياس جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'اسم الوحدة',
                border: OutlineInputBorder(),
                hintText: 'مثال: كيلوجرام',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: abbreviationController,
              decoration: InputDecoration(
                labelText: 'الاختصار (اختياري)',
                border: OutlineInputBorder(),
                hintText: 'مثال: كج',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.insertUnit({
                    'name': nameController.text.trim(),
                    'abbreviation': abbreviationController.text.trim().isNotEmpty
                        ? abbreviationController.text.trim()
                        : null,
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم إضافة الوحدة بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة الوحدات
                  _showUnitsDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في إضافة الوحدة: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showEditUnitDialog(Map<String, dynamic> unit) {
    final TextEditingController nameController = TextEditingController(text: unit['name']);
    final TextEditingController abbreviationController = TextEditingController(
        text: unit['abbreviation'] ?? ''
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل وحدة القياس'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'اسم الوحدة',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: abbreviationController,
              decoration: InputDecoration(
                labelText: 'الاختصار',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                try {
                  await _dbHelper.updateUnit(unit['id'], {
                    'name': nameController.text.trim(),
                    'abbreviation': abbreviationController.text.trim(),
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ تم تحديث الوحدة بنجاح')),
                  );

                  Navigator.pop(context);
                  // إعادة تحميل قائمة الوحدات
                  _showUnitsDialog();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ خطأ في تحديث الوحدة: ${e.toString()}')),
                  );
                }
              }
            },
            child: Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showDeleteUnitConfirmation(Map<String, dynamic> unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف وحدة "${unit['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbHelper.deleteUnit(unit['id']);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('✅ تم حذف الوحدة بنجاح')),
                );

                Navigator.pop(context);
                // إعادة تحميل قائمة الوحدات
                _showUnitsDialog();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ خطأ في حذف الوحدة: ${e.toString()}')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showBarcodeSettings() async {
    try {
      final settings = await _dbHelper.getBarcodeSettings();

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('إعدادات الباركود'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // نوع الباركود
                      DropdownButtonFormField<String>(
                        value: settings['barcode_type'] ?? 'CODE128',
                        decoration: InputDecoration(
                          labelText: 'نوع الباركود',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(value: 'CODE128', child: Text('CODE128')),
                          DropdownMenuItem(value: 'CODE39', child: Text('CODE39')),
                          DropdownMenuItem(value: 'EAN13', child: Text('EAN13')),
                          DropdownMenuItem(value: 'EAN8', child: Text('EAN8')),
                          DropdownMenuItem(value: 'UPC-A', child: Text('UPC-A')),
                          DropdownMenuItem(value: 'QR', child: Text('QR كود')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            settings['barcode_type'] = value;
                          });
                        },
                      ),
                      SizedBox(height: 15),

                      // أبعاد الباركود
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: (settings['width'] ?? 2).toString(),
                              decoration: InputDecoration(
                                labelText: 'العرض',
                                border: OutlineInputBorder(),
                                suffixText: 'مم',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['width'] = int.tryParse(value) ?? 2;
                              },
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: (settings['height'] ?? 100).toString(),
                              decoration: InputDecoration(
                                labelText: 'الطول',
                                border: OutlineInputBorder(),
                                suffixText: 'مم',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                settings['height'] = int.tryParse(value) ?? 100;
                              },
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 15),

                      // خيارات إضافية
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text('إظهار السعر'),
                                subtitle: Text('عرض سعر المنتج أسفل الباركود'),
                                value: (settings['include_price'] ?? 0) == 1,
                                onChanged: (value) {
                                  setState(() {
                                    settings['include_price'] = value ? 1 : 0;
                                  });
                                },
                              ),
                              Divider(),
                              SwitchListTile(
                                title: Text('إظهار الاسم'),
                                subtitle: Text('عرض اسم المنتج أسفل الباركود'),
                                value: (settings['include_name'] ?? 1) == 1,
                                onChanged: (value) {
                                  setState(() {
                                    settings['include_name'] = value ? 1 : 0;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _dbHelper.updateBarcodeSettings(settings);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ تم حفظ إعدادات الباركود')),
                      );

                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ خطأ في الحفظ: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text('حفظ الإعدادات'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل إعدادات الباركود: ${e.toString()}')),
      );
    }
  }

  void _showLanguageDialog() {
    final List<String> languages = ['العربية', 'English', 'Français', 'Español'];
    String selectedLang = _advancedSettings['app_language'] ?? 'العربية';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر لغة التطبيق'),
            content: Container(
              width: double.maxFinite,
              height: 250,
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final lang = languages[index];
                  return RadioListTile<String>(
                    title: Text(lang),
                    value: lang,
                    groupValue: selectedLang,
                    onChanged: (value) {
                      setState(() {
                        selectedLang = value!;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateAdvancedSetting('app_language', selectedLang);
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThemeDialog() {
    final List<String> themes = ['فاتح', 'داكن', 'تلقائي بالنظام'];
    String selectedTheme = _advancedSettings['app_theme'] ?? 'فاتح';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر مظهر الواجهة'),
            content: Container(
              width: double.maxFinite,
              height: 200,
              child: ListView.builder(
                itemCount: themes.length,
                itemBuilder: (context, index) {
                  final theme = themes[index];
                  return RadioListTile<String>(
                    title: Text(theme),
                    value: theme,
                    groupValue: selectedTheme,
                    onChanged: (value) {
                      setState(() {
                        selectedTheme = value!;
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  _updateAdvancedSetting('app_theme', selectedTheme);
                  Navigator.pop(context);
                },
                child: Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  // دوال النسخ الاحتياطي
  Future<void> _createBackupNow() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري إنشاء نسخة احتياطية...')),
      );

      final backupPath = await _dbHelper.createBackup();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('✅ تم إنشاء النسخة الاحتياطية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم حفظ النسخة الاحتياطية بنجاح في:'),
              SizedBox(height: 10),
              SelectableText(
                backupPath,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 20),
              Text('تاريخ النسخ: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.share),
              label: Text('مشاركة'),
              onPressed: () async {
                final file = File(backupPath);
                if (await file.exists()) {
                  await Share.shareXFiles([XFile(backupPath)], text: 'نسخة احتياطية من قاعدة البيانات');
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في إنشاء النسخة الاحتياطية: ${e.toString()}')),
      );
    }
  }

  Future<void> _restoreBackup() async {
    // في تطبيق حقيقي، يمكن استخدام file_picker لاختيار ملف
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('استعادة نسخة احتياطية'),
        content: Text('هذه الميزة تتطلب إضافة حزمة file_picker. سيتم تنفيذها في نسخة لاحقة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDatabaseToJson() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري تصدير البيانات...')),
      );

      final exportPath = await _dbHelper.exportDatabaseToJson();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('✅ تم تصدير البيانات بنجاح'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تم حفظ ملف التصدير في:'),
              SizedBox(height: 10),
              SelectableText(
                exportPath,
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 20),
              Text('يمكنك مشاركة هذا الملف أو حفظه كنسخة احتياطية.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
            ElevatedButton.icon(
              icon: Icon(Icons.share),
              label: Text('مشاركة'),
              onPressed: () async {
                final file = File(exportPath);
                if (await file.exists()) {
                  await Share.shareXFiles([XFile(exportPath)], text: 'تصدير بيانات قاعدة البيانات');
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تصدير البيانات: ${e.toString()}')),
      );
    }
  }

  // دوال الصيانة
  Future<void> _compressDatabase() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري ضغط قاعدة البيانات...')),
      );

      await _dbHelper.compressDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم ضغط قاعدة البيانات بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في ضغط قاعدة البيانات: ${e.toString()}')),
      );
    }
  }

  Future<void> _rebuildIndexes() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري إعادة بناء فهارس قاعدة البيانات...')),
      );

      await _dbHelper.rebuildDatabaseIndexes();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم إعادة بناء الفهارس بنجاح')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في إعادة بناء الفهارس: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkDatabaseIntegrity() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري فحص سلامة قاعدة البيانات...')),
      );

      final result = await _dbHelper.checkDatabaseIntegrity();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result['success'] ? '✅ فحص السلامة' : '❌ خطأ في الفحص'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('نتيجة الفحص:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text(result['message']),

                  if (result['success'] && result['data_integrity'] is List)
                    ...[
                      SizedBox(height: 20),
                      Text('المشاكل المكتشفة:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(result['data_integrity'] as List).map((issue) {
                        return ListTile(
                          title: Text(issue['table_name']),
                          subtitle: Text('سجلات يتيمة: ${issue['orphaned_records']}'),
                        );
                      }).toList(),
                    ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في فحص سلامة قاعدة البيانات: ${e.toString()}')),
      );
    }
  }

  Future<void> _showDatabaseStats() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري جمع إحصائيات قاعدة البيانات...')),
      );

      final stats = await _dbHelper.getDatabaseStats();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('إحصائيات قاعدة البيانات'),
          content: Container(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stats['success'])
                    ...[
                      _buildStatCard('إجمالي السجلات', '${stats['total_records']} سجل'),
                      _buildStatCard('إجمالي الجداول', '${stats['total_tables']} جدول'),
                      _buildStatCard('حجم قاعدة البيانات', '${(stats['database_size']! / 1024 / 1024).toStringAsFixed(2)} ميجابايت'),

                      SizedBox(height: 20),
                      Text('تفاصيل الجداول:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...(stats['table_stats'] as List).map((table) {
                        return ListTile(
                          title: Text(table['table_name']),
                          trailing: Text('${table['row_count']} سجل'),
                        );
                      }).toList(),
                    ]
                  else
                    Text('❌ ${stats['error']}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('حسناً'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في جلب الإحصائيات: ${e.toString()}')),
      );
    }
  }

  Widget _buildStatCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  // دوال الخيارات الخطيرة
  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('مسح جميع البيانات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل أنت متأكد من مسح جميع البيانات؟'),
            SizedBox(height: 10),
            Text(
              'هذا الإجراء سيمحو:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text('• جميع الفواتير والمبيعات'),
            Text('• جميع المشتريات'),
            Text('• جميع الحركات والتحويلات'),
            Text('• جميع سندات القبض والصرف'),
            SizedBox(height: 10),
            Text(
              '⚠️ هذا الإجراء لا يمكن التراجع عنه!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('أدخل "نعم" للتأكيد:'),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'اكتب "نعم" هنا',
              ),
              onChanged: (value) {
                setState(() {
                  _deleteConfirmed = value.toLowerCase() == 'نعم';
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _deleteConfirmed = false;
              Navigator.pop(context);
            },
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _deleteConfirmed ? _clearAllData : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('مسح البيانات'),
          ),
        ],
      ),
    );
  }

  void _showResetDatabaseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red),
            SizedBox(width: 10),
            Text('إعادة تعيين قاعدة البيانات'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('هل أنت متأكد من إعادة تعيين قاعدة البيانات؟'),
            SizedBox(height: 10),
            Text(
              'هذا الإجراء سيقوم بـ:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 5),
            Text('• حذف قاعدة البيانات الحالية'),
            Text('• إنشاء نسخة احتياطية تلقائياً'),
            Text('• إنشاء قاعدة بيانات جديدة فارغة'),
            SizedBox(height: 10),
            Text(
              '⚠️ هذا الإجراء لا يمكن التراجع عنه!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('أدخل "تأكيد" للتأكيد:'),
            SizedBox(height: 10),
            TextField(
              controller: _confirmDeleteController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'اكتب "تأكيد" هنا',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _confirmDeleteController.clear();
              Navigator.pop(context);
            },
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_confirmDeleteController.text.trim() == 'تأكيد') {
                _resetDatabase();
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('إعادة التعيين'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDatabaseConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red[900]),
            SizedBox(width: 10),
            Text('حذف قاعدة البيانات بالكامل'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⚠️ تحذير شديد الخطورة! ⚠️'),
            SizedBox(height: 10),
            Text('هذا الإجراء سيمحو قاعدة البيانات بالكامل مع جميع البيانات.'),
            SizedBox(height: 10),
            Text('لا يمكن استعادة البيانات بعد هذا الإجراء!'),
            SizedBox(height: 20),
            Text(
              'للتأكيد، أدخل الجملة التالية:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              '"أنا أتفهم أن جميع البيانات ستُحذف ولا يمكن استعادتها"',
              style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            TextField(
              controller: _confirmDeleteController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'انسخ الجملة أعلاه هنا',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _confirmDeleteController.clear();
              Navigator.pop(context);
            },
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final confirmationText = 'أنا أتفهم أن جميع البيانات ستُحذف ولا يمكن استعادتها';
              if (_confirmDeleteController.text.trim() == confirmationText) {
                _deleteDatabase();
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ يجب كتابة الجملة بالضبط كما هي')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[900],
              foregroundColor: Colors.white,
            ),
            child: Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري مسح جميع البيانات...')),
      );

      final result = await _dbHelper.clearAllData();

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم مسح جميع البيانات بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${result['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في مسح البيانات: ${e.toString()}')),
      );
    }
  }

  Future<void> _resetDatabase() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري إعادة تعيين قاعدة البيانات...')),
      );

      final result = await _dbHelper.resetDatabase();

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${result['message']}')),
        );

        // إعادة تحميل الإعدادات
        await _loadAllSettings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${result['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في إعادة التعيين: ${e.toString()}')),
      );
    }
  }

  Future<void> _deleteDatabase() async {
    try {
      // حذف قاعدة البيانات
      await _dbHelper.resetDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم حذف قاعدة البيانات وإعادة إنشائها')),
      );

      // إعادة تحميل الإعدادات
      await _loadAllSettings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في حذف قاعدة البيانات: ${e.toString()}')),
      );
    }
  }

  // دوال للإعدادات الأخرى (للتوافق مع الكود القديم)
  // استبدل هذه الدوال:

  void _showInvoiceNumberingDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceNumberingScreen(),
      ),
    );
  }

  void _showPaymentTermsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentTermsScreen(),
      ),
    );
  }

  void _showReturnPoliciesDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnPoliciesScreen(),
      ),
    );
  }


  void _showSupplierPaymentTermsDialog() {
    _showComingSoonDialog('شروط الدفع للموردين');
  }

  void _showSupplierEvaluationSettings() {
    _showComingSoonDialog('تقييم الموردين');
  }

  void _showScheduledReportsDialog() {
    _showComingSoonDialog('التقارير المجدولة');
  }

  void _showExportFormatsDialog() {
    _showComingSoonDialog('صيغ التصدير');
  }

  void _showUsersManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => UsersManagementScreen()),
    );
  }
  // استبدل هذه الدالة:
  void _showPasswordPolicyDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PasswordPolicyScreen()),
    );
  }
  void _showDateTimeFormatDialog() {
    _showComingSoonDialog('تنسيق التاريخ والوقت');
  }

  void _showNumberFormatDialog() {
    _showComingSoonDialog('تنسيق الأرقام والعملة');
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('هذه الميزة قيد التطوير وسيتم إضافتها في نسخة قادمة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حسناً'),
          ),
        ],
      ),
    );
  }
}

// فئة إدارة صلاحيات المستخدمين (كما هي)
class UserPermissionsScreen extends StatefulWidget {
  final int userId;
  final String userName;

  UserPermissionsScreen({required this.userId, required this.userName});

  @override
  _UserPermissionsScreenState createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, bool> _permissions = {};
  bool _isLoading = true;

  // قائمة الصلاحيات المتاحة
  final List<Map<String, String>> _availablePermissions = [
    {'key': 'view_dashboard', 'name': 'عرض لوحة التحكم'},
    {'key': 'manage_products', 'name': 'إدارة المنتجات'},
    {'key': 'manage_customers', 'name': 'إدارة العملاء'},
    {'key': 'manage_suppliers', 'name': 'إدارة الموردين'},
    {'key': 'manage_sales', 'name': 'إدارة المبيعات'},
    {'key': 'manage_purchases', 'name': 'إدارة المشتريات'},
    {'key': 'manage_inventory', 'name': 'إدارة المخزون'},
    {'key': 'manage_reports', 'name': 'إدارة التقارير'},
    {'key': 'manage_users', 'name': 'إدارة المستخدمين'},
    {'key': 'manage_settings', 'name': 'إدارة الإعدادات'},
  ];

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);

    try {
      final userPermissions = await _dbHelper.getUserPermissions(widget.userId);

      // تهيئة جميع الصلاحيات بقيمة false
      Map<String, bool> permissions = {};
      for (final permission in _availablePermissions) {
        permissions[permission['key']!] = false;
      }

      // تحديث الصلاحيات الموجودة
      for (final userPermission in userPermissions) {
        final key = userPermission['permission_key'] as String;
        final granted = userPermission['granted'] as int == 1;
        permissions[key] = granted;
      }

      setState(() {
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل الصلاحيات: ${e.toString()}')),
      );
    }
  }

  Future<void> _savePermissions() async {
    try {
      for (final permission in _availablePermissions) {
        final key = permission['key']!;
        final granted = _permissions[key] ?? false;

        await _dbHelper.updateUserPermission(widget.userId, key, granted);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم حفظ الصلاحيات بنجاح')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في حفظ الصلاحيات: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('صلاحيات المستخدم: ${widget.userName}'),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _availablePermissions.length,
              itemBuilder: (context, index) {
                final permission = _availablePermissions[index];
                final key = permission['key']!;
                final name = permission['name']!;
                final value = _permissions[key] ?? false;

                return SwitchListTile(
                  title: Text(name),
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      _permissions[key] = newValue;
                    });
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _savePermissions,
              child: Text('حفظ الصلاحيات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}