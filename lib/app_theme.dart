import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFFFFFFFF);
  static const text = Color(0xFF151515);
  static const textSoft = Color(0xFF586472);
  static const line = Color(0xFFE8EBEF);
  static const shadow = Color(0x16000000);

  static const pastelGreen = Color(0xFFD9EEB8);
  static const pastelBlue = Color(0xFFAEE9FB);
  static const pastelYellow = Color.fromARGB(255, 254, 231, 127);
  static const pastelGrey = Color(0xFFF5F5F0);
  static const pastelRed = Color(0xFFFFDDD8);
  static const softOrange = Color(0xFFFFEAC7);
  static const ivory = Color(0xFFFCFCFA);
  static const mintStroke = Color(0xFFC2E198);
  static const blueInk = Color(0xFF234E66);
  static const greenInk = Color(0xFF244E31);
  static const glowBlue = Color(0x5539C6F4);
  static const glowGreen = Color(0x554BC76C);
  static const glowYellow = Color(0x55FFC93D);
  static const glowDark = Color(0x22000000);

  static const navSelected = Color(0xFF151515);
  static const navUnselected = Color(0xFFF1F2F4);
  static const orangeDot = Color(0xFFFF8A4D);
}

class AppText {
  AppText._();

  static TextTheme theme() => GoogleFonts.plusJakartaSansTextTheme().copyWith(
    headlineLarge: GoogleFonts.plusJakartaSans(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      height: 1.02,
      color: AppColors.text,
    ),
    headlineMedium: GoogleFonts.plusJakartaSans(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    titleLarge: GoogleFonts.plusJakartaSans(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    titleMedium: GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: AppColors.text,
    ),
    bodyLarge: GoogleFonts.plusJakartaSans(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AppColors.textSoft,
      height: 1.35,
    ),
    bodyMedium: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSoft,
    ),
    labelLarge: GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.text,
    ),
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: AppText.theme(),
    colorScheme: const ColorScheme.light(
      primary: AppColors.text,
      secondary: AppColors.pastelBlue,
      surface: AppColors.background,
    ),
  );
}

class AppLayout {
  AppLayout._();

  static const double maxContentWidth = 390;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 20);
}

BoxDecoration softCardDecoration(
  Color color, {
  double radius = 32,
  List<BoxShadow>? shadows,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow:
        shadows ??
        const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            spreadRadius: 1,
            offset: Offset(0, 10),
          ),
        ],
  );
}
