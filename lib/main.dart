import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth_wrapper.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try initializing Firebase. If user hasn't run flutterfire configure,
  // the app will throw here.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Proceeding even if Firebase fails so the UI can show an error
  }

  runApp(
    const ProviderScope(
      child: EHadirApp(),
    ),
  );
}

class EHadirApp extends StatelessWidget {
  const EHadirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eHadir — IKM Johor Bahru',
      debugShowCheckedModeBanner: false,
      theme: EHadirTheme.lightTheme,
      home: const AuthWrapper(),
    );
  }
}
