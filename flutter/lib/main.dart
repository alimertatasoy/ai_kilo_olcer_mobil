import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme_colors.dart';
import 'ip_ayar_ekran.dart';

// Kamera listesi global
List<CameraDescription> availCams = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    availCams = await availableCameras();
  } catch (_) {}
  
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  runApp(const KiloApp());
}

class KiloApp extends StatelessWidget {
  const KiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kilo Tahmini',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ThemeColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ThemeColors.accent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const IpAyarEkran(), // Artik buradan baslayacak
    );
  }
}
