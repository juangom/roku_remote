import 'package:flutter/material.dart';

import 'ui/device_picker_page.dart';

void main() {
  runApp(const RokuRemoteApp());
}

class RokuRemoteApp extends StatelessWidget {
  const RokuRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF5A2D8C);
    const appBarColor = Color(0xFF3E1E66);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(primary: primary, onPrimary: Colors.white);

    return MaterialApp(
      title: 'Roku Remote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
        ),
      ),
      home: const DevicePickerPage(),
    );
  }
}
