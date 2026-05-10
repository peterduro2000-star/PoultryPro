import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors - Earthy Pragmatism Design
  static const Color primaryColor = Color(0xFFC85A3A); // Terracotta
  static const Color secondaryColor = Color(0xFF6B8E6F); // Sage Green
  static const Color accentColor = Color(0xFFD4AF37); // Gold
  static const Color backgroundColor = Color(0xFFF5F1E8); // Cream
  static const Color textPrimary = Color(0xFF2C2C2C); // Charcoal
  static const Color textSecondary = Color(0xFF6B6B6B); // Gray
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFF44336);
  static const Color infoColor = Color(0xFF2196F3);

  // Text Styles
  static TextStyle headingXL = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static TextStyle headingLarge = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static TextStyle headingMedium = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle headingSmall = GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textPrimary,
  );

  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
  );

  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Spacing
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 16;
  static const double spacingLG = 24;
  static const double spacingXL = 32;

  // Border Radius
  static const double radiusSM = 8;
  static const double radiusMD = 12;
  static const double radiusLG = 16;

  // Shadows
  static const BoxShadow shadowSM = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  static const BoxShadow shadowMD = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  static const BoxShadow shadowLG = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 16,
    offset: Offset(0, 8),
  );

  // Button Styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLG,
      vertical: spacingMD,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
    elevation: 2,
  );

  static ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor, width: 2),
    padding: const EdgeInsets.symmetric(
      horizontal: spacingLG,
      vertical: spacingMD,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusMD),
    ),
  );

  // Card Style
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radiusMD),
    boxShadow: const [shadowMD],
  );

  // Input Decoration
  static InputDecoration inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMD,
          vertical: spacingMD,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
      );
}
