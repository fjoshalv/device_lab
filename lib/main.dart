import 'package:device_lab/src/presentation/device_info_screen.dart';
import 'package:device_lab/src/presentation/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomeScreen(),
      routes: {'device_info': (_) => const DeviceInfoScreen()},
    );
  }
}
