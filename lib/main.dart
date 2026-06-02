import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Offline play still works even if Firebase fails to initialise.
  }
  runApp(const CowboyTrioApp());
}

class CowboyTrioApp extends StatelessWidget {
  const CowboyTrioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '3인 카우보이',
      debugShowCheckedModeBanner: false,
      theme: buildCowboyTheme(),
      home: const HomeScreen(),
    );
  }
}
