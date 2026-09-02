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
  Widget build(BuildContext context) => MaterialApp(
        title: 'ESP32 Control',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xff006a6a)),
            useMaterial3: true,
            inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 14))),
        home: HomeScreen(controller: controller),
      );
}
