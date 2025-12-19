import 'dart:io' ;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'settings_reactive.dart';
import 'settings_store.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> with SettingsReactive<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ImagePicker _picker = ImagePicker();

  // Controllers for text fields
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController(text: 'قطعة');
  final _purchasePriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _minStockController = TextEditingController();
  final _initialQuantityController = TextEditingController();

  // State variables
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _suppliers = [];
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  File? _productImage;
  DateTime? _lastPurchaseDate;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDropdownData();
    startSettingsListener();
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellPriceController.dispose();
    _minStockController.dispose();
    _initialQuantityController.dispose();
    stopSettingsListener();
    super.dispose();
  }

  // Load categories and suppliers for dropdowns
  Future<void> _loadDropdownData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _dbHelper.getCategories();
      final suppliers = await _dbHelper.getSuppliers(); // ستحتاج لإنشاء هذه الدالة
      setState(() {
        _categories = categories;
        _suppliers = suppliers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحميل البيانات: ${e.toString()}')),
      );
    }
  }

  // Image picker function
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _productImage = File(pickedFile.path);
      });
    }
  }

  // Date picker function
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _lastPurchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _lastPurchaseDate) {
      setState(() {
        _lastPurchaseDate = picked;
      });
    }
  }

  // Save product function
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final productData = {
        'name': _nameController.text,
        'barcode': _barcodeController.text.isNotEmpty ? _barcodeController.text : null,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'category_id': _selectedCategoryId,
        'supplier_id': _selectedSupplierId,
        'unit': _unitController.text,
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0.0,
        'sell_price': double.tryParse(_sellPriceController.text) ?? 0.0,
        'min_stock_level': int.tryParse(_minStockController.text) ?? 0,
        'initial_quantity': int.tryParse(_initialQuantityController.text) ?? 0,
        'current_quantity': int.tryParse(_initialQuantityController.text) ?? 0, // تعيين الكمية الحالية تساوي الابتدائية
        'last_purchase_date': _lastPurchaseDate?.toIso8601String(),
        'image_path': _productImage?.path,
      };

      await _dbHelper.insertProduct(productData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ المنتج بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(); // العودة للشاشة السابقة بعد الحفظ
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ المنتج: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة منتج جديد'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveProduct,
          ),
        ],
      ),

      body: Directionality(
         textDirection: ui.TextDirection.ltr,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                _buildSectionCard('المعلومات الأساسية', [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المنتج *',
                      prefixIcon: Icon(Icons.label),
                    ),
                    validator: (value) => value!.isEmpty ? 'الرجاء إدخال اسم المنتج' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'الباركود (اختياري)',
                      prefixIcon: Icon(Icons.qr_code_scanner),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (اختياري)',
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 3,
                  ),
                ]),
                const SizedBox(height: 16),

                // Section 2: Classification
                _buildSectionCard('التصنيف', [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'الفئة',
                      prefixIcon: Icon(Icons.category),
                    ),
                    value: _selectedCategoryId,
                    items: _categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category['id'] as int,
                        child: Text(category['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategoryId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'المورد',
                      prefixIcon: Icon(Icons.person),
                    ),
                    value: _selectedSupplierId,
                    items: _suppliers.map((supplier) {
                      return DropdownMenuItem<int>(
                        value: supplier['id'] as int,
                        child: Text(supplier['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedSupplierId = value),
                  ),
                ]),
                const SizedBox(height: 16),

                // Section 3: Pricing & Stock
                _buildSectionCard('التسعير والمخزون', [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _purchasePriceController,
                          decoration: const InputDecoration(
                            labelText: 'سعر الشراء',
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            if (double.tryParse(value) == null) return 'قيمة غير صالحة';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _sellPriceController,
                          decoration: const InputDecoration(
                            labelText: 'سعر البيع *',
                            prefixIcon: Icon(Icons.sell),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'الرجاء إدخال سعر البيع';
                            if (double.tryParse(value) == null) return 'قيمة غير صالحة';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(
                            labelText: 'الوحدة',
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _minStockController,
                          decoration: const InputDecoration(
                            labelText: 'حد الطلب الأدنى',
                            prefixIcon: Icon(Icons.warning),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            if (int.tryParse(value) == null) return 'قيمة غير صالحة';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _initialQuantityController,
                    decoration: const InputDecoration(
                      labelText: 'الكمية الابتدائية',
                      prefixIcon: Icon(Icons.add_box),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (int.tryParse(value) == null) return 'قيمة غير صالحة';
                      return null;
                    },
                  ),
                ]),
                const SizedBox(height: 16),

                // Section 4: Image and Date
                _buildSectionCard('صورة وتاريخ', [
                  // Image Picker
                  GestureDetector(
                    onTap: () => _showImagePickerOptions(),
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _productImage != null
                          ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_productImage!, fit: BoxFit.cover))
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text('اضغط لإضافة صورة', style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Picker
                  ListTile(
                    title: const Text('تاريخ آخر عملية شراء'),
                    subtitle: Text(_lastPurchaseDate == null
                        ? 'لم يتم التحديد'
                        : DateFormat('yyyy-MM-dd').format(_lastPurchaseDate!)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ]),
                const SizedBox(height: 32),

                // Save Button
                _isSaving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                  onPressed: _saveProduct,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ المنتج'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to build a section card
  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  // Show bottom sheet for image picker options
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('الكاميرا'),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }
}