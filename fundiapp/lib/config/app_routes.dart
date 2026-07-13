// lib/config/app_routes.dart

class AppRoutes {
  // ===== AUTH ROUTES =====
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String otp = '/otp';
  static const String forgot = '/forgot-password';
  static const String reset = '/reset-password';

  // ===== FUNDI MAIN SCREENS =====
  static const String home = '/home';
  static const String posts = '/posts';           // Blog/Posts screen
  static const String createPost = '/create-post';
  static const String editPost = '/edit-post';
  static const String portfolio = '/portfolio';
  static const String addPortfolio = '/add-portfolio';
  static const String editPortfolio = '/edit-portfolio';
  static const String requests = '/requests';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String settings = '/settings';

  // ===== CHAT ROUTES =====
  static const String chatList = '/chat-list';
  static const String chat = '/chat';
  static const String voiceCall = '/voice-call';
  static const String videoCall = '/video-call';

  // ===== BLOG/POSTS ROUTE =====
  static const String blog = '/posts';  // Alias for posts

  // ===== STATIC PAGES =====
  static const String about = '/about';
  static const String terms = '/terms';
  static const String faq = '/faq';
  static const String contactUs = '/contact-us';

  // ===== NAVIGATION HELPERS =====
  static String getChatRoute(int conversationId) => '/chat/$conversationId';
  static String getEditPostRoute(int postId) => '/edit-post/$postId';
  static String getEditPortfolioRoute(int itemId) => '/edit-portfolio/$itemId';
  static String getOtpRoute(String email) => '/otp?email=$email';
  static String getResetRoute(String email) => '/reset-password?email=$email';

  // ===== ROUTE MAP FOR REFERENCE =====
  static const Map<String, String> routeNames = {
    splash: 'Splash Screen',
    onboarding: 'Onboarding',
    login: 'Login',
    register: 'Register',
    otp: 'OTP Verification',
    forgot: 'Forgot Password',
    reset: 'Reset Password',
    home: 'Home Dashboard',
    posts: 'My Posts',
    createPost: 'Create Post',
    editPost: 'Edit Post',
    portfolio: 'Portfolio',
    addPortfolio: 'Add Portfolio Item',
    editPortfolio: 'Edit Portfolio Item',
    requests: 'Requests',
    profile: 'Profile',
    editProfile: 'Edit Profile',
    settings: 'Settings',
    chatList: 'Chat List',
    chat: 'Chat',
    voiceCall: 'Voice Call',
    videoCall: 'Video Call',
    about: 'About Us',
    terms: 'Terms & Conditions',
    faq: 'FAQ',
    contactUs: 'Contact Us',
  };
}