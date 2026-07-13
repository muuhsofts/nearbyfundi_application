// main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_routes.dart';
import 'config/app_theme.dart';
import 'models/chat_conversation.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/request_provider.dart';
import 'providers/technician_provider.dart';
import 'providers/service_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/location_provider.dart';
import 'providers/static_page_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/chat_provider.dart';  // 👈 Add this
import 'services/fcm_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/otp_verification_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/post_detail_screen.dart';
import 'screens/technicians/technician_detail_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/settings_screen.dart';
import 'screens/profile/about_screen.dart';
import 'screens/profile/terms_screen.dart';
import 'screens/profile/faq_screen.dart';
import 'screens/profile/contact_us_screen.dart';
import 'screens/chat/chat_list_screen.dart';  // 👈 Add this
import 'screens/chat/chat_screen.dart';  // 👈 Add this
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        ChangeNotifierProvider(create: (_) => TechnicianProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => StaticPageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),  // 👈 Add this
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              return MaterialApp(
                title: 'NearbyFundi',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
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
                navigatorKey: navigatorKey,
                initialRoute: AppRoutes.splash,
                onGenerateRoute: (settings) {
                  switch (settings.name) {
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
                          email: settings.arguments as String,
                        ),
                      );
                    case AppRoutes.forgot:
                      return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
                    case AppRoutes.reset:
                      return MaterialPageRoute(
                        builder: (_) => ResetPasswordScreen(
                          email: settings.arguments as String,
                        ),
                      );
                    case AppRoutes.home:
                      return MaterialPageRoute(builder: (_) => const HomeScreen());
                    case AppRoutes.technicianDetail:
                      return MaterialPageRoute(
                        builder: (_) => TechnicianDetailScreen(
                          technicianId: settings.arguments as int,
                        ),
                      );
                    case AppRoutes.postDetail:
                      return MaterialPageRoute(
                        builder: (_) => PostDetailScreen(
                          postId: settings.arguments as int,
                        ),
                      );
                    case AppRoutes.editProfile:
                      return MaterialPageRoute(builder: (_) => const EditProfileScreen());
                    case AppRoutes.settings:
                      return MaterialPageRoute(builder: (_) => const SettingsScreen());
                    case AppRoutes.about:
                      return MaterialPageRoute(builder: (_) => const AboutScreen());
                    case AppRoutes.terms:
                      return MaterialPageRoute(builder: (_) => const TermsScreen());
                    case AppRoutes.faq:
                      return MaterialPageRoute(builder: (_) => const FaqScreen());
                    case AppRoutes.contactUs:
                      return MaterialPageRoute(builder: (_) => const ContactUsScreen());
                    case AppRoutes.chatList:
                      return MaterialPageRoute(builder: (_) => const ChatListScreen());
                    case AppRoutes.chatScreen:
                      return MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversation: settings.arguments as ChatConversation,
                        ),
                      );
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