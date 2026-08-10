import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gymgenie/app.dart';
import 'package:gymgenie/firebase_options.dart';
import 'package:gymgenie/core/services/notification_service.dart';
import 'package:gymgenie/features/workout/data/local_log_store.dart';
import 'package:gymgenie/features/workout/data/log_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const ProviderScope(child: GymGenieApp()));

  // Run non-critical background services without blocking the main UI startup
  _initServicesAndSync();
}

Future<void> _initServicesAndSync() async {
  try {
    await LocalLogStore().database;
    await LogRepository(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
      LocalLogStore(),
    ).syncPendingLogs();
  } catch (e) {
    debugPrint('Local database or sync pending logs failed: $e');
  }

  try {
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.requestPermissions();
  } catch (e) {
    debugPrint('Notification service initialization failed: $e');
  }
}
