// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fundiapp/screens/fundi/profile/edit_profile_screen.dart';
import 'package:fundiapp/screens/fundi/profile/fundi_profile_screen.dart';
import 'package:fundiapp/screens/fundi/profile/fundi_settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
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
import 'services/fcm_service.dart';
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
import 'screens/static/about_screen.dart';
import 'screens/static/terms_screen.dart';
import 'screens/static/faq_screen.dart';
import 'screens/static/contact_us_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/chat/voice_call_screen.dart';
import 'screens/chat/video_call_screen.dart';
import 'models/chat_conversation.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

// Use FcmService's navigatorKey for notification navigation
final GlobalKey<NavigatorState> navigatorKey = FcmService.navigatorKey;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FcmService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return MaterialApp(
                title: 'FundiApp',
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
                onGenerateRoute: (settings) {
                  switch (settings.name) {
                  // ===== AUTH ROUTES =====
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
                          email: settings.arguments as String? ?? '',
                        ),
                      );

                    case AppRoutes.forgot:
                      return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());

                    case AppRoutes.reset:
                      return MaterialPageRoute(
                        builder: (_) => ResetPasswordScreen(
                          email: settings.arguments as String? ?? '',
                        ),
                      );

                  // ===== FUNDI MAIN SCREENS =====
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

                  // ===== CHAT ROUTES =====
                    case AppRoutes.chatList:
                      return MaterialPageRoute(builder: (_) => const ChatListScreen());

                    case AppRoutes.chat:
                      final args = settings.arguments;
                      if (args is ChatConversation) {
                        return MaterialPageRoute(
                          builder: (_) => ChatScreen(conversation: args),
                        );
                      } else if (args is Map && args.containsKey('conversationId')) {
                        // Navigate to chat list as fallback
                        return MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        );
                      }
                      return MaterialPageRoute(
                        builder: (_) => const ChatListScreen(),
                      );

                    case AppRoutes.voiceCall:
                      final voiceArgs = settings.arguments as Map<String, dynamic>?;
                      return MaterialPageRoute(
                        builder: (_) => VoiceCallScreen(
                          userName: voiceArgs?['userName'] ?? 'Unknown',
                          userId: voiceArgs?['userId'] ?? '',
                        ),
                      );

                    case AppRoutes.videoCall:
                      final videoArgs = settings.arguments as Map<String, dynamic>?;
                      return MaterialPageRoute(
                        builder: (_) => VideoCallScreen(
                          userName: videoArgs?['userName'] ?? 'Unknown',
                          userId: videoArgs?['userId'] ?? '',
                        ),
                      );

                  // ===== STATIC PAGES =====
                    case AppRoutes.about:
                      return MaterialPageRoute(builder: (_) => const AboutScreen());

                    case AppRoutes.terms:
                      return MaterialPageRoute(builder: (_) => const TermsScreen());

                    case AppRoutes.faq:
                      return MaterialPageRoute(builder: (_) => const FaqScreen());

                    case AppRoutes.contactUs:
                      return MaterialPageRoute(builder: (_) => const ContactUsScreen());

                  // ===== DEFAULT =====
                    default:
                      return MaterialPageRoute(builder: (_) => const SplashScreen());
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}