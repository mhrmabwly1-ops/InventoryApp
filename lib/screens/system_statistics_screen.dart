import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';

import '../database_helper.dart';

class SystemStatisticsScreen extends StatefulWidget {
  @override
  _SystemStatisticsScreenState createState() => _SystemStatisticsScreenState();
}

class _SystemStatisticsScreenState extends State<SystemStatisticsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _monthlySales = [];
  List<Map<String, dynamic>> _yearlySales = [];
  List<Map<String, dynamic>> _customerStats = [];
  List<Map<String, dynamic>> _productStats = [];
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final monthlySales = await _dbHelper.getMonthlySalesReport(_selectedYear);
      final customerStats = await _dbHelper.getCustomersReport();
      final productStats = await _dbHelper.getInventoryReport();

      // حساب المبيعات السنوية (سنوي لمدة 5 سنوات)
      final yearlySales = await _calculateYearlySales();

      setState(() {
        _monthlySales = monthlySales;
        _yearlySales = yearlySales;
        _customerStats = customerStats.take(10).toList();
        _productStats = productStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل الإحصائيات: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _calculateYearlySales() async {
    final db = await _dbHelper.database;
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (index) => currentYear - index);

    List<Map<String, dynamic>> result = [];

    for (final year in years) {
      final sales = await db.rawQuery('''
        SELECT COALESCE(SUM(total_amount), 0) as total_sales
        FROM sale_invoices 
        WHERE status = 'approved' AND strftime('%Y', invoice_date) = ?
      ''', [year.toString()]);

      result.add({
        'year': year.toString(),
        'total_sales': sales.first['total_sales'],
      });
    }

    return result.reversed.toList();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إحصائيات النظام'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // مخطط المبيعات السنوية
            _buildYearlySalesChart(),
            SizedBox(height: 20),

            // مخطط المبيعات الشهرية
            _buildMonthlySalesChart(),
            SizedBox(height: 20),

            // إحصائيات العملاء
            _buildCustomerStatistics(),
            SizedBox(height: 20),

            // إحصائيات المنتجات
            _buildProductStatistics(),
          ],
        ),
      ),
    );
  }

  Widget _buildYearlySalesChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المبيعات السنوية',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Container(
            //   height: 200,
            //   child: SfCartesianChart(
            //     primaryXAxis: CategoryAxis(),
            //     series: <LineSeries<Map<String, dynamic>, String>>[
            //       LineSeries<Map<String, dynamic>, String>(
            //         dataSource: _yearlySales,
            //         xValueMapper: (Map<String, dynamic> sales, _) => sales['year'],
            //         yValueMapper: (Map<String, dynamic> sales, _) => sales['total_sales']?.toDouble() ?? 0,
            //         color: Colors.green,
            //         markerSettings: MarkerSettings(isVisible: true),
            //         dataLabelSettings: DataLabelSettings(isVisible: true),
            //       )
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySalesChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'المبيعات الشهرية - $_selectedYear',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Container(
            //   height: 300,
            //   child: SfCartesianChart(
            //     primaryXAxis: CategoryAxis(),
            //     series: <ColumnSeries<Map<String, dynamic>, String>>[
            //       ColumnSeries<Map<String, dynamic>, String>(
            //         dataSource: _monthlySales,
            //         xValueMapper: (Map<String, dynamic> sales, _) => _getMonthName(int.parse(sales['month'])),
            //         yValueMapper: (Map<String, dynamic> sales, _) => sales['total_sales']?.toDouble() ?? 0,
            //         color: Colors.blue,
            //         dataLabelSettings: DataLabelSettings(isVisible: true),
            //       )
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerStatistics() {
    final topCustomers = _customerStats.take(5).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أفضل العملاء',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...topCustomers.asMap().entries.map((entry) {
              final index = entry.key;
              final customer = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.withOpacity(0.1),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(customer['name']),
                subtitle: Text('${customer['total_invoices'] ?? 0} فاتورة'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${customer['total_purchases'] ?? 0} ريال',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    Text(
                      'رصيد: ${customer['balance'] ?? 0}',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProductStatistics() {
    final valuableProducts = _productStats
        .where((p) => (p['total_stock'] ?? 0) > 0)
        .toList()
      ..sort((a, b) => ((b['total_stock'] ?? 0) * (b['purchase_price'] ?? 0))
          .compareTo((a['total_stock'] ?? 0) * (a['purchase_price'] ?? 0)));

    final topValuable = valuableProducts.take(5).toList();

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أعلى المنتجات قيمة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ...topValuable.map((product) {
              final stockValue = (product['total_stock'] ?? 0) * (product['purchase_price'] ?? 0);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: Icon(Icons.inventory_2, color: Colors.orange),
                ),
                title: Text(product['name']),
                subtitle: Text('الكمية: ${product['total_stock'] ?? 0}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${stockValue.toStringAsFixed(2)} ريال',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    Text(
                      '${product['profit_percentage']?.toStringAsFixed(1) ?? 0}% ربح',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }
}