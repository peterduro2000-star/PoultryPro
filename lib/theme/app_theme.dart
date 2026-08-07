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
  // Semantic colors — warmed/muted to sit inside the earthy palette
  // instead of reading as generic Material red/green/amber/blue.
  static const Color successColor = Color(0xFF6B9B5E); // muted leaf green (kin to sage)
  static const Color warningColor = Color(0xFFD68A34); // burnt amber (kin to gold, distinct from accent)
  static const Color errorColor = Color(0xFFC1443C); // brick red (kin to terracotta)
  static const Color infoColor = Color(0xFF4A7B8C); // muted teal-blue

  /// Centralized stage → color mapping so every screen that shows a
  /// flock's production stage (chick/grower/laying/etc.) uses the same
  /// earthy-palette color instead of scattering raw Colors.blue/green/
  /// orange/grey across FlocksScreen, HomeScreen, etc.
  static Color stageColor(String stage) {
    switch (stage.toLowerCase()) {
      case 'brooding':
      case 'chick':
        return infoColor;
      case 'growing':
      case 'pullet':
      case 'grower':
        return secondaryColor;
      case 'finishing':
      case 'laying':
        return accentColor;
      case 'ready for harvest':
        return primaryColor;
      case 'spent':
        return textSecondary;
      default:
        return textSecondary;
    }
  }

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

  /// Full Material 3 TextTheme built from the same two fonts used
  /// throughout the app (Playfair Display for headings, Inter for body/
  /// label). Plug this into MaterialApp's ThemeData.textTheme instead of
  /// GoogleFonts.poppinsTextTheme() — otherwise every widget that doesn't
  /// explicitly use AppTheme.headingX / bodyX (most notably AppBar titles,
  /// which just do `Text('My Flocks')` with no style) silently falls back
  /// to Poppins, giving the app three unintentional fonts at once.
  static TextTheme get textTheme => TextTheme(
    displayLarge: headingXL,
    displayMedium: headingLarge,
    displaySmall: headingMedium,
    headlineLarge: headingMedium,
    headlineMedium: headingSmall,
    headlineSmall: headingSmall,
    titleLarge: headingSmall,
    titleMedium: bodyLarge.copyWith(fontWeight: FontWeight.w600),
    titleSmall: bodyMedium.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge.copyWith(color: textPrimary),
    labelMedium: labelMedium.copyWith(color: textPrimary),
    labelSmall: bodySmall,
  );

  /// AppBarTheme pinned to the same cream background used as
  /// Scaffold.backgroundColor everywhere, with surfaceTintColor turned
  /// off. Without this, Material 3's ColorScheme.fromSeed gives the
  /// AppBar its own derived surface-tint background that doesn't quite
  /// match AppTheme.backgroundColor, producing a faint seam at the top
  /// of every screen (worse on screens using elevation: 0).
  static AppBarTheme get appBarTheme => AppBarTheme(
    backgroundColor: backgroundColor,
    foregroundColor: textPrimary,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    shadowColor: Colors.black.withOpacity(0.06),
    centerTitle: false,
    titleTextStyle: headingSmall,
    iconTheme: const IconThemeData(color: textPrimary),
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