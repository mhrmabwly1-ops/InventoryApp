import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'app_colors.dart';

class PaymentTermsScreen extends StatefulWidget {
  @override
  _PaymentTermsScreenState createState() => _PaymentTermsScreenState();
}

class _PaymentTermsScreenState extends State<PaymentTermsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _paymentTerms = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPaymentTerms();
  }

  Future<void> _loadPaymentTerms() async {
    setState(() => _isLoading = true);
    try {
      final terms = await _dbHelper.getAllPaymentTerms();
      setState(() {
        _paymentTerms = terms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تحميل شروط الدفع: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('شروط الدفع'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'إضافة شرط دفع جديد',
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
                labelText: 'بحث في شروط الدفع...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _filterPaymentTerms(value);
              },
            ),
          ),

          // قائمة شروط الدفع
          Expanded(
            child: _paymentTerms.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'لا توجد شروط دفع',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'انقر على زر + لإضافة شرط دفع جديد',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _paymentTerms.length,
              itemBuilder: (context, index) {
                return _buildPaymentTermCard(_paymentTerms[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTermCard(Map<String, dynamic> term) {
    final dueDays = term['due_days'] ?? 0;
    final discountPercent = term['discount_percent'] ?? 0.0;
    final discountDays = term['discount_days'] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(Icons.payment, color: AppColors.primary),
        ),
        title: Text(
          term['name'],
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (term['description'] != null && term['description'].toString().isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  term['description'],
                  style: TextStyle(color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text('الأيام: $dueDays'),
                  backgroundColor: Colors.blue[50],
                  labelStyle: TextStyle(fontSize: 12),
                ),
                if (discountPercent > 0)
                  Chip(
                    label: Text('خصم: $discountPercent%'),
                    backgroundColor: Colors.green[50],
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                if (discountDays > 0)
                  Chip(
                    label: Text('أيام الخصم: $discountDays'),
                    backgroundColor: Colors.orange[50],
                    labelStyle: TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.blue, size: 20),
              onPressed: () => _showEditDialog(term),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _showDeleteDialog(term),
            ),
          ],
        ),
      ),
    );
  }

  void _filterPaymentTerms(String query) {
    // يمكن تنفيذ منطق البحث هنا
  }

  void _showAddDialog() {
    _showTermDialog(null);
  }

  void _showEditDialog(Map<String, dynamic> term) {
    _showTermDialog(term);
  }

  void _showTermDialog(Map<String, dynamic>? term) {
    final isEdit = term != null;

    final TextEditingController nameController = TextEditingController(
      text: term?['name'] ?? '',
    );
    final TextEditingController descController = TextEditingController(
      text: term?['description'] ?? '',
    );
    final TextEditingController dueDaysController = TextEditingController(
      text: (term?['due_days'] ?? 0).toString(),
    );
    final TextEditingController discountPercentController = TextEditingController(
      text: (term?['discount_percent'] ?? 0.0).toString(),
    );
    final TextEditingController discountDaysController = TextEditingController(
      text: (term?['discount_days'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.payment, color: AppColors.primary),
            SizedBox(width: 10),
            Text(isEdit ? 'تعديل شرط الدفع' : 'إضافة شرط دفع جديد'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم شرط الدفع',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: صافي 30 يوم',
                  helperText: 'الاسم الذي سيظهر في القائمة',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  border: OutlineInputBorder(),
                  hintText: 'وصف مختصر لشرط الدفع',
                ),
                maxLines: 3,
              ),
              SizedBox(height: 12),
              TextField(
                controller: dueDaysController,
                decoration: InputDecoration(
                  labelText: 'عدد أيام الاستحقاق',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: 30',
                  helperText: 'عدد الأيام المسموح بها للدفع',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: discountPercentController,
                      decoration: InputDecoration(
                        labelText: 'نسبة الخصم %',
                        border: OutlineInputBorder(),
                        hintText: 'مثال: 5.0',
                        helperText: 'نسبة الخصم للدفع المبكر',
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: discountDaysController,
                      decoration: InputDecoration(
                        labelText: 'أيام الخصم',
                        border: OutlineInputBorder(),
                        hintText: 'مثال: 10',
                        helperText: 'عدد الأيام للحصول على الخصم',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // ملخص الشرط
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
                      'ملخص شرط الدفع:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _generateSummary(
                        nameController.text,
                        dueDaysController.text,
                        discountPercentController.text,
                        discountDaysController.text,
                      ),
                      style: TextStyle(color: Colors.grey[700]),
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
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('اسم شرط الدفع مطلوب')),
                );
                return;
              }

              final dueDays = int.tryParse(dueDaysController.text) ?? 0;
              final discountPercent = double.tryParse(discountPercentController.text) ?? 0.0;
              final discountDays = int.tryParse(discountDaysController.text) ?? 0;

              if (dueDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('عدد أيام الاستحقاق يجب أن يكون صفر أو أكبر')),
                );
                return;
              }

              if (discountPercent < 0 || discountPercent > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('نسبة الخصم يجب أن تكون بين 0 و 100')),
                );
                return;
              }

              if (discountDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('أيام الخصم يجب أن تكون صفر أو أكبر')),
                );
                return;
              }

              final termData = {
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
                'due_days': dueDays,
                'discount_percent': discountPercent,
                'discount_days': discountDays,
              };

              try {
                Map<String, dynamic> result;

                if (isEdit) {
                  result = await _dbHelper.updatePaymentTerm(term!['id'], termData);
                } else {
                  result = await _dbHelper.createPaymentTerm(termData);
                }

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${result['message']}')),
                  );
                  Navigator.pop(context);
                  _loadPaymentTerms();
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
            child: Text(isEdit ? 'تحديث' : 'إضافة'),
          ),
        ],
      ),
    );
  }

  String _generateSummary(String name, String dueDays, String discountPercent, String discountDays) {
    final days = int.tryParse(dueDays) ?? 0;
    final discount = double.tryParse(discountPercent) ?? 0.0;
    final discountDaysCount = int.tryParse(discountDays) ?? 0;

    String summary = 'الدفع خلال $days يوم';

    if (discount > 0 && discountDaysCount > 0) {
      summary += '، خصم $discount% للدفع خلال $discountDaysCount يوم';
    } else if (discount > 0) {
      summary += '، خصم $discount% للدفع الفوري';
    }

    return summary;
  }

  void _showDeleteDialog(Map<String, dynamic> term) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 10),
            Text('تأكيد الحذف'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف شرط الدفع "${term['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final result = await _dbHelper.deletePaymentTerm(term['id']);

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${result['message']}')),
                  );
                  Navigator.pop(context);
                  _loadPaymentTerms();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${result['error']}')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ خطأ في الحذف: ${e.toString()}')),
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
}