import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VergeTheme {
  // Brand Hazards
  static const jellyMint = Color(0xFF3CFFD0);
  static const ultraviolet = Color(0xFF5200FF);
  
  // Secondary & Accent
  static const consoleMintBorder = Color(0xFF309875);
  static const deepLinkBlue = Color(0xFF3860BE);
  static const focusCyan = Color(0xFF1EAEDB);
  static const purpleRule = Color(0xFF3D00BF);

  // Surface & Background
  static const canvasBlack = Color(0xFF131313);
  static const surfaceSlate = Color(0xFF2D2D2D);
  static const imageFrame = Color(0xFF313131);
  static const hazardWhite = Color(0xFFFFFFFF);
  static const absoluteBlack = Color(0xFF000000);

  // Neutrals & Text
  static const primaryText = hazardWhite;
  static const secondaryText = Color(0xFF949494);
  static const mutedText = Color(0xFFE9E9E9);
  static const invertedText = canvasBlack;
  static const dimGray = Color(0xFF8C8C8C);

  // Text Styles based on The Verge typography rules
  static TextStyle get heroDisplay => GoogleFonts.oswald(
    fontSize: 107,
    fontWeight: FontWeight.w900,
    height: 0.95, // Increased slightly from 0.80 due to Oswald's metrics
    letterSpacing: 1.07,
    color: primaryText,
  );

  static TextStyle get secondaryDisplay => GoogleFonts.oswald(
    fontSize: 90,
    fontWeight: FontWeight.w900,
    height: 0.95,
    color: primaryText,
  );

  static TextStyle get tertiaryDisplay => GoogleFonts.oswald(
    fontSize: 60,
    fontWeight: FontWeight.w900,
    height: 0.95,
    color: primaryText,
  );

  static TextStyle get largeHeadline => GoogleFonts.spaceGrotesk(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: primaryText,
  );

  static TextStyle get headingMedium => GoogleFonts.spaceGrotesk(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: primaryText,
  );

  static TextStyle get headingSmall => GoogleFonts.spaceGrotesk(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.0,
    color: primaryText,
  );

  static TextStyle get lightCapitalizedLabel => GoogleFonts.spaceGrotesk(
    fontSize: 19,
    fontWeight: FontWeight.w300,
    height: 1.20,
    letterSpacing: 1.9,
    color: primaryText,
  );

  static TextStyle get allCapsLabelXL => GoogleFonts.spaceGrotesk(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.10,
    letterSpacing: 1.8,
    color: primaryText,
  );

  static TextStyle get bodyRelaxed => GoogleFonts.spaceGrotesk(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.60,
    color: primaryText,
  );

  static TextStyle get inlineLabel => GoogleFonts.spaceGrotesk(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.20,
    letterSpacing: 0.15,
    color: primaryText,
  );

  static TextStyle get eyebrowAllCaps => GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.30,
    letterSpacing: 1.8,
    color: primaryText,
  );

  static TextStyle get tagLabel => GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.20,
    letterSpacing: 0.72,
    color: primaryText,
  );

  static TextStyle get monoButtonLabel => GoogleFonts.spaceMono(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 2.0,
    letterSpacing: 1.5,
  );

  static TextStyle get monoTimestamp => GoogleFonts.spaceMono(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.20,
    letterSpacing: 1.1,
    color: secondaryText,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: canvasBlack,
      cardColor: surfaceSlate,
      colorScheme: const ColorScheme.dark(
        primary: jellyMint,
        secondary: ultraviolet,
        surface: canvasBlack,
        error: ultraviolet, // As per guidelines, ultraviolet is used for error
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: canvasBlack,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceSlate,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceSlate,
        contentTextStyle: bodyRelaxed.copyWith(color: hazardWhite),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: canvasBlack,
        elevation: 0,
        selectedItemColor: jellyMint,
        unselectedItemColor: secondaryText,
        selectedLabelStyle: monoButtonLabel.copyWith(fontSize: 10, letterSpacing: 0.5),
        unselectedLabelStyle: monoButtonLabel.copyWith(fontSize: 10, letterSpacing: 0.5),
      ),
      textTheme: TextTheme(
        displayLarge: heroDisplay,
        displayMedium: secondaryDisplay,
        displaySmall: tertiaryDisplay,
        headlineLarge: largeHeadline,
        headlineMedium: headingMedium,
        headlineSmall: headingSmall,
        bodyLarge: bodyRelaxed,
        bodyMedium: bodyRelaxed.copyWith(fontSize: 14),
        labelLarge: monoButtonLabel,
      ),
    );
  }
}
