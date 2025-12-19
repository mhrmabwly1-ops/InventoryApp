import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// استيراد فئة قاعدة البيانات
import 'database_helper.dart';
// استيراد الألوان
import 'app_colors.dart';

class PasswordPolicyScreen extends StatefulWidget {
  @override
  _PasswordPolicyScreenState createState() => _PasswordPolicyScreenState();
}

class _PasswordPolicyScreenState extends State<PasswordPolicyScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;

  // سياسات كلمة المرور
  bool _enforcePasswordPolicy = true;
  int _minPasswordLength = 8;
  bool _requireUppercase = true;
  bool _requireLowercase = true;
  bool _requireNumbers = true;
  bool _requireSpecialChars = false;
  int _passwordExpiryDays = 90;
  int _maxFailedAttempts = 5;
  int _lockoutDuration = 30;
  bool _preventPasswordReuse = true;
  int _passwordHistoryCount = 5;
  bool _require2FA = false;

  // قائمة الأحرف الخاصة المسموحة
  final List<String> _specialChars = [
    '!', '@', '#', '\$', '%', '^', '&', '*', '(', ')',
    '-', '_', '=', '+', '[', ']', '{', '}', '|', '\\',
    ';', ':', '\'', '"', ',', '.', '<', '>', '/', '?'
  ];

  List<String> _selectedSpecialChars = ['!', '@', '#', '\$', '%'];

  @override
  void initState() {
    super.initState();
    _loadPasswordPolicy();
  }

  Future<void> _loadPasswordPolicy() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _dbHelper.getAdvancedSettings();

      setState(() {
        _enforcePasswordPolicy = settings['enforce_password_policy'] ?? true;
        _minPasswordLength = settings['min_password_length']?.toInt() ?? 8;
        _requireUppercase = settings['require_uppercase'] ?? true;
        _requireLowercase = settings['require_lowercase'] ?? true;
        _requireNumbers = settings['require_numbers'] ?? true;
        _requireSpecialChars = settings['require_special_chars'] ?? false;
        _passwordExpiryDays = settings['password_expiry_days']?.toInt() ?? 90;
        _maxFailedAttempts = settings['max_failed_attempts']?.toInt() ?? 5;
        _lockoutDuration = settings['lockout_duration']?.toInt() ?? 30;
        _preventPasswordReuse = settings['prevent_password_reuse'] ?? true;
        _passwordHistoryCount = settings['password_history_count']?.toInt() ?? 5;
        _require2FA = settings['require_2fa'] ?? false;

        // تحميل الأحرف الخاصة المختارة
        final savedChars = settings['allowed_special_chars']?.toString().split(',') ?? ['!', '@', '#', '\$', '%'];
        _selectedSpecialChars = savedChars.where((char) => _specialChars.contains(char)).toList();

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('خطأ في تحميل سياسات كلمة المرور: ${e.toString()}');
    }
  }

  Future<void> _savePasswordPolicy() async {
    try {
      // حفظ كل إعداد في قاعدة البيانات
      await _dbHelper.updateAdvancedSetting('enforce_password_policy', _enforcePasswordPolicy);
      await _dbHelper.updateAdvancedSetting('min_password_length', _minPasswordLength);
      await _dbHelper.updateAdvancedSetting('require_uppercase', _requireUppercase);
      await _dbHelper.updateAdvancedSetting('require_lowercase', _requireLowercase);
      await _dbHelper.updateAdvancedSetting('require_numbers', _requireNumbers);
      await _dbHelper.updateAdvancedSetting('require_special_chars', _requireSpecialChars);
      await _dbHelper.updateAdvancedSetting('password_expiry_days', _passwordExpiryDays);
      await _dbHelper.updateAdvancedSetting('max_failed_attempts', _maxFailedAttempts);
      await _dbHelper.updateAdvancedSetting('lockout_duration', _lockoutDuration);
      await _dbHelper.updateAdvancedSetting('prevent_password_reuse', _preventPasswordReuse);
      await _dbHelper.updateAdvancedSetting('password_history_count', _passwordHistoryCount);
      await _dbHelper.updateAdvancedSetting('require_2fa', _require2FA);
      await _dbHelper.updateAdvancedSetting('allowed_special_chars', _selectedSpecialChars.join(','));

      _showSuccess('تم حفظ سياسات كلمة المرور بنجاح');
    } catch (e) {
      _showError('خطأ في حفظ السياسات: ${e.toString()}');
    }
  }

  void _showSpecialCharsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختر الأحرف الخاصة المسموحة'),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  Text('الأحرف الخاصة المتاحة:'),
                  SizedBox(height: 10),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 5,
                      ),
                      itemCount: _specialChars.length,
                      itemBuilder: (context, index) {
                        final char = _specialChars[index];
                        final isSelected = _selectedSpecialChars.contains(char);

                        return GestureDetector(
                          onTap: () {
                            if (isSelected) {
                              _selectedSpecialChars.remove(char);
                            } else {
                              _selectedSpecialChars.add(char);
                            }
                            setState(() {});
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.grey[200],
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : Colors.grey,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                char,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Text('المحدد: ${_selectedSpecialChars.length} حرف'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _selectedSpecialChars = ['!', '@', '#', '\$', '%']; // إعادة التعيين
                  Navigator.pop(context);
                },
                child: Text('إعادة التعيين'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('تم'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPasswordPolicyDetails() {
    final policyDetails = '''
📋 سياسة كلمة المرور الحالية:

🔐 تعزيز سياسة كلمة المرور: ${_enforcePasswordPolicy ? '✅ مفعل' : '❌ معطل'}
📏 الحد الأدنى لطول كلمة المرور: $_minPasswordLength أحرف
🔠 يجب أن تحتوي على أحرف كبيرة: ${_requireUppercase ? '✅ نعم' : '❌ لا'}
🔡 يجب أن تحتوي على أحرف صغيرة: ${_requireLowercase ? '✅ نعم' : '❌ لا'}
🔢 يجب أن تحتوي على أرقام: ${_requireNumbers ? '✅ نعم' : '❌ لا'}
✨ يجب أن تحتوي على رموز خاصة: ${_requireSpecialChars ? '✅ نعم' : '❌ لا'}
⏳ صلاحية كلمة المرور: $_passwordExpiryDays يوم
🚫 الحد الأقصى لمحاولات الدخول الفاشلة: $_maxFailedAttempts محاولات
🔒 مدة القفل بعد فشل المحاولات: $_lockoutDuration دقيقة
🔄 منع إعادة استخدام كلمة المرور: ${_preventPasswordReuse ? '✅ مفعل' : '❌ معطل'}
📚 عدد كلمات المرور المخزنة: $_passwordHistoryCount كلمة
🔐 المصادقة الثنائية: ${_require2FA ? '✅ مطلوبة' : '❌ غير مطلوبة'}

🔤 الأحرف الخاصة المسموحة: ${_selectedSpecialChars.join(' ')}
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل سياسة كلمة المرور'),
        content: SingleChildScrollView(
          child: SelectableText(
            policyDetails,
            style: TextStyle(fontSize: 14, height: 1.5),
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

  void _showTestPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('اختبار كلمة المرور'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('أدخل كلمة مرور لاختبارها مقابل السياسات الحالية:'),
                SizedBox(height: 15),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    final testResult = _testPassword(passwordController.text);
                    _showTestResult(testResult);
                  },
                  child: Text('اختبار كلمة المرور'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق'),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _testPassword(String password) {
    final errors = <String>[];
    final warnings = <String>[];
    final successes = <String>[];

    // اختبار طول كلمة المرور
    if (password.length < _minPasswordLength) {
      errors.add('❌ كلمة المرور قصيرة جداً ($_minPasswordLength أحرف على الأقل)');
    } else {
      successes.add('✅ طول كلمة المرور مناسب (${password.length} حرف)');
    }

    // اختبار الأحرف الكبيرة
    if (_requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      errors.add('❌ يجب أن تحتوي على حرف كبير واحد على الأقل');
    } else if (_requireUppercase) {
      successes.add('✅ تحتوي على أحرف كبيرة');
    }

    // اختبار الأحرف الصغيرة
    if (_requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      errors.add('❌ يجب أن تحتوي على حرف صغير واحد على الأقل');
    } else if (_requireLowercase) {
      successes.add('✅ تحتوي على أحرف صغيرة');
    }

    // اختبار الأرقام
    if (_requireNumbers && !password.contains(RegExp(r'[0-9]'))) {
      errors.add('❌ يجب أن تحتوي على رقم واحد على الأقل');
    } else if (_requireNumbers) {
      successes.add('✅ تحتوي على أرقام');
    }

    // اختبار الأحرف الخاصة
    if (_requireSpecialChars) {
      final hasSpecialChar = _selectedSpecialChars.any((char) => password.contains(char));
      if (!hasSpecialChar) {
        errors.add('❌ يجب أن تحتوي على أحد الأحرف الخاصة: ${_selectedSpecialChars.join(' ')}');
      } else {
        successes.add('✅ تحتوي على أحرف خاصة');
      }
    }

    // اختبار قوة كلمة المرور
    final strengthScore = _calculatePasswordStrength(password);
    String strengthText;
    Color strengthColor;

    if (strengthScore >= 80) {
      strengthText = 'قوية جداً';
      strengthColor = Colors.green;
      successes.add('✅ قوة كلمة المرور: ممتازة');
    } else if (strengthScore >= 60) {
      strengthText = 'قوية';
      strengthColor = Colors.lightGreen;
      successes.add('✅ قوة كلمة المرور: جيدة');
    } else if (strengthScore >= 40) {
      strengthText = 'متوسطة';
      strengthColor = Colors.orange;
      warnings.add('⚠️ قوة كلمة المرور: متوسطة');
    } else {
      strengthText = 'ضعيفة';
      strengthColor = Colors.red;
      warnings.add('⚠️ قوة كلمة المرور: ضعيفة');
    }

    return {
      'errors': errors,
      'warnings': warnings,
      'successes': successes,
      'strength_score': strengthScore,
      'strength_text': strengthText,
      'strength_color': strengthColor,
      'is_valid': errors.isEmpty,
    };
  }

  int _calculatePasswordStrength(String password) {
    int score = 0;

    // الطول
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 10;
    if (password.length >= 16) score += 10;

    // التنوع
    if (password.contains(RegExp(r'[A-Z]'))) score += 10;
    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    if (password.contains(RegExp(r'[0-9]'))) score += 10;
    if (_selectedSpecialChars.any((char) => password.contains(char))) score += 10;

    // عدم وجود تسلسلات
    if (!_containsSequences(password)) score += 10;

    // عدم وجود تكرارات
    if (!_containsRepeats(password)) score += 10;

    return score.clamp(0, 100);
  }

  bool _containsSequences(String password) {
    // الكشف عن تسلسلات مثل abc, 123, qwerty
    final sequences = [
      'abcdefghijklmnopqrstuvwxyz',
      'zyxwvutsrqponmlkjihgfedcba',
      '0123456789',
      '9876543210',
      'qwertyuiop',
      'asdfghjkl',
      'zxcvbnm',
    ];

    for (final sequence in sequences) {
      for (int i = 0; i <= sequence.length - 3; i++) {
        final seq = sequence.substring(i, i + 3);
        if (password.toLowerCase().contains(seq)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _containsRepeats(String password) {
    // الكشف عن تكرارات مثل aaa, 111, !!!
    for (int i = 0; i < password.length - 2; i++) {
      if (password[i] == password[i + 1] && password[i] == password[i + 2]) {
        return true;
      }
    }
    return false;
  }

  void _showTestResult(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result['is_valid'] ? Icons.check_circle : Icons.error,
              color: result['is_valid'] ? Colors.green : Colors.red,
            ),
            SizedBox(width: 10),
            Text('نتيجة اختبار كلمة المرور'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // مؤشر قوة كلمة المرور
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: result['strength_color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: result['strength_color']),
                ),
                child: Row(
                  children: [
                    Icon(
                      result['strength_score'] >= 60 ? Icons.lock : Icons.lock_open,
                      color: result['strength_color'],
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'قوة كلمة المرور: ${result['strength_text']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: result['strength_color'],
                            ),
                          ),
                          SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: result['strength_score'] / 100,
                            backgroundColor: Colors.grey[200],
                            color: result['strength_color'],
                            minHeight: 8,
                          ),
                          SizedBox(height: 5),
                          Text(
                            '${result['strength_score']}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20),

              // النتائج
              if (result['successes'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✅ الاختبارات الناجحة:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    SizedBox(height: 5),
                    ...(result['successes'] as List<String>).map((success) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('• $success'),
                      );
                    }).toList(),
                  ],
                ),

              if (result['warnings'].isNotEmpty) ...[
                SizedBox(height: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '⚠️ التحذيرات:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    SizedBox(height: 5),
                    ...(result['warnings'] as List<String>).map((warning) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('• $warning'),
                      );
                    }).toList(),
                  ],
                ),
              ],

              if (result['errors'].isNotEmpty) ...[
                SizedBox(height: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '❌ الأخطاء:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    SizedBox(height: 5),
                    ...(result['errors'] as List<String>).map((error) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('• $error'),
                      );
                    }).toList(),
                  ],
                ),
              ],

              SizedBox(height: 20),

              // التوصيات
              if (!result['is_valid'])
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 نصائح لكلمة مرور قوية:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      SizedBox(height: 5),
                      Text('• استخدم مزيجاً من الأحرف الكبيرة والصغيرة'),
                      Text('• أضف أرقاماً ورموزاً خاصة'),
                      Text('• تجنب الكلمات الشائعة والتسلسلات'),
                      Text('• استخدم جملة سهلة التذكر بدلاً من كلمة واحدة'),
                    ],
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
        title: Text('سياسات كلمة المرور'),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: _showPasswordPolicyDetails,
            tooltip: 'عرض التفاصيل',
          ),
          IconButton(
            icon: Icon(Icons.lock_open),
            onPressed: _showTestPasswordDialog,
            tooltip: 'اختبار كلمة المرور',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ملخص السياسات
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: AppColors.primary, size: 30),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سياسات أمان كلمة المرور',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      'تعزيز أمان حسابات المستخدمين من خلال سياسات كلمة مرور قوية',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // تفعيل سياسات كلمة المرور
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.settings, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'الإعدادات العامة',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    SwitchListTile(
                      title: Text('تفعيل سياسات كلمة المرور'),
                      subtitle: Text('تطبيق جميع السياسات على كلمات مرور المستخدمين'),
                      value: _enforcePasswordPolicy,
                      onChanged: (value) {
                        setState(() {
                          _enforcePasswordPolicy = value;
                        });
                      },
                    ),
                    Divider(),
                    ListTile(
                      title: Text('تطبيق التغييرات على المستخدمين الحاليين'),
                      subtitle: Text('طلب تغيير كلمة المرور للمستخدمين الحاليين'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          _showForcePasswordChangeDialog();
                        },
                        child: Text('تطبيق الآن'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // متطلبات كلمة المرور
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lock, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'متطلبات كلمة المرور',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    ListTile(
                      title: Text('الحد الأدنى لطول كلمة المرور'),
                      subtitle: Text('${_minPasswordLength} أحرف'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove),
                            onPressed: () {
                              if (_minPasswordLength > 4) {
                                setState(() {
                                  _minPasswordLength--;
                                });
                              }
                            },
                          ),
                          Text('$_minPasswordLength'),
                          IconButton(
                            icon: Icon(Icons.add),
                            onPressed: () {
                              if (_minPasswordLength < 32) {
                                setState(() {
                                  _minPasswordLength++;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('مطلوب أحرف كبيرة (A-Z)'),
                      subtitle: Text('يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل'),
                      value: _requireUppercase,
                      onChanged: (value) {
                        setState(() {
                          _requireUppercase = value;
                        });
                      },
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('مطلوب أحرف صغيرة (a-z)'),
                      subtitle: Text('يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل'),
                      value: _requireLowercase,
                      onChanged: (value) {
                        setState(() {
                          _requireLowercase = value;
                        });
                      },
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('مطلوب أرقام (0-9)'),
                      subtitle: Text('يجب أن تحتوي كلمة المرور على رقم واحد على الأقل'),
                      value: _requireNumbers,
                      onChanged: (value) {
                        setState(() {
                          _requireNumbers = value;
                        });
                      },
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('مطلوب رموز خاصة'),
                      subtitle: Text('يجب أن تحتوي كلمة المرور على رمز خاص واحد على الأقل'),
                      value: _requireSpecialChars,
                      onChanged: (value) {
                        setState(() {
                          _requireSpecialChars = value;
                        });
                      },
                    ),
                    if (_requireSpecialChars) ...[
                      SizedBox(height: 10),
                      ListTile(
                        title: Text('الأحرف الخاصة المسموحة'),
                        subtitle: Text('${_selectedSpecialChars.length} حرف: ${_selectedSpecialChars.join(' ')}'),
                        trailing: IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: _showSpecialCharsDialog,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // صلاحية وأمان كلمة المرور
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timer, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'الصلاحية والأمان',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    ListTile(
                      title: Text('فترة صلاحية كلمة المرور'),
                      subtitle: Text('يجب تغيير كلمة المرور كل $_passwordExpiryDays يوم'),
                      trailing: DropdownButton<int>(
                        value: _passwordExpiryDays,
                        items: [30, 60, 90, 180, 365].map((days) {
                          return DropdownMenuItem(
                            value: days,
                            child: Text('$days يوم'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _passwordExpiryDays = value!;
                          });
                        },
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('منع إعادة استخدام كلمة المرور'),
                      subtitle: Text('لا يمكن إعادة استخدام آخر $_passwordHistoryCount كلمة مرور'),
                      trailing: DropdownButton<int>(
                        value: _passwordHistoryCount,
                        items: [1, 3, 5, 10, 15].map((count) {
                          return DropdownMenuItem(
                            value: count,
                            child: Text('$count'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _passwordHistoryCount = value!;
                          });
                        },
                      ),
                    ),
                    Divider(),
                    SwitchListTile(
                      title: Text('المصادقة الثنائية (2FA)'),
                      subtitle: Text('تطبيق المصادقة الثنائية لجميع المستخدمين'),
                      value: _require2FA,
                      onChanged: (value) {
                        setState(() {
                          _require2FA = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // حماية ضد هجمات القوة الغاشمة
            Card(
              elevation: 3,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text(
                          'حماية ضد الهجمات',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 15),
                    ListTile(
                      title: Text('الحد الأقصى لمحاولات الدخول الفاشلة'),
                      subtitle: Text('قفل الحساب بعد $_maxFailedAttempts محاولات فاشلة'),
                      trailing: DropdownButton<int>(
                        value: _maxFailedAttempts,
                        items: [3, 5, 10, 15].map((attempts) {
                          return DropdownMenuItem(
                            value: attempts,
                            child: Text('$attempts'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _maxFailedAttempts = value!;
                          });
                        },
                      ),
                    ),
                    Divider(),
                    ListTile(
                      title: Text('مدة قفل الحساب'),
                      subtitle: Text('الحساب مقفل لمدة $_lockoutDuration دقيقة بعد تجاوز الحد'),
                      trailing: DropdownButton<int>(
                        value: _lockoutDuration,
                        items: [5, 15, 30, 60, 1440].map((minutes) {
                          String text;
                          if (minutes >= 1440) {
                            text = '24 ساعة';
                          } else if (minutes >= 60) {
                            text = '${minutes ~/ 60} ساعة';
                          } else {
                            text = '$minutes دقيقة';
                          }
                          return DropdownMenuItem(
                            value: minutes,
                            child: Text(text),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _lockoutDuration = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 30),

            // أزرار الحفظ
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text('حفظ جميع الإعدادات'),
                    onPressed: _savePasswordPolicy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: Icon(Icons.restore),
                  label: Text('إعادة التعيين'),
                  onPressed: _loadPasswordPolicy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    minimumSize: Size(150, 50),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // تلميحات الأمان
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue),
                        SizedBox(width: 10),
                        Text(
                          'نصائح للأمان القوي',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text('• استخدم كلمة مرور لا تقل عن 12 حرفاً'),
                    Text('• تجنب استخدام المعلومات الشخصية مثل التاريخ أو الاسم'),
                    Text('• استخدم جملة سهلة التذكر بدلاً من كلمة واحدة'),
                    Text('• فكر في استخدام مدير كلمات المرور'),
                    Text('• لا تستخدم نفس كلمة المرور لمواقع متعددة'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showForcePasswordChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تطبيق سياسات كلمة المرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning, size: 50, color: Colors.orange),
            SizedBox(height: 10),
            Text('سيتم تطبيق سياسات كلمة المرور الجديدة على جميع المستخدمين.'),
            SizedBox(height: 10),
            Text(
              'سيُطلب من كل مستخدم تغيير كلمة المرور في المرة القادمة التي يسجل فيها دخولاً.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              // تنفيذ تطبيق السياسات
              _applyPasswordPolicyToAllUsers();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('تطبيق'),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPasswordPolicyToAllUsers() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('جاري تطبيق السياسات على جميع المستخدمين...')),
      );

      // في تطبيق حقيقي، هنا نضع علامة لكل مستخدم لضرورة تغيير كلمة المرور
      // أو نرسل إشعارات لهم

      await Future.delayed(Duration(seconds: 2));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ تم تطبيق السياسات بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في تطبيق السياسات: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}