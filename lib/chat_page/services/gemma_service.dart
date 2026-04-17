// services/gemma_service.dart - Further Optimized Version
import 'dart:async';
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';

import '../models/message_models.dart';
import '../../download_page/services/download_state_manager.dart';

/// Singleton service for Google's Gemma AI model - optimized for performance and memory efficiency
/// Handles model loading, chat sessions, and streaming responses with minimal overhead
class GemmaService {
  GemmaService._internal();
  static final GemmaService instance = GemmaService._internal();

  final _gemma = FlutterGemmaPlugin.instance;
  InferenceModel? _model;
  InferenceChat? _chat;
  bool _initialised = false;

  /// Initialize model with selected backend (CPU/GPU) - idempotent operation
  /// Uses local model file if available to avoid redundant downloads
  Future<void> init(PreferredBackend backend) async {
    if (_initialised) return; // Prevent duplicate initialization

    try {
      final dir = await getApplicationDocumentsDirectory();
      final defaultPath = '${dir.path}/gemma-3n-E2B-it-int4.task';
      final activePath = await DownloadStateManager.getActiveModelPath();
      final path = activePath ?? defaultPath;

      final modelFile = File(path);

      // Step 1: Check if file exists
      if (!modelFile.existsSync()) {
        throw Exception(
          'Model file not found at $path. Please ensure the model is downloaded or imported correctly.',
        );
      }

      // Step 2: Validate file size (Gemma 2B IT models are typically > 1GB)
      final fileSize = await modelFile.length();
      if (fileSize < 50 * 1024 * 1024) {
        // Absolute minimum 50MB for any valid LLM task file
        throw Exception(
          'The model file at $path appears to be incomplete (Size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB). A full Gemma 2B model is typically 1.2GB - 1.5GB.',
        );
      }

      // Step 3: Point plugin to the model path
      // ignore: deprecated_member_use
      await _gemma.modelManager.setModelPath(path);

      // Step 4: Create model instance with vision support
      // This is the most likely step to fail if the model is incompatible or corrupt
      _model ??= await _gemma
          .createModel(
            preferredBackend: backend,
            modelType: ModelType.gemmaIt, // Instruction-tuned variant
            supportImage: true, // Enable vision capabilities
            maxTokens: 8192, // Context window size
            maxNumImages: 1, // Single image per message
          )
          .timeout(
            const Duration(seconds: 45),
            onTimeout: () => throw Exception(
              'Model loading timed out. The file might be too large for your device\'s memory or corrupted.',
            ),
          );

      // Step 5: Create persistent chat session
      _chat ??= await _model!.createChat(
        randomSeed: 1,
        temperature: 1,
        topK: 64,
        topP: 0.95,
        supportImage: true,
        tokenBuffer: 512,
      );

      _initialised = true;
    } catch (e) {
      _initialised = false;
      _model = null;
      _chat = null;
      rethrow; // Re-throw to be caught by BootstrapManager
    }
  }

  /// Provides detailed performance statistics and error handling
  Future<void> sendWithStreaming({
    required String text,
    File? image,
    required Function(String) onToken,
    required Function(MessageStats) onComplete,
  }) async {
    if (!_initialised) {
      throw Exception('GemmaService not initialized');
    }
    if (_chat == null) {
      throw Exception('Chat not available');
    }

    // Performance tracking variables
    final startTime = DateTime.now();
    DateTime? firstTokenTime;
    int tokenCount = 0;
    final responseBuffer = StringBuffer();

    // Add user message with optional image to chat history
    if (image != null) {
      final bytes = await image.readAsBytes();
      await _chat!.addQuery(
        Message.withImage(text: text, imageBytes: bytes, isUser: true),
      );
    } else {
      await _chat!.addQuery(Message.text(text: text, isUser: true));
    }

    final completer = Completer<void>();
    bool streamStarted = false;

    // Process streaming response with performance metrics
    _chat!.generateChatResponseAsync().listen(
      (ModelResponse res) {
        if (!streamStarted) {
          streamStarted = true;
        }

        if (res is TextResponse) {
          // Record timing for first token (important latency metric)
          firstTokenTime ??= DateTime.now();
          tokenCount++;
          responseBuffer.write(res.token);

          // Forward token to caller (swallow any callback errors)
          try {
            onToken(res.token);
          } catch (_) {
            // Ignore callback errors - caller's responsibility
          }
        }
        // Note: Non-text responses (metadata, etc.) are ignored
      },
      onDone: () {
        final endTime = DateTime.now();

        // Calculate comprehensive performance statistics
        final stats = MessageStats(
          timeToFirstToken: firstTokenTime != null
              ? firstTokenTime!.difference(startTime).inMilliseconds / 1000.0
              : null,
          totalLatency: endTime.difference(startTime).inMilliseconds / 1000.0,
          tokenCount: tokenCount,
          // Tokens per second during initial processing
          prefillSpeed: firstTokenTime != null && tokenCount > 0
              ? 1000.0 / firstTokenTime!.difference(startTime).inMilliseconds
              : null,
          // Tokens per second during generation (excluding first token)
          decodeSpeed: firstTokenTime != null && tokenCount > 1
              ? (tokenCount - 1) *
                    1000.0 /
                    endTime.difference(firstTokenTime!).inMilliseconds
              : null,
        );

        // Deliver final statistics (ignore callback errors)
        try {
          onComplete(stats);
        } catch (_) {
          // Silent fallback
        }

        completer.complete();
      },
      onError: (error) {
        completer.completeError(error);
      },
    );

    await completer.future;
  }

  /// Fast chat reset - clears conversation history but keeps model loaded in memory
  /// Much faster than full reinitialization for "new chat" functionality
  Future<void> resetChatSession() async {
    if (!_initialised) return;
    await _chat?.clearHistory();
  }

  /// Complete cleanup - disposes model and resets all state
  /// Use when switching backends or completely shutting down
  Future<void> dispose() async {
    await _model?.close();
    try {
      // ignore: avoid_dynamic_calls
      await (_gemma.modelManager as dynamic).deleteModel();
    } catch (_) {}
    _model = null;
    _chat = null;
    _initialised = false;
  }
}
