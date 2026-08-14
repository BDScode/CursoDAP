import 'package:app_curso_aldo_parisot/screens/calendario_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const CursoBqtoApp());
}

class CursoBqtoApp extends StatelessWidget {
  const CursoBqtoApp({super.key});

  // Brand Colors
  static const Color primaryBlue = Color(0xFF1A367B);
  static const Color primaryMaroon = Color(0xFF872648);
  static const Color secondaryOrange = Color(0xFFE6843D);
  static const Color secondaryPurple = Color(0xFF381E46);
  static const Color accentGold = Color(0xFFCB9112);
  static const Color textColor = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Curso violonchelo Duo Aldo Parisot',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(
          0xFF0F1219,
        ), // Much darker, sober background
        cardColor: const Color(0xFF1C222D), // Subtle dark bluish-grey for cards
        colorScheme: ColorScheme.dark(
          primary:
              primaryBlue, // Shifted primary to the Blue for a more sober look
          onPrimary: textColor,
          secondary: primaryMaroon, // Maroon as secondary accent
          onSecondary: textColor,
          tertiary: accentGold,
          onTertiary: textColor,
          surface: const Color(0xFF161A22),
          onSurface: textColor,
          surfaceContainerHighest: const Color(0xFF1C222D),
        ),
        textTheme:
            GoogleFonts.aliceTextTheme(
              ThemeData.dark().textTheme.apply(
                bodyColor: textColor,
                displayColor: textColor,
              ),
            ).copyWith(
              displayLarge: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              displayMedium: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              displaySmall: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              headlineLarge: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              headlineMedium: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              headlineSmall: GoogleFonts.cinzel(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              titleLarge: GoogleFonts.cinzel(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              titleMedium: GoogleFonts.cinzel(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              titleSmall: GoogleFonts.cinzel(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0F1219),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.cinzel(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: 1.2,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF0A0C11),
          selectedItemColor:
              accentGold, // Gold for active items looks very sober/elegant
          unselectedItemColor: Colors.white24,
        ),
      ),
      home: const CalendarioScreen(),
    );
  }
}
