import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/app.dart';
import 'package:gymgenie/firebase_options.dart';
import 'package:gymgenie/features/workout/data/local_log_store.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure the local log database exists and try to sync anything saved
  // while the device was offline.
  await LocalLogStore().database;
  await LogRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    LocalLogStore(),
  ).syncPendingLogs();

  runApp(const ProviderScope(child: GymGenieApp()));
}
