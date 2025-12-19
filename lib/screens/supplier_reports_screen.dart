import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

import '../database_helper.dart';

class SupplierReportsScreen extends StatefulWidget {
  @override
  _SupplierReportsScreenState createState() => _SupplierReportsScreenState();
}

class _SupplierReportsScreenState extends State<SupplierReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<Map<String, dynamic>> _suppliersSummary = [];
  Map<String, dynamic>? _selectedSupplierReport;
  int? _selectedSupplierId;
  bool _isLoading = true;
  bool _isLoadingDetails = false;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 365)); // سنة كاملة
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSuppliersSummary();
  }

  Future<void> _loadSuppliersSummary() async {
    setState(() => _isLoading = true);

    try {
      final suppliers = await _dbHelper.getAllSuppliersSummary();
      setState(() {
        _suppliersSummary = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل بيانات الموردين: $e');
    }
  }

  Future<void> _loadSupplierDetailedReport(int supplierId) async {
    setState(() {
      _selectedSupplierId = supplierId;
      _isLoadingDetails = true;
    });

    try {
      final report = await _dbHelper.getSupplierDetailedReport(
          supplierId,
          _startDate,
          _endDate
      );

      setState(() {
        _selectedSupplierReport = report;
        _isLoadingDetails = false;
      });
    } catch (e) {
      setState(() => _isLoadingDetails = false);
      _showError('فشل في تحميل التقرير المفصل: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });

      if (_selectedSupplierId != null) {
        _loadSupplierDetailedReport(_selectedSupplierId!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تقارير الموردين المفصلة'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSuppliersSummary,
          ),
          IconButton(
            icon: Icon(Icons.date_range),
            onPressed: _selectDateRange,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // قائمة الموردين
          _buildSuppliersList(),
          // التقرير المفصل
          _buildDetailedReport(),
        ],
      ),
    );
  }

  Widget _buildSuppliersList() {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'قائمة الموردين',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _suppliersSummary.length,
              itemBuilder: (context, index) {
                final supplier = _suppliersSummary[index];
                final isSelected = _selectedSupplierId == supplier['id'];

                return InkWell(
                  onTap: () => _loadSupplierDetailedReport(supplier['id']),
                  child: Container(
                    color: isSelected ? Colors.indigo.withOpacity(0.1) : Colors.transparent,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo,
                        child: Text(
                          supplier['name'][0],
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(supplier['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المشتريات: ${supplier['total_purchases']} ريال'),
                          Text('الأرباح: ${supplier['generated_profit']?.toStringAsFixed(2)} ريال'),
                        ],
                      ),
                      trailing: Chip(
                        label: Text('${supplier['total_invoices']}'),
                        backgroundColor: Colors.indigo.withOpacity(0.1),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedReport() {
    if (_selectedSupplierReport == null) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eighteen_mp_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'اختر مورداً لعرض التقرير المفصل',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingDetails) {
      return Expanded(child: Center(child: CircularProgressIndicator()));
    }

    final report = _selectedSupplierReport!;
    final supplierInfo = report['supplier_info'];
    final summary = report['summary'];
    final monthlySales = report['monthly_sales'] ?? [];
    final topProducts = report['top_products'] ?? [];

    return Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس التقرير
            _buildReportHeader(supplierInfo, summary),
            SizedBox(height: 20),

            // الإحصائيات الرئيسية
            _buildSummaryCards(summary),
            SizedBox(height: 20),

            // مخطط المبيعات الشهرية
            if (monthlySales.isNotEmpty) ...[
              _buildMonthlySalesChart(monthlySales),
              SizedBox(height: 20),
            ],

            // أفضل المنتجات أداءً
            if (topProducts.isNotEmpty) ...[
              _buildTopProducts(topProducts),
              SizedBox(height: 20),
            ],

            // فواتير الشراء
            _buildPurchaseInvoices(report['purchase_invoices'] ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHeader(Map<String, dynamic> supplierInfo, Map<String, dynamic> summary) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.indigo,
              child: Text(
                supplierInfo['name'][0],
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplierInfo['name'],
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (supplierInfo['phone'] != null)
                    Text('الهاتف: ${supplierInfo['phone']}'),
                  if (supplierInfo['email'] != null)
                    Text('البريد: ${supplierInfo['email']}'),
                  Text(
                    'الفترة: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Chip(
                  label: Text(
                    '${summary['total_products']} منتج',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.indigo,
                ),
                SizedBox(height: 4),
                Chip(
                  label: Text(
                    '${summary['total_items_purchased']} صنف مشترى',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> summary) {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildSummaryCard(
          'إجمالي المشتريات',
          '${summary['total_purchases']?.toStringAsFixed(2)} ريال',
          Icons.shopping_cart,
          Colors.blue,
        ),
        _buildSummaryCard(
          'المبلغ المدفوع',
          '${summary['total_paid']?.toStringAsFixed(2)} ريال',
          Icons.payment,
          Colors.green,
        ),
        _buildSummaryCard(
          'المتبقي',
          '${summary['remaining_balance']?.toStringAsFixed(2)} ريال',
          Icons.account_balance_wallet,
          Colors.orange,
        ),
        _buildSummaryCard(
          'الأرباح المتحققة',
          '${summary['total_generated_profit']?.toStringAsFixed(2)} ريال',
          Icons.attach_money,
          Colors.purple,
        ),
        _buildSummaryCard(
          'الإيرادات',
          '${summary['total_generated_revenue']?.toStringAsFixed(2)} ريال',
          Icons.trending_up,
          Colors.teal,
        ),
        _buildSummaryCard(
          'المنتجات المباعة',
          '${summary['total_products_sold']}',
          Icons.inventory_2,
          Colors.red,
        ),
        _buildSummaryCard(
          'هامش الربح',
          '${summary['profit_margin']?.toStringAsFixed(1)}%',
          Icons.percent,
          Colors.indigo,
        ),
        _buildSummaryCard(
          'عائد الاستثمار',
          '${_calculateROI(summary)}%',
          Icons.bar_chart,
          Colors.amber,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 20, color: color),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesChart(List<Map<String, dynamic>> monthlySales) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الأرباح الشهرية من منتجات المورد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Container(
            //   height: 250,
            //   child: SfCartesianChart(
            //     primaryXAxis: CategoryAxis(),
            //     legend: Legend(isVisible: true),
            //     series: <CartesianSeries>[
            //       ColumnSeries<Map<String, dynamic>, String>(
            //         dataSource: monthlySales,
            //         xValueMapper: (data, _) => _formatMonth(data['month']),
            //         yValueMapper: (data, _) => data['profit']?.toDouble() ?? 0,
            //         name: 'الأرباح',
            //         color: Colors.green,
            //       ),
            //       LineSeries<Map<String, dynamic>, String>(
            //         dataSource: monthlySales,
            //         xValueMapper: (data, _) => _formatMonth(data['month']),
            //         yValueMapper: (data, _) => data['revenue']?.toDouble() ?? 0,
            //         name: 'الإيرادات',
            //         color: Colors.blue,
            //         markerSettings: MarkerSettings(isVisible: true),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopProducts(List<Map<String, dynamic>> topProducts) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أفضل المنتجات أداءً',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              final profit = product['profit']?.toDouble() ?? 0;
              final margin = product['profit_margin']?.toDouble() ?? 0;

              return Card(
                margin: EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getProfitColor(profit),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(product['name']),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مبيع: ${product['total_sold']} - إيراد: ${product['revenue']?.toStringAsFixed(2)} ريال'),
                      Text('التكلفة: ${product['cost']?.toStringAsFixed(2)} ريال'),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${profit.toStringAsFixed(2)} ريال',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getProfitColor(profit),
                        ),
                      ),
                      Text(
                        '${margin.toStringAsFixed(1)}% هامش',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseInvoices(List<Map<String, dynamic>> invoices) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فواتير الشراء (${invoices.length})',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...invoices.map((invoice) => ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.receipt, color: Colors.white, size: 20),
              ),
              title: Text('فاتورة #${invoice['invoice_number']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المبلغ: ${invoice['total_amount']} ريال - المدفوع: ${invoice['paid_amount']} ريال'),
                  Text('التاريخ: ${_formatDisplayDate(DateTime.parse(invoice['invoice_date']))}'),
                ],
              ),
              children: [
                // يمكن إضافة بنود الفاتورة هنا إذا أردت
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('المخزن: ${invoice['warehouse_name']}'),
                      Chip(
                        label: Text(
                          invoice['status'] == 'approved' ? 'معتمدة' : 'مسودة',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: invoice['status'] == 'approved' ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  double _calculateROI(Map<String, dynamic> summary) {
    final purchases = summary['total_purchases']?.toDouble() ?? 0;
    final profit = summary['total_generated_profit']?.toDouble() ?? 0;

    if (purchases > 0) {
      return (profit / purchases) * 100;
    }
    return 0;
  }

  Color _getProfitColor(double profit) {
    if (profit > 0) return Colors.green;
    if (profit < 0) return Colors.red;
    return Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDisplayDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatMonth(String monthStr) {
    final parts = monthStr.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final month = int.parse(parts[1]);
      final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
      return '${months[month - 1]}\n$year';
    }
    return monthStr;
  }
}