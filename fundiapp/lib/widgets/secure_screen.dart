// lib/widgets/secure_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/security_service.dart';

/// A wrapper widget that prevents screenshots and screen recording
class SecureScreen extends StatefulWidget {
  final Widget child;
  final bool preventScreenshot;

  const SecureScreen({
    super.key,
    required this.child,
    this.preventScreenshot = true,
  });

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (widget.preventScreenshot) {
      SecurityService.enableSecureScreen();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (widget.preventScreenshot) {
      SecurityService.disableSecureScreen();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && widget.preventScreenshot) {
      SecurityService.enableSecureScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}