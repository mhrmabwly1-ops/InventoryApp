import 'package:flutter/material.dart';

import 'color.dart';
import 'database_helper.dart';
import 'settings_reactive.dart';
import 'settings_store.dart';

class SalesScreen extends StatefulWidget {
  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SettingsReactive<SalesScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _customerController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _cartItems = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _products = [];

  int? _selectedCustomerId;
  int? _selectedWarehouseId;
  double _totalAmount = 0.0;
  double _paidAmount = 0.0;
  double _changeAmount = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    startSettingsListener();
  }

  @override
  void dispose() {
    stopSettingsListener();
    _barcodeController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final customers = await _dbHelper.getCustomers();
      final warehouses = await _dbHelper.getWarehouses();
      final products = await _dbHelper.getProducts();

      setState(() {
        _customers = customers;
        _warehouses = warehouses;
        _products = products;
        if (warehouses.isNotEmpty) _selectedWarehouseId = warehouses.first['id'];
      });
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  void _addToCart(Map<String, dynamic> product) {
    final existingItemIndex = _cartItems.indexWhere((item) => item['product_id'] == product['id']);

    if (existingItemIndex != -1) {
      setState(() {
        _cartItems[existingItemIndex]['quantity'] += 1;
        _cartItems[existingItemIndex]['total_price'] =
            _cartItems[existingItemIndex]['quantity'] * _cartItems[existingItemIndex]['sell_price'];
      });
    } else {
      setState(() {
        _cartItems.add({
          'product_id': product['id'],
          'product_name': product['name'],
          'barcode': product['barcode'],
          'purchase_price': product['purchase_price'],
          'sell_price': product['sell_price'],
          'quantity': 1,
          'total_price': product['sell_price'],
        });
      });
    }
    _calculateTotal();
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _calculateTotal();
    });
  }

  void _updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      setState(() {
        _cartItems[index]['quantity'] = newQuantity;
        _cartItems[index]['total_price'] = newQuantity * _cartItems[index]['sell_price'];
        _calculateTotal();
      });
    }
  }

  void _calculateTotal() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) => sum + (item['total_price'] as double));
    _calculateChange();
  }

  void _calculateChange() {
    _changeAmount = _paidAmount - _totalAmount;
  }

  Future<void> _searchProductByBarcode(String barcode) async {
    if (barcode.length >= 3) {
      try {
        final product = _products.firstWhere(
              (p) => p['barcode']?.toString() == barcode,
          orElse: () => {},
        );

        if (product.isNotEmpty) {
          _addToCart(product);
          _barcodeController.clear();
        } else {
          final dbProduct = await _dbHelper.getProductByBarcode(barcode);
          if (dbProduct != null) {
            _addToCart(dbProduct);
            _barcodeController.clear();
          }
        }
      } catch (e) {
        print('Error searching product: $e');
      }
    }
  }

  Future<void> _completeSale() async {
    if (_cartItems.isEmpty) {
      _showSnackBar('السلة فارغة', isError: true);
      return;
    }

    if (_selectedWarehouseId == null) {
      _showSnackBar('يرجى اختيار المخزن', isError: true);
      return;
    }

    if (_paidAmount < _totalAmount) {
      _showSnackBar('المبلغ المدفوع غير كافي', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final invoiceData = {
        'customer_id': _selectedCustomerId,
        'warehouse_id': _selectedWarehouseId,
        'total_amount': _totalAmount,
        'paid_amount': _paidAmount,
        'discount': 0.0,
        'payment_method': 'cash',
        'notes': _notesController.text.trim(),
      };

      final result = await _dbHelper.createSaleInvoice(invoiceData);

      if (result['success'] == true) {
        // إضافة بنود الفاتورة
        for (final item in _cartItems) {
          await _dbHelper.insertSaleItem({
            'sale_invoice_id': result['invoice_id'],
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'unit_price': item['sell_price'],
            'cost_price': item['purchase_price'],
            'total_price': item['total_price'],
          });
        }

        // اعتماد الفاتورة
        final approval = await _dbHelper.approveSaleInvoice(result['invoice_id']);

        if (approval['success'] == true) {
          _showSnackBar('تم إتمام البيع بنجاح', isError: false);
          _resetForm();
        } else {
          _showSnackBar('فشل في اعتماد الفاتورة: ${approval['error']}', isError: true);
        }
      } else {
        _showSnackBar('فشل في إنشاء الفاتورة: ${result['error']}', isError: true);
      }
    } catch (e) {
      _showSnackBar('خطأ في إتمام البيع: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _cartItems.clear();
      _totalAmount = 0.0;
      _paidAmount = 0.0;
      _changeAmount = 0.0;
      _barcodeController.clear();
      _notesController.clear();
      _selectedCustomerId = null;
    });
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showProductSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => ProductSearchDialog(
        products: _products,
        onProductSelected: _addToCart,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text('نقطة البيع'),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _showProductSearchDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // معلومات البيع الأساسية
          Card(
            margin: EdgeInsets.all(8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedWarehouseId,
                          decoration: InputDecoration(
                            labelText: 'المخزن',
                            border: OutlineInputBorder(),
                          ),
                          items: _warehouses.map((warehouse) {
                            return DropdownMenuItem<int?>(
                              value: warehouse['id'],
                              child: Text(warehouse['name']),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedWarehouseId = value),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _selectedCustomerId,
                          decoration: InputDecoration(
                            labelText: 'العميل',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<int?>(value: null, child: Text('بدون عميل')),
                            ..._customers.map((customer) {
                              return DropdownMenuItem<int?>(
                                value: customer['id'],
                                child: Text(customer['name']),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) => setState(() => _selectedCustomerId = value),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: InputDecoration(
                      labelText: 'مسح الباركود',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.qr_code_scanner),
                    ),
                    onChanged: _searchProductByBarcode,
                  ),
                ],
              ),
            ),
          ),

          // قائمة المنتجات في السلة
          Expanded(
            child: _cartItems.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('لا توجد منتجات في السلة', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text('${item['quantity']}', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(item['product_name'], style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('السعر: ${item['sell_price']} ر.س'),
                        Text('الإجمالي: ${item['total_price'].toStringAsFixed(2)} ر.س'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove, color: Colors.red),
                          onPressed: () => _updateQuantity(index, item['quantity'] - 1),
                        ),
                        Text('${item['quantity']}', style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: Icon(Icons.add, color: Colors.green),
                          onPressed: () => _updateQuantity(index, item['quantity'] + 1),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeFromCart(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ملخص الفاتورة والدفع
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('الإجمالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${_totalAmount.toStringAsFixed(2)} ر.س',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ],
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المدفوع',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _paidAmount = double.tryParse(value) ?? 0.0;
                      _calculateChange();
                    });
                  },
                ),
                if (_changeAmount >= 0) ...[
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الباقي:', style: TextStyle(fontSize: 16)),
                      Text('${_changeAmount.toStringAsFixed(2)} ر.س',
                          style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                        : Text('إتمام البيع', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductSearchDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onProductSelected;

  const ProductSearchDialog({required this.products, required this.onProductSelected});

  @override
  _ProductSearchDialogState createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = widget.products;
      } else {
        _filteredProducts = widget.products.where((product) {
          final name = product['name']?.toString().toLowerCase() ?? '';
          final barcode = product['barcode']?.toString().toLowerCase() ?? '';
          final searchTerm = query.toLowerCase();
          return name.contains(searchTerm) || barcode.contains(searchTerm);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('البحث عن المنتج', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الباركود...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
            ),
            SizedBox(height: 16),
            Text('النتائج: ${_filteredProducts.length}', style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 16),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    SizedBox(height: 16),
                    Text('لا توجد منتجات مطابقة', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: Icon(Icons.inventory, color: Colors.blue),
                      title: Text(product['name'], style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('السعر: ${product['sell_price']} ر.س'),
                          if (product['barcode'] != null) Text('الباركود: ${product['barcode']}'),
                        ],
                      ),
                      trailing: Icon(Icons.add, color: Colors.green),
                      onTap: () {
                        widget.onProductSelected(product);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}