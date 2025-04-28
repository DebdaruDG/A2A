import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart' as record;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'chat_model.dart'; // Assuming ChatMessage is defined here
import 'package:intl/intl.dart';

class ChatState with ChangeNotifier {
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  final record.AudioRecorder _audioRecorder = record.AudioRecorder();
  WebSocketChannel? _channel;
  final AudioPlayer _sharedPlayer = AudioPlayer();
  final StringBuffer _audioBuffer = StringBuffer();

  List<ChatMessage> _chats = [];
  List<ChatMessage> get chats => _chats;

  Uint8List? _currentPlayingAudio;
  Duration? _currentPosition;
  Map<Uint8List, Duration> _pausedPositions = {};

  AudioPlayer get sharedPlayer => _sharedPlayer;
  bool get isRecording => _isRecording;
  bool get isLoading => _isLoading;
  bool get isPlaying => _isPlaying;

  ChatState() {
    connectWebSocket();

    _sharedPlayer.onPlayerComplete.listen((event) {
      _isPlaying = false;
      _currentPlayingAudio = null;
      notifyListeners();
    });

    _sharedPlayer.onPositionChanged.listen((pos) {
      _currentPosition = pos;
      notifyListeners();
    });
  }

  void connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse(
        'wss://pu6niet7nl.execute-api.ap-south-1.amazonaws.com/production/',
      ),
    );
  }

  Future<void> sendText(String text) async {
    _chats.add(ChatMessage(text: text, isUser: true));
    _chats.add(ChatMessage(isUser: false, isLoading: true));
    _isLoading = true;
    notifyListeners();

    final event = {
      "action": "TextCompletionOpenaiVoice",
      "text": text,
      "use_assistant": false,
    };
    _channel?.sink.add(jsonEncode(event));

    _channel?.stream.listen(
      (message) {
        _handleResponse(message);
      },
      onError: (error) {
        developer.log("WebSocket Error: $error");
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> sendAudio(Uint8List audioData) async {
    try {
      _isLoading = true;
      notifyListeners();

      developer.log('audioBytesInput :- ${audioData.length} bytes');
      _chats.add(ChatMessage(isUser: true, audioBytes: audioData));
      notifyListeners();

      String base64Audio = base64Encode(audioData);

      final event = {"action": "PunjabiChatbot", "audio": base64Audio};
      _channel?.sink.add(jsonEncode(event));
    } catch (err) {
      developer.log('audioBytesInput error :- $err');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleResponse(dynamic message) {
    try {
      if (message is String && message.contains("Sent WebSocket response")) {
        return;
      }

      _audioBuffer.write(message);
      final fullMessage = _audioBuffer.toString();
      final decoded = jsonDecode(fullMessage);

      if (decoded['response'] != null || decoded['audio'] != null) {
        _chats.removeWhere((m) => m.isLoading);
        if (decoded['response'] != null) {
          _chats.add(ChatMessage(text: decoded['response'], isUser: false));
        }

        if (decoded['audio'] != null) {
          final bytes = base64Decode(decoded['audio']);
          _chats.add(
            ChatMessage(audioBytes: Uint8List.fromList(bytes), isUser: false),
          );
        }

        _audioBuffer.clear();
        _isLoading = false;
        notifyListeners();
      }
    } catch (e) {
      if (e is FormatException) return;
      _audioBuffer.clear();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayPause(Uint8List audioBytes) async {
    if (_currentPlayingAudio != null && _currentPlayingAudio != audioBytes) {
      await _sharedPlayer.stop();
      _pausedPositions[_currentPlayingAudio!] =
          _currentPosition ?? Duration.zero;
    }

    if (_isPlaying && _currentPlayingAudio == audioBytes) {
      await _sharedPlayer.pause();
      _pausedPositions[audioBytes] = _currentPosition ?? Duration.zero;
      _isPlaying = false;
    } else {
      if (_currentPlayingAudio != audioBytes) {
        await _sharedPlayer.setSource(BytesSource(audioBytes));
        await _sharedPlayer.resume();
        _currentPlayingAudio = audioBytes;
        _isPlaying = true;
      } else {
        await _sharedPlayer.resume();
        _isPlaying = true;
      }

      final resumePosition = _pausedPositions[audioBytes];
      if (resumePosition != null) {
        await _sharedPlayer.seek(resumePosition);
      }
      notifyListeners();
    }
  }

  Future<void> startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        _isRecording = true;
        notifyListeners();

        if (kIsWeb) {
          await _audioRecorder.start(
            const record.RecordConfig(
              encoder: record.AudioEncoder.wav,
              sampleRate: 44100,
              numChannels: 1,
            ),
            path: '', // Empty path for in-memory recording
          );
          developer.log('Recording started (memory mode) for Web');
        } else {
          developer.log('Recording not implemented for non-web platforms');
        }
      } else {
        developer.log('Microphone permission denied');
      }
    } catch (err) {
      developer.log('Error starting recording: $err');
      _isRecording = false;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    try {
      if (_isRecording) {
        _isRecording = false;
        notifyListeners();

        final blobUrl = await _audioRecorder.stop();
        developer.log('Blob URL: $blobUrl');
        if (blobUrl != null && blobUrl.isNotEmpty) {
          try {
            final response = await http.get(Uri.parse(blobUrl));
            if (response.statusCode == 200) {
              final audioData = response.bodyBytes;
              developer.log(
                'Recording captured as bytes: ${audioData.length} bytes',
              );
              await sendAudio(audioData);
            } else {
              developer.log('HTTP request failed: ${response.statusCode}');
            }
          } catch (httpErr) {
            developer.log('HTTP request error: $httpErr');
          }
        } else {
          developer.log('No audio data captured: Blob URL is null or empty');
        }
      }
    } catch (err) {
      developer.log('Error stopping recording: $err');
      _isRecording = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _audioRecorder.dispose();
    _sharedPlayer.dispose();
    super.dispose();
  }
}
