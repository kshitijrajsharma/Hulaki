import 'package:fieldchat/app/auth_gate.dart';
import 'package:fieldchat/design/app_theme.dart';
import 'package:flutter/material.dart';

/// Application root. Holds the theme and the top-level navigation surface.
class FieldChatApp extends StatelessWidget {
  const FieldChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldChat',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
