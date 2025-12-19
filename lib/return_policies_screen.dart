import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'app_colors.dart';

class ReturnPoliciesScreen extends StatefulWidget {
  @override
  _ReturnPoliciesScreenState createState() => _ReturnPoliciesScreenState();
}

class _ReturnPoliciesScreenState extends State<ReturnPoliciesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _policies = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReturnPolicies();
  }

  Future<void> _loadReturnPolicies() async {
    setState(() => _isLoading = true);
    try {
      final policies = await _dbHelper.getAllReturnPolicies();
      setState(() {
        _policies = policies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ خطأ في تحميل سياسات الإرجاع: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('سياسات الإرجاع'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _showAddDialog,
            tooltip: 'إضافة سياسة إرجاع جديدة',
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
                labelText: 'بحث في سياسات الإرجاع...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                _filterPolicies(value);
              },
            ),
          ),

          // قائمة سياسات الإرجاع
          Expanded(
            child: _policies.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_return, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    'لا توجد سياسات إرجاع',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'انقر على زر + لإضافة سياسة إرجاع جديدة',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _policies.length,
              itemBuilder: (context, index) {
                return _buildPolicyCard(_policies[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(Map<String, dynamic> policy) {
    final returnDays = policy['return_days'] ?? 0;
    final restockingFee = policy['restocking_fee'] ?? 0.0;
    final conditions = policy['conditions'] ?? '';

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
          child: Icon(Icons.assignment_return, color: AppColors.primary),
        ),
        title: Text(
          policy['name'],
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conditions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  conditions.length > 100
                      ? '${conditions.substring(0, 100)}...'
                      : conditions,
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
                  label: Text('أيام الإرجاع: $returnDays'),
                  backgroundColor: Colors.blue[50],
                  labelStyle: TextStyle(fontSize: 12),
                ),
                if (restockingFee > 0)
                  Chip(
                    label: Text('رسوم إعادة: $restockingFee%'),
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
              onPressed: () => _showEditDialog(policy),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () => _showDeleteDialog(policy),
            ),
          ],
        ),
      ),
    );
  }

  void _filterPolicies(String query) {
    // يمكن تنفيذ منطق البحث هنا
  }

  void _showAddDialog() {
    _showPolicyDialog(null);
  }

  void _showEditDialog(Map<String, dynamic> policy) {
    _showPolicyDialog(policy);
  }

  void _showPolicyDialog(Map<String, dynamic>? policy) {
    final isEdit = policy != null;

    final TextEditingController nameController = TextEditingController(
      text: policy?['name'] ?? '',
    );
    final TextEditingController returnDaysController = TextEditingController(
      text: (policy?['return_days'] ?? 0).toString(),
    );
    final TextEditingController restockingFeeController = TextEditingController(
      text: (policy?['restocking_fee'] ?? 0.0).toString(),
    );
    final TextEditingController conditionsController = TextEditingController(
      text: policy?['conditions'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.assignment_return, color: AppColors.primary),
            SizedBox(width: 10),
            Text(isEdit ? 'تعديل سياسة الإرجاع' : 'إضافة سياسة إرجاع جديدة'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم السياسة',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: سياسة الإرجاع القياسية',
                  helperText: 'الاسم الذي سيظهر في القائمة',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: returnDaysController,
                decoration: InputDecoration(
                  labelText: 'عدد أيام الإرجاع',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: 30',
                  helperText: 'عدد الأيام المسموح بها للإرجاع',
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 12),
              TextField(
                controller: restockingFeeController,
                decoration: InputDecoration(
                  labelText: 'رسوم إعادة التخزين %',
                  border: OutlineInputBorder(),
                  hintText: 'مثال: 10.0',
                  helperText: 'نسبة الرسوم للإرجاع (0 = لا توجد رسوم)',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              SizedBox(height: 12),
              TextField(
                controller: conditionsController,
                decoration: InputDecoration(
                  labelText: 'الشروط والأحكام',
                  border: OutlineInputBorder(),
                  hintText: 'الشروط الخاصة بالإرجاع...',
                  helperText: 'الشروط التي يجب توافرها للإرجاع',
                ),
                maxLines: 5,
              ),
              SizedBox(height: 16),

              // ملخص السياسة
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
                      'ملخص السياسة:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _generatePolicySummary(
                        nameController.text,
                        returnDaysController.text,
                        restockingFeeController.text,
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
                  SnackBar(content: Text('اسم السياسة مطلوب')),
                );
                return;
              }

              final returnDays = int.tryParse(returnDaysController.text) ?? 0;
              final restockingFee = double.tryParse(restockingFeeController.text) ?? 0.0;

              if (returnDays < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('أيام الإرجاع يجب أن تكون صفر أو أكبر')),
                );
                return;
              }

              if (restockingFee < 0 || restockingFee > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('رسوم إعادة التخزين يجب أن تكون بين 0 و 100')),
                );
                return;
              }

              final policyData = {
                'name': nameController.text.trim(),
                'return_days': returnDays,
                'restocking_fee': restockingFee,
                'conditions': conditionsController.text.trim(),
              };

              try {
                Map<String, dynamic> result;

                if (isEdit) {
                  result = await _dbHelper.updateReturnPolicy(policy!['id'], policyData);
                } else {
                  result = await _dbHelper.createReturnPolicy(policyData);
                }

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${result['message']}')),
                  );
                  Navigator.pop(context);
                  _loadReturnPolicies();
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

  String _generatePolicySummary(String name, String returnDays, String restockingFee) {
    final days = int.tryParse(returnDays) ?? 0;
    final fee = double.tryParse(restockingFee) ?? 0.0;

    String summary = 'الإرجاع مسموح خلال $days يوم من الشراء';

    if (fee > 0) {
      summary += '، مع رسوم إعادة تخزين $fee%';
    } else {
      summary += '، بدون رسوم إعادة تخزين';
    }

    return summary;
  }

  void _showDeleteDialog(Map<String, dynamic> policy) {
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
        content: Text('هل أنت متأكد من حذف سياسة الإرجاع "${policy['name']}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final result = await _dbHelper.deleteReturnPolicy(policy['id']);

                if (result['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${result['message']}')),
                  );
                  Navigator.pop(context);
                  _loadReturnPolicies();
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