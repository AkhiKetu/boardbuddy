import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  // Initialize Flutter before using Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Connect BoardBuddy to the Firebase project.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Start the BoardBuddy application.
  runApp(const BoardBuddyApp());
}
