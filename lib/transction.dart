import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'package:intl/intl.dart';
import 'settings_reactive.dart';
import 'settings_store.dart';

class TransactionsScreen extends StatefulWidget {
  @override
  _TransactionsScreenState createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with SettingsReactive<TransactionsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  bool _isLoading = true;
  String _selectedType = 'all'; // 'sale', 'purchase', 'all'
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    startSettingsListener();
  }

  @override
  void dispose() {
    stopSettingsListener();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    try {
      // جلب المبيعات
      final sales = await _dbHelper.getSaleInvoices();
      // جلب المشتريات
      final purchases = await _dbHelper.getPurchaseInvoices();

      List<Map<String, dynamic>> allTransactions = [];

      // تحويل المبيعات إلى معاملات
      for (var sale in sales) {
        allTransactions.add({
          'id': sale['id'],
          'type': 'sale',
          'invoice_number': sale['invoice_number'],
          'customer_name': sale['customer_name'],
          'total_amount': sale['total_amount'],
          'date': sale['invoice_date'],
          'status': sale['status'],
          'icon': Icons.shopping_cart,
          'color': Colors.green,
        });
      }

      // تحويل المشتريات إلى معاملات
      for (var purchase in purchases) {
        allTransactions.add({
          'id': purchase['id'],
          'type': 'purchase',
          'invoice_number': purchase['invoice_number'],
          'supplier_name': purchase['supplier_name'],
          'total_amount': purchase['total_amount'],
          'date': purchase['invoice_date'],
          'status': purchase['status'],
          'icon': Icons.shopping_bag,
          'color': Colors.blue,
        });
      }

      // ترتيب حسب التاريخ
      allTransactions.sort((a, b) {
        final dateA = DateTime.parse(a['date'] ?? '');
        final dateB = DateTime.parse(b['date'] ?? '');
        return dateB.compareTo(dateA);
      });

      setState(() {
        _transactions = allTransactions;
        _filteredTransactions = allTransactions;
        _isLoading = false;
      });
    } catch (e) {
      print('خطأ في تحميل المعاملات: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterTransactions() {
    List<Map<String, dynamic>> filtered = _transactions;

    // تصفية حسب النوع
    if (_selectedType != 'all') {
      filtered = filtered.where((t) => t['type'] == _selectedType).toList();
    }

    // تصفية حسب التاريخ
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((transaction) {
        try {
          final transactionDate = DateTime.parse(transaction['date'] ?? '');
          return transactionDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              transactionDate.isBefore(_endDate!.add(Duration(days: 1)));
        } catch (e) {
          return false;
        }
      }).toList();
    }

    setState(() {
      _filteredTransactions = filtered;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      currentDate: DateTime.now(),
      saveText: 'تطبيق',
      helpText: 'اختر فترة',
      cancelText: 'إلغاء',
      confirmText: 'موافق',
      errorFormatText: 'تنسيق تاريخ غير صحيح',
      errorInvalidText: 'نطاق غير صالح',
      errorInvalidRangeText: 'نطاق غير صالح',
      fieldStartLabelText: 'من تاريخ',
      fieldEndLabelText: 'إلى تاريخ',
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _filterTransactions();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedType = 'all';
      _startDate = null;
      _endDate = null;
      _filteredTransactions = _transactions;
    });
  }

  void _viewTransactionDetails(Map<String, dynamic> transaction) {
    if (transaction['type'] == 'sale') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SaleInvoiceDetailsScreen(
            invoiceId: transaction['id'],
          ),
        ),
      );
    } else if (transaction['type'] == 'purchase') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PurchaseInvoiceDetailsScreen(
            invoiceId: transaction['id'],
          ),
        ),
      );
    }
  }

  double get _totalSales {
    return _filteredTransactions
        .where((t) => t['type'] == 'sale')
        .fold(0.0, (sum, t) => sum + (t['total_amount'] as num).toDouble());
  }

  double get _totalPurchases {
    return _filteredTransactions
        .where((t) => t['type'] == 'purchase')
        .fold(0.0, (sum, t) => sum + (t['total_amount'] as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('💰 سجل المعاملات'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر البحث
          Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'نوع المعاملة',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(value: 'all', child: Text('جميع المعاملات')),
                      DropdownMenuItem(value: 'sale', child: Text('مبيعات')),
                      DropdownMenuItem(value: 'purchase', child: Text('مشتريات')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedType = value!);
                      _filterTransactions();
                    },
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _selectDateRange,
                          icon: Icon(Icons.calendar_today, size: 20),
                          label: Text(
                            _startDate == null
                                ? 'اختر الفترة'
                                : '${DateFormat('yyyy-MM-dd').format(_startDate!)} - ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.clear, size: 20, color: Colors.red),
                        onPressed: _clearFilters,
                        tooltip: 'مسح الفلاتر',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // إحصائيات سريعة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildStatCard(
                  title: 'المعاملات',
                  value: _filteredTransactions.length.toString(),
                  icon: Icons.receipt,
                  color: Colors.blue,
                ),
                SizedBox(width: 8),
                _buildStatCard(
                  title: 'المبيعات',
                  value: '${_totalSales.toStringAsFixed(0)} ر.س',
                  icon: Icons.shopping_cart,
                  color: Colors.green,
                ),
                SizedBox(width: 8),
                _buildStatCard(
                  title: 'المشتريات',
                  value: '${_totalPurchases.toStringAsFixed(0)} ر.س',
                  icon: Icons.shopping_bag,
                  color: Colors.orange,
                ),
              ],
            ),
          ),

          // قائمة المعاملات
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? _buildEmptyState()
                : _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  SizedBox(width: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            'لا توجد معاملات',
            style: TextStyle(fontSize: 18, color: Colors.grey[500]),
          ),
          SizedBox(height: 8),
          Text(
            'قم بإضافة فواتير مبيعات أو مشتريات',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: _filteredTransactions.length,
        itemBuilder: (context, index) {
          return _buildTransactionItem(_filteredTransactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isSale = transaction['type'] == 'sale';
    final color = transaction['color'] as Color;
    final icon = transaction['icon'] as IconData;
    final date = DateTime.parse(transaction['date'] ?? '');

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          transaction['invoice_number'] ?? 'بدون رقم',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSale
                  ? 'العميل: ${transaction['customer_name'] ?? 'نقدي'}'
                  : 'المورد: ${transaction['supplier_name'] ?? 'غير معروف'}',
              style: TextStyle(fontSize: 12),
            ),
            Text(
              'التاريخ: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            _buildStatusChip(transaction['status']),
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${(transaction['total_amount'] as num).toStringAsFixed(0)} ر.س',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSale ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isSale ? 'بيع' : 'شراء',
                style: TextStyle(
                  fontSize: 10,
                  color: isSale ? Colors.green : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _viewTransactionDetails(transaction),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'مكتمل';
        break;
      case 'draft':
        color = Colors.orange;
        text = 'مسودة';
        break;
      case 'cancelled':
        color = Colors.red;
        text = 'ملغى';
        break;
      default:
        color = Colors.grey;
        text = 'غير معروف';
    }

    return Container(
      margin: EdgeInsets.only(top: 4),
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// شاشة تفاصيل فاتورة البيع
class SaleInvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;

  const SaleInvoiceDetailsScreen({Key? key, required this.invoiceId}) : super(key: key);

  @override
  _SaleInvoiceDetailsScreenState createState() => _SaleInvoiceDetailsScreenState();
}

class _SaleInvoiceDetailsScreenState extends State<SaleInvoiceDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    try {
      final result = await _dbHelper.getSaleInvoiceWithItems(widget.invoiceId);
      if (result != null) {
        setState(() {
          _invoice = result['invoice'];
          _items = result['items'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('خطأ في تحميل التفاصيل: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة بيع #${_invoice?['invoice_number'] ?? ''}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // معلومات الفاتورة
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('معلومات الفاتورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    _buildInfoRow('رقم الفاتورة', _invoice?['invoice_number']),
                    _buildInfoRow('العميل', _invoice?['customer_name'] ?? 'نقدي'),
                    _buildInfoRow('المخزن', _invoice?['warehouse_name']),
                    _buildInfoRow('طريقة الدفع', _invoice?['payment_method'] == 'cash' ? 'نقدي' : 'آجل'),
                    _buildInfoRow('الحالة', _invoice?['status'] == 'approved' ? 'مكتمل' : 'مسودة'),
                    _buildInfoRow('المبلغ الإجمالي', '${_invoice?['total_amount']?.toStringAsFixed(0) ?? '0'} ر.س'),
                    _buildInfoRow('المدفوع', '${_invoice?['paid_amount']?.toStringAsFixed(0) ?? '0'} ر.س'),
                    _buildInfoRow('المتبقي', '${((_invoice?['total_amount'] ?? 0) - (_invoice?['paid_amount'] ?? 0)).toStringAsFixed(0)} ر.س'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // المنتجات
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    ..._items.map((item) => _buildProductItem(item)),
                    SizedBox(height: 16),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المجموع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${_items.fold(0.0, (sum, item) => sum + (item['total_price'] as num).toDouble()).toStringAsFixed(0)} ر.س',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          ),
          Expanded(
            child: Text(value ?? 'غير متوفر'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(Icons.inventory_2, size: 20),
      ),
      title: Text(item['product_name'] ?? ''),
      subtitle: Text('${item['quantity']} × ${item['unit_price']} ر.س'),
      trailing: Text('${item['total_price']} ر.س'),
    );
  }
}

// شاشة تفاصيل فاتورة الشراء (مشابهة للبيع)
class PurchaseInvoiceDetailsScreen extends StatefulWidget {
  final int invoiceId;

  const PurchaseInvoiceDetailsScreen({Key? key, required this.invoiceId}) : super(key: key);

  @override
  _PurchaseInvoiceDetailsScreenState createState() => _PurchaseInvoiceDetailsScreenState();
}

class _PurchaseInvoiceDetailsScreenState extends State<PurchaseInvoiceDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic>? _invoice;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    try {
      final result = await _dbHelper.getPurchaseInvoiceWithItems(widget.invoiceId);
      if (result != null) {
        setState(() {
          _invoice = result['invoice'];
          _items = result['items'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('خطأ في تحميل التفاصيل: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('فاتورة شراء #${_invoice?['invoice_number'] ?? ''}'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('معلومات الفاتورة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    _buildInfoRow('رقم الفاتورة', _invoice?['invoice_number']),
                    _buildInfoRow('المورد', _invoice?['supplier_name']),
                    _buildInfoRow('المخزن', _invoice?['warehouse_name']),
                    _buildInfoRow('الحالة', _invoice?['status'] == 'approved' ? 'مكتمل' : 'مسودة'),
                    _buildInfoRow('المبلغ الإجمالي', '${_invoice?['total_amount']?.toStringAsFixed(0) ?? '0'} ر.س'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المنتجات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    ..._items.map((item) => _buildProductItem(item)),
                    SizedBox(height: 16),
                    Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('المجموع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${_items.fold(0.0, (sum, item) => sum + (item['total_price'] as num).toDouble()).toStringAsFixed(0)} ر.س',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
    children: [
    Expanded(
    child: Text('$label:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
    ),
    Expanded(
    child: Text(value ?? 'غير متوفر'),
    ),
    ])
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        child: Icon(Icons.inventory_2, size: 20),
      ),
      title: Text(item['product_name'] ?? ''),
      subtitle: Text('${item['quantity']} × ${item['unit_price']} ر.س'),
      trailing: Text('${item['total_price']} ر.س'),
    );
  }
}