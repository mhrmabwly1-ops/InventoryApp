import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

// استيراد فئة قاعدة البيانات
import '_settings.dart';
import 'database_helper.dart';
// استيراد الألوان
import 'app_colors.dart';
import 'settings_reactive.dart';
import 'settings_store.dart';

class UsersManagementScreen extends StatefulWidget {
  @override
  _UsersManagementScreenState createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> with SettingsReactive<UsersManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // متغيرات للنموذج
  String _username = '';
  String _password = '';
  String _confirmPassword = '';
  String _name = '';
  String _role = 'cashier';
  String _permissions = '';
  bool _isActive = true;

  // قائمة الأدوار المتاحة
  final List<String> _roles = [
    'admin',
    'manager',
    'warehouse',
    'cashier',
    'viewer'
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    startSettingsListener();
  }

  @override
  void dispose() {
    stopSettingsListener();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _dbHelper.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('خطأ في تحميل المستخدمين: ${e.toString()}');
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = user['name']?.toString().toLowerCase() ?? '';
        final username = user['username']?.toString().toLowerCase() ?? '';
        final role = user['role']?.toString().toLowerCase() ?? '';

        return name.contains(query.toLowerCase()) ||
            username.contains(query.toLowerCase()) ||
            role.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _showAddUserDialog() {
    _username = '';
    _password = '';
    _confirmPassword = '';
    _name = '';
    _role = 'cashier';
    _permissions = '';
    _isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('إضافة مستخدم جديد'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'اسم المستخدم مطلوب';
                        }
                        if (value.length < 3) {
                          return 'اسم المستخدم يجب أن يكون 3 أحرف على الأقل';
                        }
                        return null;
                      },
                      onChanged: (value) => _username = value.trim(),
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'كلمة المرور مطلوبة';
                        }
                        if (value.length < 6) {
                          return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        }
                        return null;
                      },
                      onChanged: (value) => _password = value,
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value != _password) {
                          return 'كلمات المرور غير متطابقة';
                        }
                        return null;
                      },
                      onChanged: (value) => _confirmPassword = value,
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'الاسم الكامل مطلوب';
                        }
                        return null;
                      },
                      onChanged: (value) => _name = value.trim(),
                    ),
                    SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: InputDecoration(
                        labelText: 'الدور *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                      items: _roles.map((role) {
                        String roleName;
                        switch (role) {
                          case 'admin': roleName = 'مدير النظام'; break;
                          case 'manager': roleName = 'مدير'; break;
                          case 'warehouse': roleName = 'مخازن'; break;
                          case 'cashier': roleName = 'كاشير'; break;
                          case 'viewer': roleName = 'مشاهد'; break;
                          default: roleName = role;
                        }
                        return DropdownMenuItem(
                          value: role,
                          child: Text(roleName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _role = value!;
                        });
                      },
                    ),
                    SizedBox(height: 15),
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'الصلاحيات (اختياري)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.security),
                        hintText: 'صلاحيات إضافية بصيغة JSON',
                      ),
                      onChanged: (value) => _permissions = value,
                    ),
                    SizedBox(height: 15),
                    SwitchListTile(
                      title: Text('الحساب نشط'),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await _addUser();
                  }
                },
                child: Text('إضافة مستخدم'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addUser() async {
    try {
      final newUser = {
        'username': _username,
        'password': _password, // في تطبيق حقيقي، يجب تشفير كلمة المرور
        'name': _name,
        'role': _role,
        'permissions': _permissions.isNotEmpty ? _permissions : null,
        'is_active': _isActive ? 1 : 0,
      };

      final userId = await _dbHelper.insertUser(newUser);

      // إضافة صلاحيات افتراضية حسب الدور
      await _setupDefaultPermissions(userId);

      _showSuccess('تم إضافة المستخدم بنجاح');
      Navigator.pop(context);
      _loadUsers();
    } catch (e) {
      _showError('خطأ في إضافة المستخدم: ${e.toString()}');
    }
  }

  Future<void> _setupDefaultPermissions(int userId) async {
    // صلاحيات افتراضية حسب الدور
    Map<String, List<String>> rolePermissions = {
      'admin': [
        'view_dashboard',
        'manage_products',
        'manage_customers',
        'manage_suppliers',
        'manage_sales',
        'manage_purchases',
        'manage_inventory',
        'manage_reports',
        'manage_users',
        'manage_settings'
      ],
      'manager': [
        'view_dashboard',
        'manage_products',
        'manage_customers',
        'manage_suppliers',
        'manage_sales',
        'manage_purchases',
        'manage_inventory',
        'manage_reports'
      ],
      'warehouse': [
        'view_dashboard',
        'manage_products',
        'manage_inventory'
      ],
      'cashier': [
        'view_dashboard',
        'manage_sales',
        'manage_customers'
      ],
      'viewer': [
        'view_dashboard',
        'view_reports'
      ],
    };

    final permissions = rolePermissions[_role] ?? [];

    for (final permission in permissions) {
      await _dbHelper.updateUserPermission(userId, permission, true);
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    _username = user['username'];
    _name = user['name'] ?? '';
    _role = user['role'] ?? 'cashier';
    _permissions = user['permissions'] ?? '';
    _isActive = (user['is_active'] ?? 1) == 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('تعديل المستخدم'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text('اسم المستخدم'),
                    subtitle: Text(_username),
                    leading: Icon(Icons.person),
                  ),
                  SizedBox(height: 15),
                  TextFormField(
                    initialValue: _name,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الاسم الكامل مطلوب';
                      }
                      return null;
                    },
                    onChanged: (value) => _name = value.trim(),
                  ),
                  SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: InputDecoration(
                      labelText: 'الدور *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    items: _roles.map((role) {
                      String roleName;
                      switch (role) {
                        case 'admin': roleName = 'مدير النظام'; break;
                        case 'manager': roleName = 'مدير'; break;
                        case 'warehouse': roleName = 'مخازن'; break;
                        case 'cashier': roleName = 'كاشير'; break;
                        case 'viewer': roleName = 'مشاهد'; break;
                        default: roleName = role;
                      }
                      return DropdownMenuItem(
                        value: role,
                        child: Text(roleName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _role = value!;
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  TextFormField(
                    initialValue: _permissions,
                    decoration: InputDecoration(
                      labelText: 'الصلاحيات (اختياري)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.security),
                      hintText: 'صلاحيات إضافية بصيغة JSON',
                    ),
                    onChanged: (value) => _permissions = value,
                  ),
                  SizedBox(height: 15),
                  SwitchListTile(
                    title: Text('الحساب نشط'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),
                  SizedBox(height: 15),
                  Divider(),
                  ListTile(
                    title: Text('تغيير كلمة المرور'),
                    subtitle: Text('إضغط هنا لتغيير كلمة مرور المستخدم'),
                    leading: Icon(Icons.lock_reset),
                    onTap: () {
                      Navigator.pop(context);
                      _showChangePasswordDialog(user['id']);
                    },
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
                  await _updateUser(user['id']);
                },
                child: Text('حفظ التعديلات'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateUser(int userId) async {
    try {
      final updatedUser = {
        'name': _name,
        'role': _role,
        'permissions': _permissions.isNotEmpty ? _permissions : null,
        'is_active': _isActive ? 1 : 0,
      };

      await _dbHelper.updateUser(userId, updatedUser);

      // تحديث الصلاحيات الافتراضية إذا تغير الدور
      await _updateUserPermissions(userId);

      _showSuccess('تم تحديث المستخدم بنجاح');
      Navigator.pop(context);
      _loadUsers();
    } catch (e) {
      _showError('خطأ في تحديث المستخدم: ${e.toString()}');
    }
  }

  Future<void> _updateUserPermissions(int userId) async {
    try {
      // الحصول على الصلاحيات الحالية
      final currentPermissions = await _dbHelper.getUserPermissions(userId);

      // تحديث الصلاحيات حسب الدور الجديد
      Map<String, List<String>> rolePermissions = {
        'admin': [
          'view_dashboard',
          'manage_products',
          'manage_customers',
          'manage_suppliers',
          'manage_sales',
          'manage_purchases',
          'manage_inventory',
          'manage_reports',
          'manage_users',
          'manage_settings'
        ],
        'manager': [
          'view_dashboard',
          'manage_products',
          'manage_customers',
          'manage_suppliers',
          'manage_sales',
          'manage_purchases',
          'manage_inventory',
          'manage_reports'
        ],
        'warehouse': [
          'view_dashboard',
          'manage_products',
          'manage_inventory'
        ],
        'cashier': [
          'view_dashboard',
          'manage_sales',
          'manage_customers'
        ],
        'viewer': [
          'view_dashboard',
          'view_reports'
        ],
      };

      final requiredPermissions = rolePermissions[_role] ?? [];

      // تحديث كل الصلاحيات
      for (final permission in requiredPermissions) {
        await _dbHelper.updateUserPermission(userId, permission, true);
      }

      // إلغاء الصلاحيات غير المطلوبة للدور
      for (final currentPermission in currentPermissions) {
        final key = currentPermission['permission_key'] as String;
        if (!requiredPermissions.contains(key)) {
          await _dbHelper.updateUserPermission(userId, key, false);
        }
      }
    } catch (e) {
      print('❌ خطأ في تحديث الصلاحيات: $e');
    }
  }

  void _showChangePasswordDialog(int userId) {
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تغيير كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: newPasswordController,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'كلمة المرور مطلوبة';
                }
                if (value.length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            SizedBox(height: 15),
            TextFormField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value != newPasswordController.text) {
                  return 'كلمات المرور غير متطابقة';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text.length >= 6 &&
                  newPasswordController.text == confirmPasswordController.text) {
                await _changeUserPassword(userId, newPasswordController.text);
              } else {
                _showError('كلمة المرور غير صالحة أو غير متطابقة');
              }
            },
            child: Text('تغيير كلمة المرور'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUserPassword(int userId, String newPassword) async {
    try {
      // في تطبيق حقيقي، يجب تشفير كلمة المرور قبل الحفظ
      await _dbHelper.changeUserPassword(userId, newPassword);
      _showSuccess('تم تغيير كلمة المرور بنجاح');
      Navigator.pop(context);
    } catch (e) {
      _showError('خطأ في تغيير كلمة المرور: ${e.toString()}');
    }
  }

  void _showDeleteUserConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الحذف'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 50, color: Colors.orange),
            SizedBox(height: 10),
            Text('هل أنت متأكد من حذف المستخدم:'),
            SizedBox(height: 5),
            Text(
              '${user['name']} (${user['username']})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '⚠️ هذا الإجراء سيعطل حساب المستخدم ولا يمكن التراجع عنه!',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _deleteUser(user['id']);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف المستخدم'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(int userId) async {
    try {
      // نستخدم التعطيل بدلاً من الحذف المباشر
      await _dbHelper.deleteUser(userId);
      _showSuccess('تم تعطيل المستخدم بنجاح');
      _loadUsers();
    } catch (e) {
      _showError('خطأ في حذف المستخدم: ${e.toString()}');
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final lastLogin = user['last_login'] != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(user['last_login']))
        : 'لم يسجل دخول بعد';

    final createdAt = user['created_at'] != null
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(user['created_at']))
        : 'غير معروف';

    String roleName;
    switch (user['role']) {
      case 'admin': roleName = 'مدير النظام'; break;
      case 'manager': roleName = 'مدير'; break;
      case 'warehouse': roleName = 'مخازن'; break;
      case 'cashier': roleName = 'كاشير'; break;
      case 'viewer': roleName = 'مشاهد'; break;
      default: roleName = user['role'] ?? 'غير معروف';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person, color: AppColors.primary),
                title: Text('اسم المستخدم'),
                subtitle: Text(user['username'] ?? ''),
              ),
              ListTile(
                leading: Icon(Icons.badge, color: AppColors.primary),
                title: Text('الاسم الكامل'),
                subtitle: Text(user['name'] ?? ''),
              ),
              ListTile(
                leading: Icon(Icons.work, color: AppColors.primary),
                title: Text('الدور'),
                subtitle: Text(roleName),
              ),
              ListTile(
                leading: Icon(Icons.calendar_today, color: AppColors.primary),
                title: Text('تاريخ الإنشاء'),
                subtitle: Text(createdAt),
              ),
              ListTile(
                leading: Icon(Icons.login, color: AppColors.primary),
                title: Text('آخر تسجيل دخول'),
                subtitle: Text(lastLogin),
              ),
              ListTile(
                leading: Icon(Icons.verified_user, color: AppColors.primary),
                title: Text('الحالة'),
                subtitle: Text((user['is_active'] ?? 1) == 1 ? '🟢 نشط' : '🔴 معطل'),
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                icon: Icon(Icons.security),
                label: Text('عرض وتعديل الصلاحيات'),
                onPressed: () {
                  Navigator.pop(context);
                  _showUserPermissions(user['id'], user['name']);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 45),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showUserPermissions(int userId, String userName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserPermissionsScreen(
          userId: userId,
          userName: userName,
        ),
      ),
    );
  }


  Future<void> _exportUsersReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري إنشاء تقرير المستخدمين...')),
      );

      // جمع بيانات المستخدمين
      final List<Map<String, dynamic>> reportData = [];

      for (final user in _users) {
        final lastLogin = user['last_login'] != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(user['last_login']))
            : 'لم يسجل دخول بعد';

        final createdAt = user['created_at'] != null
            ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(user['created_at']))
            : 'غير معروف';

        String roleName;
        switch (user['role']) {
          case 'admin': roleName = 'مدير النظام'; break;
          case 'manager': roleName = 'مدير'; break;
          case 'warehouse': roleName = 'مخازن'; break;
          case 'cashier': roleName = 'كاشير'; break;
          case 'viewer': roleName = 'مشاهد'; break;
          default: roleName = user['role'] ?? 'غير معروف';
        }

        reportData.add({
          'اسم المستخدم': user['username'],
          'الاسم الكامل': user['name'],
          'الدور': roleName,
          'الحالة': (user['is_active'] ?? 1) == 1 ? 'نشط' : 'معطل',
          'تاريخ الإنشاء': createdAt,
          'آخر تسجيل دخول': lastLogin,
        });
      }

      // تحويل إلى JSON
      final jsonData = jsonEncode(reportData);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // حفظ في ملف
      final Directory tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/users_report_$timestamp.json';
      final file = File(filePath);
      await file.writeAsString(jsonData);

      // await Share.shareFiles(
      //   [filePath],
      //   text: 'تقرير المستخدمين\nعدد المستخدمين: ${_users.length}\nتاريخ التصدير: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      //   subject: 'تقرير المستخدمين - نظام المخزون',
      // );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ تم تصدير تقرير المستخدمين بنجاح')),
      );
    } catch (e) {
      _showError('خطأ في تصدير تقرير المستخدمين: ${e.toString()}');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
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
        title: Text('إدارة المستخدمين'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'تحديث القائمة',
          ),
          IconButton(
            icon: Icon(Icons.file_download),
            onPressed: _exportUsersReport,
            tooltip: 'تصدير التقرير',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        child: Icon(Icons.add),
        backgroundColor: AppColors.primary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // شريط البحث
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'بحث في المستخدمين...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterUsers('');
                  },
                )
                    : null,
              ),
              onChanged: _filterUsers,
            ),
          ),

          // إحصائيات سريعة
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'المجموع',
                      _users.length.toString(),
                      Icons.people,
                      Colors.blue,
                    ),
                    _buildStatItem(
                      'نشط',
                      _users.where((u) => (u['is_active'] ?? 1) == 1).length.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    _buildStatItem(
                      'معطل',
                      _users.where((u) => (u['is_active'] ?? 0) == 0).length.toString(),
                      Icons.cancel,
                      Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SizedBox(height: 10),

          // قائمة المستخدمين
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey),
                  SizedBox(height: 20),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'لا توجد نتائج للبحث'
                        : 'لا توجد مستخدمين',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  if (!_searchController.text.isNotEmpty)
                    ElevatedButton(
                      onPressed: _showAddUserDialog,
                      child: Text('إضافة أول مستخدم'),
                    ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredUsers.length,
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final isActive = (user['is_active'] ?? 1) == 1;

                String roleName;
                switch (user['role']) {
                  case 'admin': roleName = 'مدير النظام'; break;
                  case 'manager': roleName = 'مدير'; break;
                  case 'warehouse': roleName = 'مخازن'; break;
                  case 'cashier': roleName = 'كاشير'; break;
                  case 'viewer': roleName = 'مشاهد'; break;
                  default: roleName = user['role'] ?? 'غير معروف';
                }

                return Card(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 2,
                  color: isActive ? null : Colors.grey[100],
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive ? AppColors.primary : Colors.grey,
                      child: Text(
                        user['name']?.substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      user['name'] ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isActive ? null : Colors.grey,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${user['username']} - $roleName',
                          style: TextStyle(
                            color: isActive ? Colors.grey : Colors.grey[400],
                          ),
                        ),
                        if (!isActive)
                          Text(
                            '🔴 حساب معطل',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditUserDialog(user);
                        } else if (value == 'delete') {
                          _showDeleteUserConfirmation(user);
                        } else if (value == 'view') {
                          _showUserDetails(user);
                        } else if (value == 'permissions') {
                          _showUserPermissions(user['id'], user['name']);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('عرض التفاصيل'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('تعديل'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'permissions',
                          child: Row(
                            children: [
                              Icon(Icons.security, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('الصلاحيات'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('حذف'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showUserDetails(user),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}