import 'package:flutter/material.dart';
import 'controllers/app_controller.dart';
import 'screens/home_screen.dart';
import 'services/ble_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(BleService(), SettingsService());
  await controller.initialize();
  runApp(Esp32ControlApp(controller: controller));
}

class Esp32ControlApp extends StatelessWidget {
  final AppController controller;
  const Esp32ControlApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
            title: 'ESP32 Control',
            debugShowCheckedModeBanner: false,
            themeMode: switch (controller.settings.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            home: HomeScreen(controller: controller),
          ));

  ThemeData _theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff006a6a), brightness: brightness),
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)));
}
