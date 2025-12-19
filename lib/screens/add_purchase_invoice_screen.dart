import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../settings_reactive.dart';
import '../settings_store.dart';

class AddPurchaseInvoiceScreen extends StatefulWidget {
  @override
  _AddPurchaseInvoiceScreenState createState() => _AddPurchaseInvoiceScreenState();
}

class _AddPurchaseInvoiceScreenState extends State<AddPurchaseInvoiceScreen> with SettingsReactive<AddPurchaseInvoiceScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _warehouses = [];
  List<Map<String, dynamic>> _products = [];

  int? _selectedSupplierId;
  int? _selectedWarehouseId;
  String _notes = '';
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    startSettingsListener();
  }

  @override
  void dispose() {
    _notesController.dispose();
    stopSettingsListener();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final suppliers = await _dbHelper.getSuppliers();
      final warehouses = await _dbHelper.getWarehouses();
      final products = await _dbHelper.getProducts();

      setState(() {
        _suppliers = suppliers;
        _warehouses = warehouses;
        _products = products;
        if (warehouses.isNotEmpty) _selectedWarehouseId = warehouses.first['id'];
      });
    } catch (e) {
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

  void _addItem() {
    showDialog(
      context: context,
      builder: (context) => AddPurchaseItemDialog(
        products: _products,
        onAdd: (item) {
          setState(() {
            _items.add(item);
          });
        },
      ),
    );
  }

  void _editItem(int index) {
    final item = _items[index];
    showDialog(
      context: context,
      builder: (context) => AddPurchaseItemDialog(
        products: _products,
        initialProductId: item['product_id'],
        initialQuantity: item['quantity'],
        initialUnitPrice: item['unit_price'],
        isEditing: true,
        onAdd: (updatedItem) {
          setState(() {
            _items[index] = updatedItem;
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف هذا المنتج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  double get _totalAmount {
    return _items.fold(0, (sum, item) => sum + (item['total_price'] as double));
  }

  Future<void> _submitInvoice() async {
    if (_selectedSupplierId == null) {
      _showError('يرجى اختيار المورد');
      return;
    }

    if (_selectedWarehouseId == null) {
      _showError('يرجى اختيار المخزن');
      return;
    }

    if (_items.isEmpty) {
      _showError('يرجى إضافة منتجات على الأقل');
      return;
    }

    // تحضير البيانات للقاعدة
    final List<Map<String, dynamic>> itemsForDb = _items.map((item) {
      return {
        'product_id': item['product_id'],
        'quantity': item['quantity'],
        'unit_price': item['unit_price'],
      };
    }).toList();

    final invoice = {
      'supplier_id': _selectedSupplierId,
      'warehouse_id': _selectedWarehouseId,
      'notes': _notesController.text.trim(),
      'invoice_date': DateTime.now().toIso8601String(),
      'status': 'draft',
    };

    final result = await _dbHelper.createPurchaseInvoiceWithItems(invoice, itemsForDb);

    if (result['success'] ?? false) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء فاتورة الشراء بنجاح - رقم: ${result['invoice_number']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showError(result['error'] ?? 'حدث خطأ غير معروف');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة فاتورة شراء', style: TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: Icon(Icons.save, size: 22),
            onPressed: _submitInvoice,
            tooltip: 'حفظ',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // معلومات الفاتورة الأساسية
              _buildBasicInfo(),
              SizedBox(height: 16),

              // بنود الفاتورة
              _buildInvoiceItems(),
              SizedBox(height: 16),

              // المجموع
              _buildTotalSection(),
              SizedBox(height: 16),

              // زر الحفظ
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue),
                SizedBox(width: 8),
                Text('معلومات الفاتورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedSupplierId,
              decoration: InputDecoration(
                labelText: 'المورد',
                labelStyle: TextStyle(fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _suppliers.map((supplier) {
                return DropdownMenuItem<int>(
                  value: supplier['id'],
                  child: Text(supplier['name'] ?? '', style: TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSupplierId = value;
                });
              },
              validator: (value) => value == null ? 'يرجى اختيار المورد' : null,
              isExpanded: true,
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedWarehouseId,
              decoration: InputDecoration(
                labelText: 'المخزن',
                labelStyle: TextStyle(fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _warehouses.map((warehouse) {
                return DropdownMenuItem<int>(
                  value: warehouse['id'],
                  child: Text(warehouse['name'] ?? '', style: TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWarehouseId = value;
                });
              },
              validator: (value) => value == null ? 'يرجى اختيار المخزن' : null,
              isExpanded: true,
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'ملاحظات (اختياري)',
                labelStyle: TextStyle(fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 2,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceItems() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shopping_cart, size: 20, color: Colors.green),
                    SizedBox(width: 8),
                    Text('المنتجات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.add, size: 18),
                  label: Text('إضافة', style: TextStyle(fontSize: 14)),
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            _items.isEmpty
                ? Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'لا توجد منتجات مضافة',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
                : Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: index < _items.length - 1
                          ? Border(bottom: BorderSide(color: Colors.grey[200]!))
                          : null,
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        item['product_name'] ?? '',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الكمية: ${item['quantity']} × ${item['unit_price']} ريال',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            'المجموع: ${item['total_price']} ريال',
                            style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: () => _editItem(index),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                          SizedBox(width: 4),
                          IconButton(
                            icon: Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () => _removeItem(index),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    return Card(
      elevation: 2,
      color: Colors.blue[50],
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المبلغ الإجمالي',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                Text(
                  'عدد المنتجات: ${_items.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_totalAmount.toStringAsFixed(2)} ريال',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                Text(
                  '${_items.length} منتج',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(Icons.save_alt, size: 20),
        label: Text(
          'حفظ الفاتورة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: _submitInvoice,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}

class AddPurchaseItemDialog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onAdd;
  final int? initialProductId;
  final int? initialQuantity;
  final double? initialUnitPrice;
  final bool isEditing;

  const AddPurchaseItemDialog({
    Key? key,
    required this.products,
    required this.onAdd,
    this.initialProductId,
    this.initialQuantity = 1,
    this.initialUnitPrice = 0,
    this.isEditing = false,
  }) : super(key: key);

  @override
  _AddPurchaseItemDialogState createState() => _AddPurchaseItemDialogState();
}

class _AddPurchaseItemDialogState extends State<AddPurchaseItemDialog> {
  int? _selectedProductId;
  int _quantity = 1;
  double _unitPrice = 0;
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
    _quantity = widget.initialQuantity ?? 1;
    _unitPrice = widget.initialUnitPrice ?? 0;

    _quantityController.text = _quantity.toString();
    _priceController.text = _unitPrice.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _addItem() {
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى اختيار المنتج')),
      );
      return;
    }

    final product = widget.products.firstWhere(
          (p) => p['id'] == _selectedProductId,
      orElse: () => {},
    );

    if (product.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('المنتج غير موجود')),
      );
      return;
    }

    final item = {
      'product_id': _selectedProductId,
      'product_name': product['name'] ?? '',
      'quantity': _quantity,
      'unit_price': _unitPrice,
      'total_price': _quantity * _unitPrice,
    };

    widget.onAdd(item);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_shopping_cart, color: Colors.blue),
          SizedBox(width: 8),
          Text(widget.isEditing ? 'تعديل المنتج' : 'إضافة منتج', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedProductId,
              decoration: InputDecoration(
                labelText: 'اختر المنتج',
                labelStyle: TextStyle(fontSize: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: widget.products.map((product) {
                return DropdownMenuItem<int>(
                  value: product['id'],
                  child: Text(
                    product['name'] ?? '',
                    style: TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductId = value;
                  if (value != null) {
                    final product = widget.products.firstWhere((p) => p['id'] == value);
                    _unitPrice = (product['purchase_price'] as num?)?.toDouble() ?? 0;
                    _priceController.text = _unitPrice.toStringAsFixed(2);
                  }
                });
              },
              isExpanded: true,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      labelStyle: TextStyle(fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _quantity = int.tryParse(value) ?? 1;
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'السعر',
                      labelStyle: TextStyle(fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      _unitPrice = double.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            if (_selectedProductId != null && _quantity > 0 && _unitPrice > 0)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المجموع:', style: TextStyle(fontSize: 14)),
                    Text(
                      '${(_quantity * _unitPrice).toStringAsFixed(2)} ريال',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
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
          child: Text('إلغاء', style: TextStyle(fontSize: 14)),
        ),
        ElevatedButton(
          onPressed: _selectedProductId == null ? null : _addItem,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isEditing ? Colors.orange : Colors.green,
          ),
          child: Text(widget.isEditing ? 'تحديث' : 'إضافة', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}