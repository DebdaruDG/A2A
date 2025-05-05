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
import 'package:flutter/services.dart' show rootBundle;
import 'chat_model.dart';
import 'dart:html' as html;
import 'models/punjabi_audio.dart';

class ChatState with ChangeNotifier {
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isReceivingAudioChunks = false;
  bool _isPlaying = false;
  final record.AudioRecorder _audioRecorder = record.AudioRecorder();
  WebSocketChannel? _channel;
  final AudioPlayer _sharedPlayer = AudioPlayer();
  final StringBuffer _audioBuffer = StringBuffer();
  Timer? _keepAliveTimer;

  final List<ChatMessage> _chats = [];
  List<ChatMessage> get chats => _chats;

  Uint8List? _currentPlayingAudio;
  Duration? _currentPosition;
  final Map<Uint8List, Duration> _pausedPositions = {};

  AudioPlayer get sharedPlayer => _sharedPlayer;
  bool get isRecording => _isRecording;
  bool get isLoading => _isLoading;
  bool get isReceivingAudioChunks => _isReceivingAudioChunks;
  bool get isPlaying => _isPlaying;

  final Map<int, String> _chunkedAudioMap = {};

  ChatState() {
    if (_channel == null) {
      connectWebSocket();
    }

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
    _channel?.sink.close();
    _keepAliveTimer?.cancel();
    _channel = WebSocketChannel.connect(
      Uri.parse(
        'wss://pu6niet7nl.execute-api.ap-south-1.amazonaws.com/production/',
      ),
    );
    developer.log('WebSocket connected');

    _keepAliveTimer = Timer.periodic(Duration(minutes: 15), (timer) {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({"action": "ping"}));
        developer.log('Sent keep-alive ping');
      }
    });

    _channel?.stream.listen(
      (message) {
        _handleResponse(message);
      },
      onError: (error) {
        developer.log('WebSocket Error: $error');
        _isLoading = false;
        _isReceivingAudioChunks = false;
        notifyListeners();
      },
      onDone: () {
        developer.log(
          'WebSocket closed with code: ${_channel?.closeCode}, reason: ${_channel?.closeReason}',
        );
        _channel = null;
        _keepAliveTimer?.cancel();
        Future.delayed(Duration(seconds: 5), () {
          if (_channel == null) {
            connectWebSocket();
          }
        });
      },
    );
  }

  Future<void> sendText(String text) async {
    try {
      _chats.add(ChatMessage(text: text, isUser: true));
      _chats.add(ChatMessage(isUser: false, isLoading: true));
      _isLoading = true;
      notifyListeners();

      final event = {
        "action": "TextCompletionOpenaiVoice",
        "text": text,
        "use_assistant": false,
      };

      if (_channel == null) {
        developer.log('WebSocket channel is null or closed for text event');
        connectWebSocket();
        await Future.delayed(Duration(milliseconds: 500));
      }

      if (_channel != null) {
        _channel!.sink.add(jsonEncode(event));
        developer.log('Text event sent successfully');
      } else {
        throw Exception('Failed to reconnect WebSocket for text event');
      }
    } catch (err) {
      developer.log('sendText error: $err');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendAudio(Uint8List audioData) async {
    try {
      _isLoading = true; // Trigger loading state immediately
      notifyListeners();

      final audioDataSizeBytes = audioData.length.toDouble();
      developer.log(
        'audioBytesInput size: ${audioDataSizeBytes.toStringAsFixed(3)} bytes',
      );

      _chats.add(ChatMessage(isUser: true, audioBytes: audioData));
      _chats.add(ChatMessage(isUser: false, isLoading: true)); // Add loader
      notifyListeners();

      String base64Audio = base64Encode(audioData);

      final base64SizeBytes = base64Audio.length;
      final base64SizeKB = base64SizeBytes / 1024.0;
      developer.log(
        'base64Audio total size: ${base64SizeKB.toStringAsFixed(3)} KB',
      );

      await sendAudioChunks(base64Audio);

      developer.log(
        'All audio chunks sent successfully, awaiting server response',
      );
    } catch (err) {
      developer.log('audioBytesInput error: $err');
      _chats.removeWhere((m) => m.isLoading);
      _chats.add(ChatMessage(text: 'Error sending audio.', isUser: false));
    } finally {
      // Do not reset _isLoading here; wait for response or error in _handleResponse
      notifyListeners();
    }
  }

  Future<void> sendAudioChunks(String base64Audio) async {
    const int chunkSizeBytes = 20 * 1024;

    final int base64SizeBytes = base64Audio.length;
    final int totalChunks = (base64SizeBytes / chunkSizeBytes).ceil();
    developer.log('Splitting into $totalChunks chunk(s) of ~20 KB each');

    for (int i = 0; i < totalChunks; i++) {
      final int start = i * chunkSizeBytes;
      final int end =
          start + chunkSizeBytes < base64SizeBytes
              ? start + chunkSizeBytes
              : base64SizeBytes;

      final String chunk = base64Audio.substring(start, end);
      final chunkSizeBytesActual = chunk.length;
      final chunkSizeKB = chunkSizeBytesActual / 1024.0;

      developer.log(
        'Chunk ${i + 1}/$totalChunks size: ${chunkSizeKB.toStringAsFixed(3)} KB ($chunkSizeBytesActual bytes)',
      );

      final event = {
        "action": "PunjabiChatbot",
        "chunkIndex": i,
        "totalChunks": totalChunks,
        "audio": chunk,
      };
      final eventJson = jsonEncode(event);

      developer.log(
        'WebSocket event size (chunk ${i + 1}): ${(eventJson.length / 1024.0).toStringAsFixed(3)} KB (${eventJson.length} bytes)',
      );

      if (_channel != null) {
        _channel!.sink.add(eventJson);
        developer.log(
          'WebSocket chunk ${i + 1}/$totalChunks sent successfully',
        );
      } else {
        throw Exception('Failed to reconnect WebSocket for chunk ${i + 1}');
      }

      await Future.delayed(Duration(milliseconds: 50));
    }
  }

  Future<void> testWebSocket() async {
    try {
      final testEvent = {
        "action": "PunjabiChatbot",
        "audio": "test",
        "chunkIndex": 0,
        "totalChunks": 1,
      };
      if (_channel == null) {
        developer.log('WebSocket channel is null or closed for test event');
        connectWebSocket();
        await Future.delayed(Duration(milliseconds: 500));
      }
      if (_channel != null) {
        _channel!.sink.add(jsonEncode(testEvent));
        developer.log('Test event sent successfully');
      } else {
        throw Exception('Failed to reconnect WebSocket for test event');
      }
    } catch (err) {
      developer.log('testWebSocket error: $err');
    }
  }

  void _handleResponse(dynamic message) {
    try {
      developer.log('Received WebSocket message: $message');

      if (message is String && message.contains("Sent WebSocket response")) {
        developer.log('Received acknowledgment: $message');
        return;
      }

      _audioBuffer.write(message);
      final fullMessage = _audioBuffer.toString();
      developer.log('Current buffer: $fullMessage');

      final decoded = jsonDecode(fullMessage);
      developer.log('Parsed WebSocket response: $decoded');

      if (decoded['action'] == "PunjabiChatbot" && decoded['audio'] != null) {
        int chunkIndex = decoded['chunkIndex'];
        int totalChunks = decoded['totalChunks'];
        String base64Chunk = decoded['audio'];

        developer.log('Received chunk $chunkIndex of $totalChunks');

        _chunkedAudioMap[chunkIndex] = base64Chunk;

        if (!_isReceivingAudioChunks) {
          _isReceivingAudioChunks = true;
          notifyListeners();
        }

        if (_chunkedAudioMap.length == totalChunks) {
          developer.log('All audio chunks received. Reconstructing...');

          StringBuffer combined = StringBuffer();
          for (int i = 0; i < totalChunks; i++) {
            if (_chunkedAudioMap.containsKey(i)) {
              combined.write(_chunkedAudioMap[i]);
            } else {
              developer.log('Missing chunk at index $i');
              return;
            }
          }

          try {
            Uint8List audioBytes = base64Decode(combined.toString());
            developer.log('Decoded full audio length: ${audioBytes.length}');

            _chats.removeWhere((m) => m.isLoading);
            _chats.add(ChatMessage(audioBytes: audioBytes, isUser: false));

            if (kIsWeb) {
              final blob = html.Blob([audioBytes]);
              final url = html.Url.createObjectUrlFromBlob(blob);
              final audioElement =
                  html.AudioElement()
                    ..src = url
                    ..autoplay = true;
              html.document.body!.append(audioElement);
              developer.log('Audio playback started');
            }

            _chunkedAudioMap.clear();
            _isReceivingAudioChunks = false;
            _isLoading = false; // Reset loading state
            notifyListeners();
          } catch (e) {
            developer.log('Error decoding concatenated audio: $e');
            _chats.removeWhere((m) => m.isLoading);
            _chats.add(
              ChatMessage(text: 'Error decoding audio stream.', isUser: false),
            );
            _isReceivingAudioChunks = false;
            _isLoading = false;
            notifyListeners();
          }
        }

        _audioBuffer.clear();
        return;
      }

      PunjabiBotResponse? punjabiResponse = PunjabiBotResponse.fromJson(
        decoded,
      );
      _chats.removeWhere((m) => m.isLoading);

      if ((punjabiResponse.audioChunks ?? []).isNotEmpty) {
        for (AudioChunks item in (punjabiResponse.audioChunks ?? [])) {
          final bytes = base64Decode(item.data ?? '');
          _chats.add(
            ChatMessage(audioBytes: Uint8List.fromList(bytes), isUser: false),
          );
        }
      }

      if (decoded['response'] != null) {
        _chats.add(ChatMessage(text: decoded['response'], isUser: false));
      }

      if (decoded['audio'] != null) {
        try {
          final bytes = base64Decode(decoded['audio']);
          _chats.add(
            ChatMessage(audioBytes: Uint8List.fromList(bytes), isUser: false),
          );
        } catch (e) {
          developer.log('Error decoding single audio: $e');
          _chats.add(
            ChatMessage(text: 'Error: Failed to decode audio', isUser: false),
          );
        }
      }

      if (decoded['error'] != null) {
        _chats.add(
          ChatMessage(text: 'Error: ${decoded['error']}', isUser: false),
        );
      }

      _audioBuffer.clear();
      _isLoading = false;
      _isReceivingAudioChunks = false;
      notifyListeners();
    } catch (e) {
      if (e is FormatException) {
        developer.log('Partial message received, buffering: $e');
        return;
      }
      developer.log('Error processing WebSocket response: $e');
      _audioBuffer.clear();
      _isLoading = false;
      _isReceivingAudioChunks = false;
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
    }
    notifyListeners();
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
              sampleRate: 16000,
              numChannels: 1,
            ),
            path: '',
          );
          developer.log('Recording started (WAV, memory mode) for Web');
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

  Future<Uint8List> fetchAssetAudioUint8ListData(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List audioData = data.buffer.asUint8List();
    return audioData;
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

              if (kIsWeb) {
                final blob = html.Blob([audioData]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                html.Url.revokeObjectUrl(url);
                developer.log('Saved audio for debugging');
              }

              final punjabiPrompt = 'punjabi_voice.wav';
              final compressedPunjabiPrompt = 'punjabi_voice_compressed.wav';
              final assetAudioData = await fetchAssetAudioUint8ListData(
                'assets/$punjabiPrompt',
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
    _keepAliveTimer?.cancel();
    _channel?.sink.close();
    _audioRecorder.dispose();
    _sharedPlayer.dispose();
    super.dispose();
  }
}
