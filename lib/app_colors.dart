import 'package:flutter/material.dart';

/// يحتوي هذا الملف على جميع الألوان المستخدمة في تطبيق إدارة المخزون
/// لضمان اتساق التصميم وتسهيل تعديل اللغة البصرية للتطبيق من مكان واحد.
class AppColors {
  // Private constructor لمنع إنشاء نسخة من الكلاس
  AppColors._();

  // ============ الألوان الأساسية (Primary & Secondary) ============

  /// اللون الأساسي للتطبيق (أزرق احترافي)
  /// يستخدم في الشريط العلوي، الأزرار الرئيسية، والعناوين البارزة.
  static const Color primary = Color(0xFF1565C0);

  /// ظل أفتح من اللون الأساسي
  /// يستخدم للخلفيات التفاعلية والتمييز البسيط.
  static const Color primaryLight = Color(0xFF5e92f3);

  /// ظل أغمق من اللون الأساسي
  /// يستخدم في شريط الحالة (Status Bar) وأماكن أخرى تحتاج للتمييز.
  static const Color primaryDark = Color(0xFF003c8f);

  /// اللون الثانوي (أخضر)
  /// يستخدم للإشارة إلى النجاح، عمليات الحفظ، والأزرار الإيجابية.
  static const Color secondary = Color(0xFF2E7D32);

  /// ظل أفتح من اللون الثانوي
  static const Color secondaryLight = Color(0xFF60ad5e);

  /// ظل أغمق من اللون الثانوي
  static const Color secondaryDark = Color(0xFF005005);

  // ============ ألوان الخلفية والسطح (Background & Surface) ============

  /// لون الخلفية الرئيسية للتطبيق
  /// لون رمادي فاتح مريح للعين.
  static const Color background = Color(0xFFF5F7FA);

  /// لون الأسطح مثل البطاقات (Cards) والحوار (Dialogs)
  /// عادة ما يكون أبيض.
  static const Color surface = Color(0xFFFFFFFF);

  // ============ ألوان النصوص (Text Colors) ============

  /// لون النص الذي يظهر على اللون الأساسي
  /// عادة ما يكون أبيض لضمان التباين.
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// لون النص الذي يظهر على اللون الثانوي
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// لون النص الرئيسي على الخلفيات والأسطح
  /// لون رمادي داكن للقراءة السهلة.
  static const Color onSurface = Color(0xFF212121);

  /// لون العناوين الفرعية والنصوص الأقل أهمية
  static const Color subtitle = Color(0xFF757575);

  /// لون النصائح والحقول الفارغة (Hint Text)
  static const Color hint = Color(0xFF9E9E9E);

  // ============ ألوان الحالات (Status Colors) ============

  /// لون الخطأ (أحمر)
  /// يستخدم في رسائل الخطأ، حقول التحقق الخاطئة.
  static const Color error = Color(0xFFE53935);

  /// لون التحذير (برتقالي)
  /// يستخدم للتنبيهات الهامة التي تحتاج لانتباه المستخدم.
  static const Color warning = Color(0xFFFF9800);

  /// لون المعلومات (أزرق فاتح)
  /// يستخدم في رسائل المعلومات والنصائح.
  static const Color info = Color(0xFF03A9F4);

  // ============ ألوان واجهة المستخدم الأخرى (UI Elements) ============

  /// لون الخطوط الفاصلة (Dividers)
  static const Color divider = Color(0xFFE0E0E0);

  /// لون الحدود (Borders)
  static const Color border = Color(0xFFE0E0E0);

  /// لون الرمادي المحايد (Neutral Grey)
  /// للاستخدامات العامة التي تحتاج لون رمادي.
  static const Color grey = Color(0xFF9E9E9E);

  /// لون الرمادي الداكن
  static const Color darkGrey = Color(0xFF424242);

  // ============ ألوان خاصة بحالات معينة ============

  /// لون النجاح (أخضر زاهي)
  /// يمكن استخدامه بدلاً من اللون الثانوي للإشارة لنجاح عملية بشكل مباشر.
  static const Color success = Color(0xFF4CAF50);

  /// لون الخطر (أحمر زاهي)
  /// يستخدم لحذف العناصر أو الإجراءات الخطيرة.
  static const Color danger = Color(0xFFF44336);

  /// لون المنتج في حالة نفاد المخزون أو المخزون المنخفض
  static const Color lowStock = Color(0xFFFF6F00);

  /// لون المنتج في حالة توفر المخزون
  static const Color inStock = secondary;
}