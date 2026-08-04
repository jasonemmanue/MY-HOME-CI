import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Couleurs principales ──
  static const Color primaryGreen = Color(0xFF2E7D5B);
  static const Color primaryGreenLight = Color(0xFF4CAF7D);
  static const Color primaryGreenDark = Color(0xFF1B5E3B);

  static const Color secondaryOrange = Color(0xFFF5A623);
  static const Color secondaryOrangeLight = Color(0xFFFFBF4A);
  static const Color secondaryOrangeDark = Color(0xFFD4891A);

  // ── Couleurs neutres ──
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardDark = Color(0xFF2C2C2C);

  static const Color textPrimaryLight = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textPrimaryDark = Color(0xFFE8E8E8);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color dividerDark = Color(0xFF374151);

  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);

  // ── Rayons d'arrondi ──
  static const double radiusSmall = 8.0;
  static const double radiusDefault = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  // ── Ombres ──
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];

  // ── Decoration de carte ──
  static BoxDecoration cardDecoration({bool isDark = false}) => BoxDecoration(
        color: isDark ? cardDark : surfaceLight,
        borderRadius: BorderRadius.circular(radiusDefault),
        boxShadow: softShadow,
      );

  // ══════════════════════════════════════════════
  //  THEME CLAIR
  // ══════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        primaryColor: primaryGreen,
        scaffoldBackgroundColor: backgroundLight,
        colorScheme: const ColorScheme.light(
          primary: primaryGreen,
          onPrimary: Colors.white,
          secondary: secondaryOrange,
          onSecondary: Colors.white,
          surface: surfaceLight,
          onSurface: textPrimaryLight,
          error: errorColor,
          onError: Colors.white,
        ),

        // ── AppBar ──
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: textPrimaryLight),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primaryGreen,
          ),
        ),

        // ── Texte ──
        textTheme: _buildTextTheme(isLight: true),

        // ── Carte ──
        cardTheme: CardThemeData(
          color: surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),

        // ── Bouton principal ──
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusDefault),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Bouton texte ──
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryGreen,
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Bouton outline ──
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryGreen,
            side: const BorderSide(color: primaryGreen, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusDefault),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Champ de saisie ──
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundLight,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: dividerLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: dividerLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: primaryGreen, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: errorColor),
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: textSecondaryLight,
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            color: textSecondaryLight,
          ),
        ),

        // ── Bottom Navigation ──
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surfaceLight,
          selectedItemColor: primaryGreen,
          unselectedItemColor: textSecondaryLight,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        ),

        // ── Chip ──
        chipTheme: ChipThemeData(
          backgroundColor: backgroundLight,
          selectedColor: primaryGreen.withValues(alpha: 0.15),
          labelStyle: GoogleFonts.inter(fontSize: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          side: const BorderSide(color: dividerLight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        // ── Divider ──
        dividerTheme: const DividerThemeData(
          color: dividerLight,
          thickness: 1,
          space: 1,
        ),

        // ── FloatingActionButton ──
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
        ),

        // ── TabBar ──
        tabBarTheme: TabBarThemeData(
          labelColor: primaryGreen,
          unselectedLabelColor: textSecondaryLight,
          indicatorColor: primaryGreen,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
        ),
      );

  // ══════════════════════════════════════════════
  //  THEME SOMBRE
  // ══════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryGreen,
        scaffoldBackgroundColor: backgroundDark,
        colorScheme: const ColorScheme.dark(
          primary: primaryGreenLight,
          onPrimary: Colors.black,
          secondary: secondaryOrange,
          onSecondary: Colors.black,
          surface: surfaceDark,
          onSurface: textPrimaryDark,
          error: errorColor,
          onError: Colors.white,
        ),

        // ── AppBar ──
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: textPrimaryDark),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: primaryGreenLight,
          ),
        ),

        // ── Texte ──
        textTheme: _buildTextTheme(isLight: false),

        // ── Carte ──
        cardTheme: CardThemeData(
          color: cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        ),

        // ── Bouton principal ──
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusDefault),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Bouton texte ──
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryGreenLight,
            textStyle: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Bouton outline ──
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryGreenLight,
            side: const BorderSide(color: primaryGreenLight, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusDefault),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // ── Champ de saisie ──
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardDark,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: dividerDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: dividerDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: primaryGreenLight, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
            borderSide: const BorderSide(color: errorColor),
          ),
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: textSecondaryDark,
          ),
          labelStyle: GoogleFonts.inter(
            fontSize: 14,
            color: textSecondaryDark,
          ),
        ),

        // ── Bottom Navigation ──
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surfaceDark,
          selectedItemColor: primaryGreenLight,
          unselectedItemColor: textSecondaryDark,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
        ),

        // ── Chip ──
        chipTheme: ChipThemeData(
          backgroundColor: cardDark,
          selectedColor: primaryGreenLight.withValues(alpha: 0.2),
          labelStyle: GoogleFonts.inter(fontSize: 13, color: textPrimaryDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          side: const BorderSide(color: dividerDark),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),

        // ── Divider ──
        dividerTheme: const DividerThemeData(
          color: dividerDark,
          thickness: 1,
          space: 1,
        ),

        // ── FloatingActionButton ──
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLarge),
          ),
        ),

        // ── TabBar ──
        tabBarTheme: TabBarThemeData(
          labelColor: primaryGreenLight,
          unselectedLabelColor: textSecondaryDark,
          indicatorColor: primaryGreenLight,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
        ),
      );

  // ── Construction du TextTheme ──
  static TextTheme _buildTextTheme({required bool isLight}) {
    final Color primary =
        isLight ? textPrimaryLight : textPrimaryDark;
    final Color secondary =
        isLight ? textSecondaryLight : textSecondaryDark;

    return TextTheme(
      // Titres
      headlineLarge: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: primary,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Sous-titres
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleSmall: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: primary,
      ),
      // Corps de texte
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      // Labels
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: secondary,
      ),
    );
  }
}
