
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

// ============================================================
// CONFIG
// ============================================================

import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'firebase_options.dart';

// ============================================================
// LOCALIZATION
// ============================================================

import 'l10n/app_localizations.dart';

// ============================================================
// MODELS
// ============================================================

import 'models/chat_conversation.dart';

// ============================================================
// PROVIDERS
// ============================================================

import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/request_provider.dart';
import 'providers/portfolio_provider.dart';
import 'providers/technician_provider.dart';
import 'providers/service_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/static_page_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/subscription_provider.dart';

// ============================================================
// SERVICES
// ============================================================

import 'services/fcm_service.dart';
import 'services/security_service.dart';

// ============================================================
// AUTH SCREENS
// ============================================================

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';

// ============================================================
// REGISTRATION FLOW
// ============================================================

import 'screens/auth/register_flow/register_step1_screen.dart';
import 'screens/auth/register_flow/register_step2_screen.dart';
import 'screens/auth/register_flow/register_step3_screen.dart';
import 'screens/auth/register_flow/register_step4_screen.dart';
import 'screens/auth/register_flow/register_review_screen.dart';

// ============================================================
// FUNDI SCREENS
// ============================================================

import 'screens/fundi/fundi_home_screen.dart';
import 'screens/fundi/fundi_posts_screen.dart';
import 'screens/fundi/fundi_portfolio_screen.dart';
import 'screens/fundi/fundi_requests_screen.dart';

import 'screens/fundi/profile/edit_profile_screen.dart';
import 'screens/fundi/profile/fundi_profile_screen.dart';
import 'screens/fundi/profile/fundi_settings_screen.dart';

// ============================================================
// STATIC SCREENS
// ============================================================

import 'screens/static/about_screen.dart';
import 'screens/static/terms_screen.dart';
import 'screens/static/faq_screen.dart';
import 'screens/static/contact_us_screen.dart';
import 'screens/static/privacy_policy_screen.dart';

// ============================================================
// CHAT
// ============================================================

import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/voice_call_screen.dart';
import 'screens/chat/video_call_screen.dart';

// ============================================================
// SUBSCRIPTION
// ============================================================

import 'screens/subscription/rate_cards_screen.dart';
import 'screens/subscription/payment_methods_screen.dart';
import 'screens/subscription/my_subscriptions_screen.dart';
import 'screens/subscription/downloads_screen.dart';

// ============================================================
// GLOBAL NAVIGATOR KEY
// ============================================================
//
// Keep the navigator key owned by main.dart.
//
// This avoids making app startup depend on a navigator key
// exposed by FcmService.
//
// FCM can still use this key if your FcmService is designed
// to receive/use it.
//

final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
WidgetsFlutterBinding.ensureInitialized();

// ----------------------------------------------------------
// Firebase
// ----------------------------------------------------------

try {
await Firebase.initializeApp(
options: DefaultFirebaseOptions.currentPlatform,
);

debugPrint('✅ Firebase initialized successfully');
} catch (e, stackTrace) {
debugPrint('❌ Firebase initialization failed: $e');
debugPrint('$stackTrace');

// Do not stop application startup.
//
// This is important for iOS testing because a Firebase
// configuration/plugin problem should not prevent Flutter
// from displaying the application UI.
}

// ----------------------------------------------------------
// Firebase Cloud Messaging
// ----------------------------------------------------------

try {
await FcmService.init();

debugPrint('✅ FCM initialized successfully');
} catch (e, stackTrace) {
debugPrint('❌ FCM initialization failed: $e');
debugPrint('$stackTrace');

// Do not block runApp().
}

// ----------------------------------------------------------
// Secure Screen
// ----------------------------------------------------------

try {
await SecurityService.enableSecureScreen();

debugPrint('✅ Secure screen initialized successfully');
} catch (e, stackTrace) {
debugPrint('❌ Secure screen initialization failed: $e');
debugPrint('$stackTrace');

// Do not block application startup.
}

// ----------------------------------------------------------
// System UI
// ----------------------------------------------------------

try {
await SystemChrome.setPreferredOrientations(
const [
DeviceOrientation.portraitUp,
DeviceOrientation.portraitDown,
],
);

SystemChrome.setSystemUIOverlayStyle(
const SystemUiOverlayStyle(
statusBarColor: Colors.transparent,
statusBarIconBrightness: Brightness.dark,
systemNavigationBarColor: Colors.transparent,
systemNavigationBarIconBrightness: Brightness.light,
),
);
} catch (e, stackTrace) {
debugPrint('⚠️ System UI configuration failed: $e');
debugPrint('$stackTrace');
}

// ----------------------------------------------------------
// Auth Provider
// ----------------------------------------------------------
//
// Create once because the same instance is also registered
// with ProviderRegistry.
//

final authProvider = AuthProvider(
navigatorKey: navigatorKey,
);

ProviderRegistry.registerAuthProvider(authProvider);

// ----------------------------------------------------------
// Start Flutter application
// ----------------------------------------------------------

runApp(
MultiProvider(
providers: [
ChangeNotifierProvider<AuthProvider>.value(
value: authProvider,
),

ChangeNotifierProvider<PostProvider>(
create: (_) => PostProvider(),
),

ChangeNotifierProvider<RequestProvider>(
create: (_) => RequestProvider(),
),

ChangeNotifierProvider<PortfolioProvider>(
create: (_) => PortfolioProvider(),
),

ChangeNotifierProvider<TechnicianProvider>(
create: (_) => TechnicianProvider(),
),

ChangeNotifierProvider<ServiceProvider>(
create: (_) => ServiceProvider(),
),

ChangeNotifierProvider<NotificationProvider>(
create: (_) => NotificationProvider(),
),

ChangeNotifierProvider<SettingsProvider>(
create: (_) => SettingsProvider(),
),

ChangeNotifierProvider<StaticPageProvider>(
create: (_) => StaticPageProvider(),
),

ChangeNotifierProvider<ThemeProvider>(
create: (_) => ThemeProvider(),
),

ChangeNotifierProvider<ChatProvider>(
create: (_) => ChatProvider(),
),

ChangeNotifierProvider<SubscriptionProvider>(
create: (_) => SubscriptionProvider(),
),
],
child: const MyApp(),
),
);
}

// ============================================================
// MY APP
// ============================================================

class MyApp extends StatelessWidget {
const MyApp({super.key});

@override
Widget build(BuildContext context) {
return Consumer<ThemeProvider>(
builder: (
BuildContext context,
ThemeProvider themeProvider,
Widget? _,
) {
return Consumer<SettingsProvider>(
builder: (
BuildContext context,
SettingsProvider settings,
Widget? _,
) {
return MaterialApp(
title: 'NETSAF FUNDI APP',

debugShowCheckedModeBanner: false,

// ------------------------------------------------
// Theme
// ------------------------------------------------

theme: AppTheme.lightTheme,
darkTheme: AppTheme.darkTheme,
themeMode: themeProvider.themeMode,

// ------------------------------------------------
// Navigator
// ------------------------------------------------

navigatorKey: navigatorKey,

// ------------------------------------------------
// Localization
// ------------------------------------------------

locale: settings.currentLocale,

localizationsDelegates: const [
AppLocalizations.delegate,
GlobalMaterialLocalizations.delegate,
GlobalCupertinoLocalizations.delegate,
GlobalWidgetsLocalizations.delegate,
],

supportedLocales: const [
Locale('en'),
Locale('sw'),
],

// ------------------------------------------------
// Routing
// ------------------------------------------------

initialRoute: AppRoutes.splash,
onGenerateRoute: _generateRoute,

// ------------------------------------------------
// System UI
// ------------------------------------------------

builder: (
BuildContext context,
Widget? child,
) {
return AnnotatedRegion<SystemUiOverlayStyle>(
value: const SystemUiOverlayStyle(
statusBarColor: Colors.transparent,
statusBarIconBrightness: Brightness.dark,
systemNavigationBarColor: Colors.transparent,
systemNavigationBarIconBrightness: Brightness.light,
),
child: child ?? const SizedBox.shrink(),
);
},
);
},
);
},
);
}

// ==========================================================
// ROUTES
// ==========================================================

Route<dynamic> _generateRoute(RouteSettings settings) {
final Object? args = settings.arguments;

switch (settings.name) {
// ========================================================
// AUTH
// ========================================================

case AppRoutes.splash:
return MaterialPageRoute(
builder: (_) => const SplashScreen(),
settings: settings,
);

case AppRoutes.onboarding:
return MaterialPageRoute(
builder: (_) => const OnboardingScreen(),
settings: settings,
);

case AppRoutes.login:
return MaterialPageRoute(
builder: (_) => const LoginScreen(),
settings: settings,
);

// ========================================================
// REGISTRATION
// ========================================================

case AppRoutes.registerStep1:
return MaterialPageRoute(
builder: (_) => const RegisterStep1Screen(),
settings: settings,
);

case AppRoutes.registerStep2:
final int technicianId = _getIntArgument(args);

return MaterialPageRoute(
builder: (_) => RegisterStep2Screen(
technicianId: technicianId,
),
settings: settings,
);

case AppRoutes.registerStep3:
final int technicianId = _getIntArgument(args);

return MaterialPageRoute(
builder: (_) => RegisterStep3Screen(
technicianId: technicianId,
),
settings: settings,
);

case AppRoutes.registerStep4:
final int technicianId = _getIntArgument(args);

return MaterialPageRoute(
builder: (_) => RegisterStep4Screen(
technicianId: technicianId,
),
settings: settings,
);

case AppRoutes.registerReview:
if (args is Map<String, dynamic>) {
return MaterialPageRoute(
builder: (_) => RegisterReviewScreen(
registrationData: args,
),
settings: settings,
);
}

return MaterialPageRoute(
builder: (_) => const RegisterStep1Screen(),
settings: settings,
);

// ========================================================
// OTP
// ========================================================

case AppRoutes.otp:
if (args is Map<String, dynamic>) {
return MaterialPageRoute(
builder: (_) => OtpVerificationScreen(
email: args['email']?.toString() ?? '',
redirectToStep2:
args['redirectToStep2'] == true,
technicianId: _nullableInt(args['technicianId']),
),
settings: settings,
);
}

return MaterialPageRoute(
builder: (_) => OtpVerificationScreen(
email: args?.toString() ?? '',
),
settings: settings,
);

// ========================================================
// PASSWORD
// ========================================================

case AppRoutes.forgot:
return MaterialPageRoute(
builder: (_) => const ForgotPasswordScreen(),
settings: settings,
);

case AppRoutes.reset:
return MaterialPageRoute(
builder: (_) => ResetPasswordScreen(
email: args?.toString() ?? '',
),
settings: settings,
);

// ========================================================
// FUNDI HOME
// ========================================================

case AppRoutes.home:
return MaterialPageRoute(
builder: (_) => const FundiHomeScreen(),
settings: settings,
);

// ========================================================
// POSTS / BLOG
// ========================================================

case AppRoutes.posts:
case AppRoutes.blog:
case AppRoutes.createPost:
case AppRoutes.editPost:
return MaterialPageRoute(
builder: (_) => const FundiPostsScreen(),
settings: settings,
);

// ========================================================
// PORTFOLIO
// ========================================================

case AppRoutes.portfolio:
case AppRoutes.addPortfolio:
case AppRoutes.editPortfolio:
return MaterialPageRoute(
builder: (_) => const FundiPortfolioScreen(),
settings: settings,
);

// ========================================================
// REQUESTS
// ========================================================

case AppRoutes.requests:
return MaterialPageRoute(
builder: (_) => const FundiRequestsScreen(),
settings: settings,
);

// ========================================================
// PROFILE
// ========================================================

case AppRoutes.profile:
return MaterialPageRoute(
builder: (_) => const FundiProfileScreen(),
settings: settings,
);

case AppRoutes.editProfile:
return MaterialPageRoute(
builder: (_) => const EditProfileScreen(),
settings: settings,
);

case AppRoutes.settings:
return MaterialPageRoute(
builder: (_) => const FundiSettingsScreen(),
settings: settings,
);

// ========================================================
// CHAT
// ========================================================

case AppRoutes.chatList:
return MaterialPageRoute(
builder: (_) => const ChatListScreen(),
settings: settings,
);

case AppRoutes.chat:
if (args is ChatConversation) {
return MaterialPageRoute(
builder: (_) => ChatScreen(
conversation: args,
),
settings: settings,
);
}

return MaterialPageRoute(
builder: (_) => const ChatListScreen(),
settings: settings,
);

// ========================================================
// VOICE CALL
// ========================================================

case AppRoutes.voiceCall:
final Map<String, dynamic>? voiceArgs =
_getMapArgument(args);

return MaterialPageRoute(
builder: (_) => VoiceCallScreen(
userName:
voiceArgs?['userName']?.toString() ?? 'Unknown',
userId:
voiceArgs?['userId']?.toString() ?? '',
),
settings: settings,
);

// ========================================================
// VIDEO CALL
// ========================================================

case AppRoutes.videoCall:
final Map<String, dynamic>? videoArgs =
_getMapArgument(args);

return MaterialPageRoute(
builder: (_) => VideoCallScreen(
userName:
videoArgs?['userName']?.toString() ?? 'Unknown',
userId:
videoArgs?['userId']?.toString() ?? '',
),
settings: settings,
);

// ========================================================
// STATIC PAGES
// ========================================================

case AppRoutes.about:
return MaterialPageRoute(
builder: (_) => const AboutScreen(),
settings: settings,
);

case AppRoutes.terms:
return MaterialPageRoute(
builder: (_) => const TermsScreen(),
settings: settings,
);

case AppRoutes.faq:
return MaterialPageRoute(
builder: (_) => const FaqScreen(),
settings: settings,
);

case AppRoutes.contactUs:
return MaterialPageRoute(
builder: (_) => const ContactUsScreen(),
settings: settings,
);

case AppRoutes.privacy:
return MaterialPageRoute(
builder: (_) => const PrivacyPolicyScreen(),
settings: settings,
);

// ========================================================
// SUBSCRIPTIONS
// ========================================================

case AppRoutes.rateCards:
return MaterialPageRoute(
builder: (_) => const RateCardsScreen(),
settings: settings,
);

case AppRoutes.paymentMethods:
return MaterialPageRoute(
builder: (_) => const PaymentMethodsScreen(),
settings: settings,
);

case AppRoutes.subscriptions:
return MaterialPageRoute(
builder: (_) => const MySubscriptionsScreen(),
settings: settings,
);

case AppRoutes.createSubscription:
return MaterialPageRoute(
builder: (_) => const RateCardsScreen(),
settings: settings,
);

// ========================================================
// DOWNLOADS
// ========================================================

case AppRoutes.downloads:
return MaterialPageRoute(
builder: (_) => const DownloadsScreen(),
settings: settings,
);

// ========================================================
// UNKNOWN ROUTE
// ========================================================

default:
debugPrint(
'⚠️ Unknown route: ${settings.name}',
);

return MaterialPageRoute(
builder: (_) => const SplashScreen(),
settings: settings,
);
}
}

// ==========================================================
// ROUTE ARGUMENT HELPERS
// ==========================================================

int _getIntArgument(Object? args) {
if (args is int) {
return args;
}

if (args is String) {
return int.tryParse(args) ?? 0;
}

if (args is Map<String, dynamic>) {
final Object? value =
args['technicianId'] ?? args['id'];

if (value is int) {
return value;
}

if (value is String) {
return int.tryParse(value) ?? 0;
}
}

return 0;
}

int? _nullableInt(Object? value) {
if (value is int) {
return value;
}

if (value is String) {
return int.tryParse(value);
}

return null;
}

Map<String, dynamic>? _getMapArgument(Object? args) {
if (args is Map<String, dynamic>) {
return args;
}

return null;
}
}

// ============================================================
// PROVIDER REGISTRY
// ============================================================
//
// Used by services that need access to AuthProvider without
// depending directly on a BuildContext.
//

class ProviderRegistry {
static AuthProvider? _authProvider;

static void registerAuthProvider(
AuthProvider provider,
) {
_authProvider = provider;
}

static AuthProvider? get authProvider => _authProvider;
}

