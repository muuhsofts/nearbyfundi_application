// lib/services/voice_recorder_service.dart

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal();

  FlutterSoundRecorder? _recorder;
  bool _isRecording = false;
  String? _recordingPath;

  Future<void> init() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  Future<bool> startRecording() async {
    if (_recorder == null) await init();

    if (_recorder!.isRecording) return false;

    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder!.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
        bitRate: 128000,
        sampleRate: 16000,
      );

      _isRecording = true;
      _recordingPath = path;
      return true;
    } catch (e) {
      print('Failed to start recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    if (_recorder == null || !_recorder!.isRecording) return null;

    try {
      final path = await _recorder!.stopRecorder();
      _isRecording = false;
      return path;
    } catch (e) {
      print('Failed to stop recording: $e');
      return null;
    }
  }

  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;

  void dispose() {
    _recorder?.closeRecorder();
  }
}