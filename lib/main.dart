import 'package:flutter/material.dart';

import 'pages/root_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MelodiaApp());
}

class MelodiaApp extends StatelessWidget {
  const MelodiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Melodia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.gelap,
      home: const RootPage(),
    );
  }
}
