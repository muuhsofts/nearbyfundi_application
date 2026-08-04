import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/fundi/fundi_home_screen.dart';
import 'screens/fundi/fundi_posts_screen.dart';
import 'screens/fundi/fundi_portfolio_screen.dart';
import 'screens/fundi/fundi_requests_screen.dart';
import 'screens/fundi/profile/edit_profile_screen.dart';
import 'screens/fundi/profile/fundi_profile_screen.dart';
import 'screens/fundi/profile/fundi_settings_screen.dart';
import 'screens/static/about_screen.dart';
import 'screens/static/terms_screen.dart';
import 'screens/static/faq_screen.dart';
import 'screens/static/contact_us_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/voice_call_screen.dart';
import 'screens/chat/video_call_screen.dart';
import 'screens/subscription/rate_cards_screen.dart';
import 'screens/subscription/payment_methods_screen.dart';
import 'screens/subscription/my_subscriptions_screen.dart';
import 'screens/subscription/downloads_screen.dart';

// Config
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'firebase_options.dart';

// Providers
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

// Services
import 'services/fcm_service.dart';

// Models
import 'models/chat_conversation.dart';

// Localization
import 'l10n/app_localizations.dart';

// Use FcmService's navigatorKey for notification navigation
final GlobalKey<NavigatorState> navigatorKey = FcmService.navigatorKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.init();

  // Create auth provider first
  final authProvider = AuthProvider(navigatorKey: navigatorKey);

  // Register it globally for other providers to access
  ProviderRegistry.registerAuthProvider(authProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => TechnicianProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => StaticPageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return MaterialApp(
              title: 'NETSAF FUNDI APP',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              navigatorKey: navigatorKey,

              // Localization
              locale: settings.currentLocale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en', ''),
                Locale('sw', ''),
              ],

              initialRoute: AppRoutes.splash,
              onGenerateRoute: _generateRoute,
            );
          },
        );
      },
    );
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
    // ============================================================
    // AUTH ROUTES
    // ============================================================
      case AppRoutes.splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case AppRoutes.onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case AppRoutes.otp:
        return MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            email: args as String? ?? '',
          ),
        );

      case AppRoutes.forgot:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

      case AppRoutes.reset:
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(
            email: args as String? ?? '',
          ),
        );

    // ============================================================
    // FUNDI MAIN SCREENS
    // ============================================================
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const FundiHomeScreen());

      case AppRoutes.posts:
      case AppRoutes.blog:
        return MaterialPageRoute(builder: (_) => const FundiPostsScreen());

      case AppRoutes.createPost:
      case AppRoutes.editPost:
        return MaterialPageRoute(builder: (_) => const FundiPostsScreen());

      case AppRoutes.portfolio:
      case AppRoutes.addPortfolio:
      case AppRoutes.editPortfolio:
        return MaterialPageRoute(builder: (_) => const FundiPortfolioScreen());

      case AppRoutes.requests:
        return MaterialPageRoute(builder: (_) => const FundiRequestsScreen());

      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const FundiProfileScreen());

      case AppRoutes.editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());

      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const FundiSettingsScreen());

    // ============================================================
    // CHAT ROUTES
    // ============================================================
      case AppRoutes.chatList:
        return MaterialPageRoute(builder: (_) => const ChatListScreen());

      case AppRoutes.chat:
        if (args is ChatConversation) {
          return MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: args),
          );
        }
        return MaterialPageRoute(builder: (_) => const ChatListScreen());

      case AppRoutes.voiceCall:
        final voiceArgs = args as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VoiceCallScreen(
            userName: voiceArgs?['userName'] ?? 'Unknown',
            userId: voiceArgs?['userId'] ?? '',
          ),
        );

      case AppRoutes.videoCall:
        final videoArgs = args as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            userName: videoArgs?['userName'] ?? 'Unknown',
            userId: videoArgs?['userId'] ?? '',
          ),
        );

    // ============================================================
    // STATIC PAGES
    // ============================================================
      case AppRoutes.about:
        return MaterialPageRoute(builder: (_) => const AboutScreen());

      case AppRoutes.terms:
        return MaterialPageRoute(builder: (_) => const TermsScreen());

      case AppRoutes.faq:
        return MaterialPageRoute(builder: (_) => const FaqScreen());

      case AppRoutes.contactUs:
        return MaterialPageRoute(builder: (_) => const ContactUsScreen());

    // ============================================================
    // SUBSCRIPTION ROUTES
    // ============================================================
      case AppRoutes.rateCards:
        return MaterialPageRoute(builder: (_) => const RateCardsScreen());

      case AppRoutes.paymentMethods:
        return MaterialPageRoute(
          builder: (_) => const PaymentMethodsScreen(),
          settings: RouteSettings(arguments: args),
        );

      case AppRoutes.subscriptions:
        return MaterialPageRoute(builder: (_) => const MySubscriptionsScreen());

      case AppRoutes.createSubscription:
        return MaterialPageRoute(builder: (_) => const RateCardsScreen());

    // ============================================================
    // 🆕 DOWNLOADS ROUTE
    // ============================================================
      case AppRoutes.downloads:
        return MaterialPageRoute(builder: (_) => const DownloadsScreen());

    // ============================================================
    // DEFAULT
    // ============================================================
      default:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
    }
  }
}