import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'app_colors.dart';

class InvoiceNumberingScreen extends StatefulWidget {
  @override
  _InvoiceNumberingScreenState createState() => _InvoiceNumberingScreenState();
}

class _InvoiceNumberingScreenState extends State<InvoiceNumberingScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _settings = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // أنواع الفواتير
  final List<Map<String, dynamic>> _invoiceTypes = [
    {'type': 'sale', 'name': 'فواتير البيع', 'icon': Icons.receipt},
    {'type': 'purchase', 'name': 'فواتير الشراء', 'icon': Icons.shopping_cart},
    {'type': 'sale_return', 'name': 'مرتجعات البيع', 'icon': Icons.assignment_return},
    {'type': 'purchase_return', 'name': 'مرتجعات الشراء', 'icon': Icons.assignment_returned},
    {'type': 'stock_transfer', 'name': 'تحويلات المخزون', 'icon': Icons.move_to_inbox},
    {'type': 'inventory_adjustment', 'name': 'تعديلات الجرد', 'icon': Icons.inventory},
  ];

  @override
  void initState() {
    super.initState();
    _loadInvoiceNumberingSettings();
  }

  Future<void> _loadInvoiceNumberingSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _dbHelper.getAllInvoiceNumberingSettings();

      // إذا لم تكن هناك إعدادات، نقوم بإنشاء إعدادات افتراضية
      if (settings.isEmpty) {
        for (var type in _invoiceTypes) {
          await _dbHelper.updateInvoiceNumberingSettings(type['type'], {
            'prefix': _getDefaultPrefix(type['type']),
            'suffix': '',
            'current_number': 1,
            'number_length': 5,
            'reset_frequency': 'never',
            'is_active': 1,
          });
        }
        // إعادة التحميل
        await _loadInvoiceNumberingSettings();
        return;
      }

      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تحميل إعدادات الترقيم: ${e.toString()}')),
      );
    }
  }

  String _getDefaultPrefix(String type) {
    switch (type) {
      case 'sale': return 'SALE-';
      case 'purchase': return 'PUR-';
      case 'sale_return': return 'SR-';
      case 'purchase_return': return 'PR-';
      case 'stock_transfer': return 'ST-';
      case 'inventory_adjustment': return 'IA-';
      default: return 'INV-';
    }
  }

  String _getTypeName(String type) {
    for (var item in _invoiceTypes) {
      if (item['type'] == type) return item['name'];
    }
    return type;
  }

  IconData _getTypeIcon(String type) {
    for (var item in _invoiceTypes) {
      if (item['type'] == type) return item['icon'];
    }
    return Icons.receipt;
  }

  String _getFrequencyName(String frequency) {
    switch (frequency) {
      case 'daily': return 'يومي';
      case 'weekly': return 'أسبوعي';
      case 'monthly': return 'شهري';
      case 'yearly': return 'سنوي';
      case 'never': return 'أبداً';
      default: return frequency;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ترقيم الفواتير'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadInvoiceNumberingSettings,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // شريط البحث
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث في أنواع الفواتير...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                // يمكن إضافة منطق البحث هنا
              },
            ),
          ),

          // قائمة إعدادات الترقيم
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _invoiceTypes.length,
              itemBuilder: (context, index) {
                final type = _invoiceTypes[index];
                final setting = _settings.firstWhere(
                      (s) => s['invoice_type'] == type['type'],
                  orElse: () => {},
                );

                return _buildInvoiceTypeCard(type, setting);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTypeCard(Map<String, dynamic> type, Map<String, dynamic> setting) {
    final typeName = type['name'];
    final typeIcon = type['icon'];
    final invoiceType = type['type'];

    final prefix = setting['prefix'] ?? _getDefaultPrefix(invoiceType);
    final suffix = setting['suffix'] ?? '';
    final currentNumber = setting['current_number'] ?? 1;
    final numberLength = setting['number_length'] ?? 5;
    final resetFrequency = setting['reset_frequency'] ?? 'never';

    // مثال على الرقم التالي
    final nextNumber = currentNumber;
    final formattedNumber = nextNumber.toString().padLeft(numberLength, '0');
    final exampleNumber = '$prefix$formattedNumber$suffix';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () => _showEditDialog(invoiceType, setting),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(typeIcon, color: AppColors.primary, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      typeName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
              SizedBox(height: 16),

              // معلومات الترقيم
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'البادئة:',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          prefix.isNotEmpty ? prefix : 'لا يوجد',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اللاحقة:',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          suffix.isNotEmpty ? suffix : 'لا يوجد',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الرقم الحالي:',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          currentNumber.toString(),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'طول الرقم:',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          numberLength.toString(),
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إعادة التعيين:',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          _getFrequencyName(resetFrequency),
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // مثال على الرقم
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'مثال على الرقم التالي: $exampleNumber',
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String invoiceType, Map<String, dynamic> setting) {
    final TextEditingController prefixController = TextEditingController(
      text: setting['prefix'] ?? _getDefaultPrefix(invoiceType),
    );
    final TextEditingController suffixController = TextEditingController(
      text: setting['suffix'] ?? '',
    );
    final TextEditingController currentNumberController = TextEditingController(
      text: (setting['current_number'] ?? 1).toString(),
    );
    final TextEditingController numberLengthController = TextEditingController(
      text: (setting['number_length'] ?? 5).toString(),
    );

    String selectedFrequency = setting['reset_frequency'] ?? 'never';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(_getTypeIcon(invoiceType), color: AppColors.primary),
                SizedBox(width: 10),
                Text('إعدادات ترقيم ${_getTypeName(invoiceType)}'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: prefixController,
                    decoration: InputDecoration(
                      labelText: 'البادئة',
                      border: OutlineInputBorder(),
                      hintText: 'مثال: INV-',
                      helperText: 'يتم إضافتها في بداية الرقم',
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: suffixController,
                    decoration: InputDecoration(
                      labelText: 'اللاحقة',
                      border: OutlineInputBorder(),
                      hintText: 'مثال: -2024',
                      helperText: 'يتم إضافتها في نهاية الرقم',
                    ),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: currentNumberController,
                    decoration: InputDecoration(
                      labelText: 'الرقم الحالي',
                      border: OutlineInputBorder(),
                      helperText: 'الرقم الذي سيبدأ منه الترقيم',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: numberLengthController,
                    decoration: InputDecoration(
                      labelText: 'طول الرقم',
                      border: OutlineInputBorder(),
                      hintText: 'مثال: 5 → 00001',
                      helperText: 'عدد الأرقام (يتم تعبئتها بالأصفار)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedFrequency,
                    decoration: InputDecoration(
                      labelText: 'تكرار إعادة التعيين',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'never', child: Text('أبداً')),
                      DropdownMenuItem(value: 'daily', child: Text('يومي')),
                      DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                      DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                      DropdownMenuItem(value: 'yearly', child: Text('سنوي')),
                    ],
                    onChanged: (value) => setState(() => selectedFrequency = value!),
                  ),
                  SizedBox(height: 16),

                  // معاينة الرقم
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'معاينة الرقم:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _generatePreview(
                            prefixController.text,
                            suffixController.text,
                            currentNumberController.text,
                            numberLengthController.text,
                          ),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final currentNumber = int.tryParse(currentNumberController.text) ?? 1;
                  final numberLength = int.tryParse(numberLengthController.text) ?? 5;

                  if (currentNumber < 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('الرقم الحالي يجب أن يكون أكبر من صفر')),
                    );
                    return;
                  }

                  if (numberLength < 1 || numberLength > 10) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('طول الرقم يجب أن يكون بين 1 و 10')),
                    );
                    return;
                  }

                  try {
                    final result = await _dbHelper.updateInvoiceNumberingSettings(invoiceType, {
                      'prefix': prefixController.text,
                      'suffix': suffixController.text,
                      'current_number': currentNumber,
                      'number_length': numberLength,
                      'reset_frequency': selectedFrequency,
                      'is_active': 1,
                    });

                    if (result['success']) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('✅ تم تحديث الإعدادات بنجاح')),
                      );
                      Navigator.pop(context);
                      _loadInvoiceNumberingSettings();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ ${result['error']}')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ خطأ في الحفظ: ${e.toString()}')),
                    );
                  }
                },
                child: Text('حفظ التغييرات'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _generatePreview(String prefix, String suffix, String currentNumber, String numberLength) {
    try {
      final number = int.tryParse(currentNumber) ?? 1;
      final length = int.tryParse(numberLength) ?? 5;
      final formattedNumber = number.toString().padLeft(length, '0');
      return '$prefix$formattedNumber$suffix';
    } catch (e) {
      return '$prefix$currentNumber$suffix';
    }
  }
}