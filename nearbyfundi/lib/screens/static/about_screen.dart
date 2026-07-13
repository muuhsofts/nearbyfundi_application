// lib/screens/static/about_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/static_page_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaticPageProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('About Us')),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          provider.about?.content ?? 'No content available',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ),
    );
  }
}