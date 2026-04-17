// main.dart
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:gemma_chat/download_page/model_download_page.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Top-level callback function for handling download progress updates.
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  final SendPort? send = IsolateNameServer.lookupPortByName(
    'downloader_send_port',
  );
  send?.send([id, status, progress]);
}

/// App entry point - initializes all required services before starting the UI.
Future<void> main() async {
  // Ensure Flutter binding is initialized before calling platform-specific code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AI model plugin
  try {
    await FlutterGemma.initialize();
  } catch (e) {
    debugPrint('FlutterGemma initialization error: $e');
  }

  // Initialize the flutter_downloader plugin for background downloads
  await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: false);

  // Register our callback function so the background downloader can call it
  FlutterDownloader.registerCallback(downloadCallback);

  // This prevents the device from sleeping
  await WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemma Vision',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const ModelDownloadPage(),
    );
  }
}
