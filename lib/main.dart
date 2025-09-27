import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushup_counter/pages/pushup_counter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Request camera permission
  await Permission.camera.request();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pushup Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const PushupCounter()
    );
  }
}
