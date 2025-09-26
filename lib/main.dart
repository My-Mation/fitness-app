import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushup_counter/pages/home.dart';
import 'package:pushup_counter/pages/pushup_counter.dart';
import 'package:pushup_counter/services/storage_service.dart';
import 'package:pushup_counter/services/overlay_service.dart';
import 'package:pushup_counter/services/usage_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();
  await storage.init();
  // Request overlay permission early (best effort)
  final overlay = OverlayService();
  await overlay.ensurePermission();
  // Request camera permission best effort
  await Permission.camera.request();
  // Usage access must be granted via settings screen; prompt if missing
  final usage = UsageService();
  if (!await usage.hasPermission()) {
    await usage.requestPermission();
  }


  // Set up method channel for overlay communication
  const platform = MethodChannel('com.example.pushup_counter/overlay');
  platform.setMethodCallHandler(_handleOverlayMethodCall);

  runApp(const MyApp());
}

Future<void> _handleOverlayMethodCall(MethodCall call) async {
  switch (call.method) {
    case 'startPushups':
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (context) => const PushupCounter()),
      );
      break;
    case 'closeOverlay':
      // Close overlay - this is handled by the overlay itself
      print('Overlay requested to close');
      break;
    default:
      print('Unknown method from overlay: ${call.method}');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Pushup Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const Home()
    );
  }
}
