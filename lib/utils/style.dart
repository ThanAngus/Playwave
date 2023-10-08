import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppColors {
  static const Color black = Color(0xFF031111);
  static const Color grey = Color(0xFF333333);
  static const Color white = Color(0xFFFDFEFF);
  static const Color errorColor = Color(0xFFBE0028);
  static const Color primary = Color(0xFFB6BFB2);
  static const Color accent = Color(0XFFFF7F50);
  static const MaterialColor primarySwatch = MaterialColor(
    0xFFB6BFB2,
    <int, Color>{
      50: Color(0xFFFAFAF9),
      100: Color(0xFFF0F1EF),
      200: Color(0xFFE3E5E2),
      300: Color(0xFFD5D8D5),
      400: Color(0xFFCACDCA),
      500: Color(0xFFB6BFB2), // Hex color #B6BFB2 (500 shade)
      600: Color(0xFFA2AA9E),
      700: Color(0xFF8E9689),
      800: Color(0xFF7A826E),
      900: Color(0xFF646C57),
    },
  );
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

final ThemeData appTheme = ThemeData(
  primaryColor: AppColors.primary,
  useMaterial3: true,
  dividerColor: AppColors.white.withOpacity(0.6),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Brand-Head',
      fontWeight: FontWeight.w600,
    ),
    displayMedium: TextStyle(
      fontFamily: 'Brand-Head',
      fontWeight: FontWeight.w600,
    ),
    displaySmall: TextStyle(
      fontFamily: 'Brand-Head',
      fontWeight: FontWeight.w600,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'Brand-Head',
    ),
    headlineMedium: TextStyle(
      fontFamily: 'Product-Regular',
    ),
    headlineSmall: TextStyle(
      fontFamily: 'Product-Regular',
    ),
    titleMedium: TextStyle(
      fontFamily: 'Product-Regular',
    ),
    titleLarge: TextStyle(
      fontFamily: 'Product-Regular',
    ),
    titleSmall: TextStyle(
      fontFamily: 'Product-Regular',
    ),
  ).apply(
    bodyColor: AppColors.white,
    displayColor: AppColors.white,
  ),
  visualDensity: VisualDensity.adaptivePlatformDensity,
  scaffoldBackgroundColor: AppColors.black,
  colorScheme: ColorScheme.fromSwatch(
    primarySwatch: AppColors.primarySwatch,
  ).copyWith(
    secondary: AppColors.accent,
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.black,
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
    ),
    titleTextStyle: TextStyle(
      fontSize: ScreenUtil().setSp(25),
      fontFamily: 'Product-Regular',
    ),
  ),
);
