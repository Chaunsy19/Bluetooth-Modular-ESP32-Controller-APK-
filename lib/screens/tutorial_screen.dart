import 'package:flutter/material.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Tutorial'),
            leading: const BackButton(),
            actions: const [
              Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(Icons.school_outlined))
            ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          _section(
            context,
            Icons.route_outlined,
            'How the app works',
            const [
              '1. Scan for and connect to ESP32-Control.',
              '2. The ESP32 sends its saved module layout to the app.',
              '3. Add a module or open its details to choose its function and GPIO pins.',
              '4. The ESP32 validates and saves the change. You do not need to edit or upload code again.',
              '5. The controls send BLE commands; the ESP32 produces low-power control signals for your accessory electronics.',
            ],
          ),
          _section(
            context,
            Icons.memory_outlined,
            'Recommended ESP32 DevKit V1 pins',
            const [
              'On/off, PWM light, or servo signal: GPIO 13, 14, 16–19, 21–23, 25–27, 32, or 33.',
              'Analog input: GPIO 32–36 or 39.',
              'Digital input: most exposed GPIOs; GPIO 34–39 are input-only.',
              'Motor/winch: three unused output pins—PWM/enable, direction A, and direction B.',
              'A pin can belong to only one module at a time.',
            ],
          ),
          _warning(
            context,
            'Pins to avoid',
            'Never use GPIO 6–11 because they connect to flash. Avoid GPIO 1 and 3 because they handle USB serial. GPIO 0, 2, 5, 12, and 15 are boot pins and attached circuits can prevent startup.',
          ),
          _section(
            context,
            Icons.extension_outlined,
            'Accessory types',
            const [
              'On/off light or relay: a HIGH/LOW control signal.',
              'Dimmable PWM light: a 0–100% PWM signal.',
              'Servo: a standard 0–180° servo control signal.',
              'Motor/winch: a momentary −100% to 100% control that stops when released.',
              'Digital input: displays HIGH or LOW.',
              'Analog input: displays the ESP32 ADC reading.',
            ],
          ),
          _warning(
            context,
            'External drivers and power are required',
            'ESP32 pins produce signals only. Use a resistor and suitable MOSFET for lights, a relay driver for relays, and a properly rated H-bridge for motors or winches. Power servos and motors from a suitable external supply—not the ESP32 3.3V pin. Connect the external supply ground to ESP32 GND.',
          ),
          _section(
            context,
            Icons.health_and_safety_outlined,
            'Built-in safety',
            const [
              'Outputs start off when the ESP32 boots.',
              'Lights and motors stop after the BLE disconnect timeout.',
              'The Safety button turns controllable outputs off.',
              'Servo, PWM, and motor values are clamped to their allowed ranges.',
              'The ESP32 rejects invalid, duplicate, or incompatible pin assignments.',
            ],
          ),
        ]),
      );

  Widget _section(BuildContext context, IconData icon, String title,
          List<String> lines) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line),
              ),
          ]),
        ),
      );

  Widget _warning(BuildContext context, String title, String text) => Card(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.warning_amber_rounded),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 10),
            Text(text),
          ]),
        ),
      );
}
