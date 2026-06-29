import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  // Vibrant Brand Colors
  static const Color brandGreen = Color(0xFF059669); // Emerald Green
  static const Color brandSlate = Color(0xFF0F172A); // Slate 900
  static const Color brandOrange = Color(0xFFF59E0B); // Amber/Orange 500

  static ThemeData get light {
    return FlexThemeData.light(
      colors: FlexSchemeColor.from(
        primary: brandGreen,
        secondary: brandSlate,
        tertiary: brandOrange,
      ),
      scaffoldBackground: Colors.white,
      appBarBackground: Colors.white,
      surfaceMode: FlexSurfaceMode.level,
      blendLevel: 0,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 0,
        blendOnColors: false,
        useTextTheme: true,
        useM2StyleDividerInM3: false,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        
        // Premium rounded shapes (Rounded corners 18-20)
        cardRadius: 20.0,
        dialogRadius: 24.0,
        inputDecoratorRadius: 14.0,
        
        inputDecoratorIsFilled: true,
        inputDecoratorFillColor: Colors.white,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarMutedUnselectedLabel: true,
        navigationBarMutedUnselectedIcon: true,
        navigationBarIndicatorOpacity: 0.12,
        navigationBarElevation: 0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    );
  }

  static ThemeData get dark {
    return FlexThemeData.dark(
      colors: FlexSchemeColor.from(
        primary: brandGreen,
        secondary: brandSlate,
        tertiary: brandOrange,
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 10,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 15,
        useTextTheme: true,
        useM2StyleDividerInM3: false,
        alignedDropdown: true,
        useInputDecoratorThemeInDialogs: true,
        
        // Premium rounded shapes
        cardRadius: 20.0,
        dialogRadius: 24.0,
        inputDecoratorRadius: 14.0,
        
        inputDecoratorIsFilled: true,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarMutedUnselectedLabel: true,
        navigationBarMutedUnselectedIcon: true,
        navigationBarIndicatorOpacity: 0.15,
        navigationBarElevation: 0,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
      fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    );
  }
}
