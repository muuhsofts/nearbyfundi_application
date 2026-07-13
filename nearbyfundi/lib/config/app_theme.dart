import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ===== COLORS =====
  static const Color dark = Color(0xFF002B49);
  static const Color primaryColor = Color(0xFF006B5E);
  static const Color primaryDark = Color(0xFF004D3A);
  static const Color secondaryColor = Color(0xFFF5A623);
  static const Color accentColor = Color(0xFF00A896);
  static const Color light = Color(0xFFFFFFFF);
  static const Color sea = Color(0xFF004472);
  static const Color salat = Color(0xFF21AE8C);
  static const Color black = Color(0xFF13191D);
  static const Color errorColor = Colors.red;
  static const Color successColor = salat;
  static const Color warningColor = secondaryColor;
  static const Color borderLight = Color(0xFFE2E8F0);

  // ===== ALIASES =====
  static const Color background = light;
  static const Color secondary = secondaryColor;
  static const Color textSecondary = Color(0xFF8A8A8A);
  static const Color border = borderLight;
  static const Color surface = light;
  static const Color accent = accentColor;
  static const Color primary = primaryColor;
  static const Color success = successColor;
  static const Color error = errorColor;

  // ===== CHAT COLORS =====
  static const Color chatBubbleSent = primaryColor;
  static const Color chatBubbleReceived = Color(0xFF2A2A2A);
  static const Color chatTextSent = Colors.white;
  static const Color chatTextReceived = Colors.white;
  static const Color chatTimestampSent = Color(0xCCFFFFFF);
  static const Color chatTimestampReceived = Color(0xFF888888);
  static const Color chatInputBackground = Color(0xFF1A1A1A);
  static const Color chatDivider = Color(0xFF333333);
  static const Color chatOnlineDot = Color(0xFF4CAF50);
  static const Color chatOfflineDot = Color(0xFF9E9E9E);
  static const Color chatUnreadBadge = Color(0xFFFF4444);

  // ===== RADIUS =====
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusExtraLarge = 24.0;
  static const double borderRadiusMessageBubble = 16.0;

  // ===== GETTERS =====
  static Color get backgroundColor => light;
  static Color get surfaceColor => light;
  static Color get greyText => Colors.grey.shade600;
  static Color get darkText => black;

  // ===== TEXT STYLES =====
  static TextStyle get bodyText => GoogleFonts.poppins(
    fontSize: 14,
    color: greyText,
  );
  static TextStyle get headline2 => GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: darkText,
  );
  static TextStyle get buttonText => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: light,
  );

  static TextStyle get chatMessageText => GoogleFonts.poppins(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );
  static TextStyle get chatTimestampText => GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w400,
  );
  static TextStyle get chatNameText => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static TextStyle get chatEmptyText => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: Colors.grey,
  );
  static TextStyle get chatHeaderText => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  // ===== DECORATIONS =====
  static BoxDecoration cardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: light,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderLight, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          spreadRadius: 1,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration darkCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: const Color(0xFF333333), width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          spreadRadius: 1,
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration chatBubbleDecoration({
    required bool isSent,
    double radius = 16,
  }) {
    return BoxDecoration(
      color: isSent ? chatBubbleSent : chatBubbleReceived,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
        bottomLeft: Radius.circular(isSent ? radius : 4),
        bottomRight: Radius.circular(isSent ? 4 : radius),
      ),
    );
  }

  static BoxDecoration chatInputContainerDecoration({bool isDark = false}) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    );
  }

  static BoxDecoration chatListItemDecoration({bool isActive = false}) {
    return BoxDecoration(
      color: isActive ? primaryColor.withOpacity(0.05) : Colors.transparent,
      border: Border(
        bottom: BorderSide(
          color: borderLight.withOpacity(0.5),
          width: 0.5,
        ),
      ),
    );
  }

  static CardThemeData get cardTheme => lightTheme.cardTheme;

  static InputDecoration inputDecoration({
    String? label,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primary) : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: light,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 14),
    );
  }

  static InputDecoration chatFieldDecoration({
    String? hint,
    bool isDark = false,
  }) {
    return InputDecoration(
      hintText: hint ?? 'Type a message...',
      hintStyle: GoogleFonts.poppins(
        color: isDark ? Colors.white54 : Colors.grey.shade400,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusExtraLarge),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusExtraLarge),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusExtraLarge),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }

  // ===== LIGHT THEME =====
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: salat,
      error: errorColor,
      surface: Colors.white,
    ),
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Colors.black87),
      bodyMedium: const TextStyle(color: Colors.black54),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black54,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: Colors.black54,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
      iconTheme: IconThemeData(color: Colors.black),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: Colors.grey),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      color: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 8,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStatePropertyAll(primary),
      trackColor: MaterialStatePropertyAll(Color(0xFFB0BEC5)),
    ),
  );

  // ===== DARK THEME – true black background, dark gray surfaces =====
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: Colors.black, // true black
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: salat,
      error: errorColor,
      surface: Color(0xFF1A1A1A),
    ),
    textTheme: GoogleFonts.poppinsTextTheme().copyWith(
      bodyLarge: const TextStyle(color: Colors.white),
      bodyMedium: const TextStyle(color: Colors.white70),
      headlineMedium: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: Colors.white70,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF1A1A1A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: Colors.white70),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      color: Color(0xFF1A1A1A),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: primary,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.black,
      elevation: 8,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStatePropertyAll(primary),
      trackColor: MaterialStatePropertyAll(Color(0xFF455A64)),
    ),
  );
}

// ===== THEME EXTENSION =====
extension ChatTheme on ThemeData {
  Color get chatBubbleSent => AppTheme.chatBubbleSent;
  Color get chatBubbleReceived => AppTheme.chatBubbleReceived;
  Color get chatTextSent => AppTheme.chatTextSent;
  Color get chatTextReceived => AppTheme.chatTextReceived;
  Color get chatTimestampSent => AppTheme.chatTimestampSent;
  Color get chatTimestampReceived => AppTheme.chatTimestampReceived;
  Color get chatOnlineDot => AppTheme.chatOnlineDot;
  Color get chatUnreadBadge => AppTheme.chatUnreadBadge;

  TextStyle get chatMessageText => AppTheme.chatMessageText;
  TextStyle get chatTimestampText => AppTheme.chatTimestampText;
  TextStyle get chatNameText => AppTheme.chatNameText;
  TextStyle get chatEmptyText => AppTheme.chatEmptyText;
}