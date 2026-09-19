import 'package:flutter/material.dart';

import 'player/player_controller.dart';
import 'ui/player_page.dart';

class FikPlayerApp extends StatelessWidget {
  const FikPlayerApp({super.key, required this.controller});

  final PlayerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fik_player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE8E8E8),
          surface: Color(0xFF121212),
        ),
        scaffoldBackgroundColor: Colors.black,
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFE8E8E8),
          inactiveTrackColor: Color(0xFF444444),
          thumbColor: Color(0xFFE8E8E8),
        ),
      ),
      home: PlayerPage(controller: controller),
    );
  }
}
