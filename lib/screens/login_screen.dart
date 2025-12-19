// import 'package:flutter/material.dart';
// import 'package:projectstor/screens/permission_service.dart';
//
// import '../dashboard_screen.dart';
// import '../database_helper.dart';
//
//
// class LoginScreen extends StatefulWidget {
//   @override
//   _LoginScreenState createState() => _LoginScreenState();
// }
//
// class _LoginScreenState extends State<LoginScreen> {
//   final DatabaseHelper _dbHelper = DatabaseHelper();
//   final PermissionService _permissionService = PermissionService();
//   final _usernameController = TextEditingController();
//   final _passwordController = TextEditingController();
//   bool _isLoading = false;
//   bool _obscurePassword = true;
//
//   Future<void> _login() async {
//     if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
//       _showError('يرجى إدخال اسم المستخدم وكلمة المرور');
//       return;
//     }
//
//     setState(() => _isLoading = true);
//
//     try {
//       final db = await _dbHelper.database;
//       final users = await db.query(
//         'users',
//         where: 'username = ? AND password = ? AND is_active = 1',
//         whereArgs: [_usernameController.text, _passwordController.text],
//       );
//
//       if (users.isNotEmpty) {
//         final user = users.first;
//         _permissionService.setUserPermissions(user['role'] as String);
//
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (_) => DashboardScreen(
//               username: user['name'] as String,
//               role: user['role'] as String,
//             ),
//           ),
//         );
//
//         // تحديث آخر وقت دخول
//         await db.update(
//           'users',
//           {'last_login': DateTime.now().toIso8601String()},
//           where: 'id = ?',
//           whereArgs: [user['id']],
//         );
//       } else {
//         _showError('اسم المستخدم أو كلمة المرور غير صحيحة');
//       }
//     } catch (e) {
//       _showError('حدث خطأ أثناء تسجيل الدخول: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       body: Center(
//         child: SingleChildScrollView(
//           padding: EdgeInsets.all(24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // شعار التطبيق
//               Container(
//                 padding: EdgeInsets.all(20),
//                 decoration: BoxDecoration(
//                   color: Colors.deepPurple,
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   Icons.inventory_2,
//                   color: Colors.white,
//                   size: 50,
//                 ),
//               ),
//               SizedBox(height: 30),
//
//               Text(
//                 'نظام إدارة المخزون',
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.deepPurple,
//                 ),
//               ),
//               SizedBox(height: 8),
//               Text(
//                 'سجل الدخول إلى حسابك',
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: Colors.grey[600],
//                 ),
//               ),
//               SizedBox(height: 40),
//
//               // حقل اسم المستخدم
//               TextFormField(
//                 controller: _usernameController,
//                 decoration: InputDecoration(
//                   labelText: 'اسم المستخدم',
//                   prefixIcon: Icon(Icons.person),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 20),
//
//               // حقل كلمة المرور
//               TextFormField(
//                 controller: _passwordController,
//                 obscureText: _obscurePassword,
//                 decoration: InputDecoration(
//                   labelText: 'كلمة المرور',
//                   prefixIcon: Icon(Icons.lock),
//                   suffixIcon: IconButton(
//                     icon: Icon(
//                       _obscurePassword ? Icons.visibility : Icons.visibility_off,
//                     ),
//                     onPressed: () {
//                       setState(() => _obscurePassword = !_obscurePassword);
//                     },
//                   ),
//                   border: OutlineInputBorder(
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 30),
//
//               // زر تسجيل الدخول
//               Container(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   onPressed: _isLoading ? null : _login,
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.deepPurple,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                   child: _isLoading
//                       ? CircularProgressIndicator(color: Colors.white)
//                       : Text(
//                     'تسجيل الدخول',
//                     style: TextStyle(fontSize: 16),
//                   ),
//                 ),
//               ),
//               SizedBox(height: 20),
//
//               // معلومات إضافية
//               Text(
//                 'نسخة النظام: 1.0.0',
//                 style: TextStyle(
//                   color: Colors.grey[500],
//                   fontSize: 12,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }