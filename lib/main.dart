import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushup_counter/pages/pushup_counter.dart';
import 'package:pushup_counter/pages/squat_counter.dart';
import 'package:pushup_counter/pages/dumbbell_curl_counter.dart';
import 'package:pushup_counter/pages/pullup_counter.dart';

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
      title: 'Exercise Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const HomePage()
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Counter'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PushupCounter()),
                );
              },
              child: const Text('Pushups'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SquatCounter()),
                );
              },
              child: const Text('Squats'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DumbbellCurlCounter()),
                );
              },
              child: const Text('Dumbbell Curls'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PullupCounter()),
                );
              },
              child: const Text('Pullups'),
            ),
          ],
        ),
      ),
    );
  }
}
