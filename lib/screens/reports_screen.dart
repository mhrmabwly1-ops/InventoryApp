import 'package:flutter/material.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';

import '../database_helper.dart';
import 'profit_reports_screen.dart';
import 'system_statistics_screen.dart';

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  List<Map<String, dynamic>> _monthlySales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReportsData();
  }

  Future<void> _loadReportsData() async {
    setState(() => _isLoading = true);

    try {
      final summary = await _dbHelper.getReportsSummary();
      final topProducts = await _dbHelper.getTopSellingProducts(limit: 5);
      final lowStockProducts = await _dbHelper.getLowStockProducts();
      final monthlySales = await _dbHelper.getMonthlySalesReport(DateTime.now().year);

      setState(() {
        _summary = summary;
        _topProducts = topProducts;
        _lowStockProducts = lowStockProducts;
        _monthlySales = monthlySales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل في تحميل البيانات: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('التقارير الشاملة'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadReportsData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // بطاقات الإحصائيات السريعة
            _buildSummaryCards(),
            SizedBox(height: 20),

            // مخطط المبيعات الشهرية
            _buildSalesChart(),
            SizedBox(height: 20),

            // أفضل المنتجات مبيعاً
            _buildTopProducts(),
            SizedBox(height: 20),

            // المنتجات منخفضة المخزون
            _buildLowStockProducts(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: [
        _buildSummaryCard(
          'المبيعات الشهرية',
          '${_summary['monthly_sales']} ريال',
          Icons.shopping_cart,
          Colors.green,
          '${_summary['monthly_invoices']} فاتورة',
        ),
        _buildSummaryCard(
          'مبيعات اليوم',
          '${_summary['today_sales']} ريال',
          Icons.today,
          Colors.blue,
          '${_summary['today_invoices']} فاتورة',
        ),
        _buildSummaryCard(
          'قيمة المخزون',
          '${_summary['inventory_value']} ريال',
          Icons.inventory_2,
          Colors.orange,
          '${_summary['total_products']} منتج',
        ),
        _buildSummaryCard(
          'رصيد العملاء',
          '${_summary['total_balance']} ريال',
          Icons.people,
          Colors.purple,
          '${_summary['total_customers']} عميل',
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesChart() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المبيعات الشهرية - ${DateTime.now().year}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.bar_chart, color: Colors.deepPurple),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SystemStatisticsScreen()),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: 16),
            // Container(
            //   height: 200,
            //   child: SfCartesianChart(
            //     primaryXAxis: CategoryAxis(),
            //     series: <ColumnSeries<Map<String, dynamic>, String>>[
            //       ColumnSeries<Map<String, dynamic>, String>(
            //         dataSource: _monthlySales,
            //         xValueMapper: (Map<String, dynamic> sales, _) => _getMonthName(int.parse(sales['month'])),
            //         yValueMapper: (Map<String, dynamic> sales, _) => sales['total_sales']?.toDouble() ?? 0,
            //         color: Colors.deepPurple,
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

  Widget _buildTopProducts() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'أفضل المنتجات مبيعاً',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text('هذا الشهر'),
                  backgroundColor: Colors.green.withOpacity(0.1),
                ),
              ],
            ),
            SizedBox(height: 16),
            ..._topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return _buildProductRankingItem(index + 1, product);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRankingItem(int rank, Map<String, dynamic> product) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getRankColor(rank),
        child: Text(
          '$rank',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(product['name']),
      subtitle: Text('${product['category_name'] ?? 'بدون فئة'}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${product['total_sold']} مبيع',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${product['total_revenue']} ريال',
            style: TextStyle(fontSize: 12, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockProducts() {
    if (_lowStockProducts.isEmpty) {
      return SizedBox(); // لا تظهر إذا لم توجد منتجات منخفضة المخزون
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'منتجات منخفضة المخزون',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 16),
            ..._lowStockProducts.take(5).map((product) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withOpacity(0.1),
                child: Icon(Icons.inventory_2, color: Colors.orange),
              ),
              title: Text(product['name']),
              subtitle: Text('المخزون الحالي: ${product['total_stock']}'),
              trailing: Chip(
                label: Text(
                  'منخفض',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orange,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.amber;
      case 2: return Colors.grey;
      case 3: return Colors.brown;
      default: return Colors.blue;
    }
  }

  String _getMonthName(int month) {
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }
}