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
import 'dart:html' as html;

import 'models/audio_completion.dart';
import 'models/punjabi_audio.dart'; // For saving audio on web

class ChatState with ChangeNotifier {
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  final record.AudioRecorder _audioRecorder = record.AudioRecorder();
  WebSocketChannel? _channel;
  final AudioPlayer _sharedPlayer = AudioPlayer();
  final StringBuffer _audioBuffer = StringBuffer();
  Timer? _keepAliveTimer;

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

    // Set up keep-alive ping (test disabling if Internal server error persists)
    _keepAliveTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode({"action": "ping"}));
        developer.log('Sent keep-alive ping');
      }
    });

    _channel?.stream.listen(
      (message) {
        developer.log('Received WebSocket message: $message');
        _handleResponse(message);
      },
      onError: (error) {
        developer.log('WebSocket Error: $error');
        _isLoading = false;
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
      _isLoading = true;
      notifyListeners();

      // Log size of audioData in bytes (to 3 decimal places)
      final audioDataSizeBytes = audioData.length.toDouble();
      developer.log(
        'audioBytesInput size: ${audioDataSizeBytes.toStringAsFixed(3)} bytes',
      );

      // Add audio data to chats
      _chats.add(ChatMessage(isUser: true, audioBytes: audioData));
      notifyListeners();

      // Encode to base64
      String base64Audio = base64Encode(audioData);

      // Log total size of base64Audio in kilobytes (to 3 decimal places)
      final base64SizeBytes = base64Audio.length; // Bytes in UTF-8
      final base64SizeKB = base64SizeBytes / 1024.0; // Convert to KB
      developer.log(
        'base64Audio total size: ${base64SizeKB.toStringAsFixed(3)} KB',
      );

      // Send chunks over WebSocket
      await sendAudioChunks(base64Audio);

      developer.log(
        'All audio chunks sent successfully, awaiting server response',
      );
    } catch (err) {
      developer.log('audioBytesInput error: $err');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Future<void> sendAudioChunks(String base64Audio) async {
  //   // Define chunk size to match backend (80,000 characters)
  //   const int chunkSize = 30000;

  //   // Calculate number of chunks
  //   final int base64Length = base64Audio.length;
  //   final int totalChunks = (base64Length / chunkSize).ceil();
  //   developer.log(
  //     'Splitting into $totalChunks chunk(s) of up to 80,000 characters each',
  //   );

  //   // Send chunks over WebSocket
  //   for (int i = 0; i < totalChunks; i++) {
  //     // Calculate start and end indices for the chunk
  //     final int start = i * chunkSize;
  //     final int end =
  //         (start + chunkSize < base64Length) ? start + chunkSize : base64Length;

  //     // Extract chunk
  //     final String chunk = base64Audio.substring(start, end);
  //     final chunkSizeBytes = chunk.length;
  //     final chunkSizeKB = chunkSizeBytes / 1024.0;

  //     // Log chunk details
  //     developer.log(
  //       'Chunk ${i + 1}/$totalChunks size: ${chunkSizeKB.toStringAsFixed(3)} KB ($chunkSizeBytes bytes)',
  //     );

  //     // Prepare WebSocket event
  //     final event = {
  //       "action": "AudioCompletionOpenaiVoice",
  //       "audio": chunk,
  //       // "chunkIndex": i,
  //       // "totalChunks": totalChunks,
  //     };
  //     final eventJson = jsonEncode(event);

  //     // Log event size
  //     final eventSizeBytes = eventJson.length;
  //     developer.log(
  //       'WebSocket event size (chunk ${i + 1}): ${(eventSizeBytes / 1024.0).toStringAsFixed(3)} KB ($eventSizeBytes bytes)',
  //     );

  //     // Send over WebSocket
  //     if (_channel == null) {
  //       developer.log('WebSocket channel is null or closed for chunk ${i + 1}');
  //       connectWebSocket();
  //       await Future.delayed(
  //         Duration(milliseconds: 500),
  //       ); // Wait for connection
  //     }

  //     if (_channel != null) {
  //       _channel!.sink.add(eventJson);
  //       developer.log(
  //         'WebSocket chunk ${i + 1}/$totalChunks sent successfully',
  //       );
  //     } else {
  //       throw Exception('Failed to reconnect WebSocket for chunk ${i + 1}');
  //     }
  //   }
  // }

  Future<void> sendAudioChunks(String base64Audio) async {
    // Define chunk size (20 KB in bytes to stay under 20 KB limit)
    const int chunkSizeBytes = 20 * 1024; // 20 KB

    // Calculate number of chunks
    final int base64SizeBytes = base64Audio.length;
    final int totalChunks = (base64SizeBytes / chunkSizeBytes).ceil();
    developer.log('Splitting into $totalChunks chunk(s) of ~20 KB each');
    // final List<String> audioChunks

    // Send chunks over WebSocket
    for (int i = 0; i < totalChunks; i++) {
      // Calculate start and end indices for the chunk
      final int start = i * chunkSizeBytes;
      final int end =
          start + chunkSizeBytes < base64SizeBytes
              ? start + chunkSizeBytes
              : base64SizeBytes;

      // Extract chunk
      final String chunk = base64Audio.substring(start, end);
      final chunkSizeBytesActual = chunk.length;
      final chunkSizeKB = chunkSizeBytesActual / 1024.0;

      // Log chunk details
      developer.log(
        'Chunk ${i + 1}/$totalChunks size: ${chunkSizeKB.toStringAsFixed(3)} KB (${chunkSizeBytesActual} bytes)',
      );

      // Prepare WebSocket event
      final event = {"action": "PunjabiChatbot", "audio": chunk};
      final eventJson = jsonEncode(event);

      // Log event size
      final eventSizeBytes = eventJson.length;
      developer.log(
        'WebSocket event size (chunk ${i + 1}): ${(eventSizeBytes / 1024.0).toStringAsFixed(3)} KB ($eventSizeBytes bytes)',
      );

      // Send over WebSocket
      if (_channel == null) {
        developer.log('WebSocket channel is null or closed for chunk ${i + 1}');
        connectWebSocket();
        await Future.delayed(
          Duration(milliseconds: 500),
        ); // Wait for connection
      }

      if (_channel != null) {
        _channel!.sink.add(
          eventJson,
          // event,
        );
        developer.log(
          'WebSocket chunk ${i + 1}/$totalChunks sent successfully',
        );
      } else {
        throw Exception('Failed to reconnect WebSocket for chunk ${i + 1}');
      }
    }
  }

  // Test function to send a simple message and check for response
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

      // Handle acknowledgment messages
      if (message is String && message.contains("Sent WebSocket response")) {
        developer.log('Received acknowledgment: $message');
        return;
      }

      // Buffer the message
      _audioBuffer.write(message);
      final fullMessage = _audioBuffer.toString();
      developer.log('Current buffer: $fullMessage');

      // Attempt to parse JSON
      final decoded = jsonDecode(fullMessage);
      developer.log('Parsed WebSocket response: $decoded');
      developer.log(
        'Parsed WebSocket response - runtimeType : ${decoded.runtimeType}',
      );

      PunjabiBotResponse? punjabiResponse = PunjabiBotResponse.fromJson(
        decoded,
      );

      developer.log('reposnse body - ${punjabiResponse.audioChunks}');
      // Process the response
      _chats.removeWhere((m) => m.isLoading);

      if ((punjabiResponse.audioChunks ?? []).isNotEmpty) {
        // Punjabi Chat bot logic :-
        for (AudioChunks item in (punjabiResponse.audioChunks ?? [])) {
          final bytes = base64Decode(item.data ?? '');
          developer.log('Decoded audio bytes: ${bytes.length}');
          _chats.add(
            ChatMessage(audioBytes: Uint8List.fromList(bytes), isUser: false),
          );
        }
      }

      if (decoded['response'] != null) {
        developer.log('Response text: ${decoded['response']}');
        _chats.add(ChatMessage(text: decoded['response'], isUser: false));
      }
      if (decoded['audio'] != null) {
        developer.log(
          'Single audio received, base64 length: ${decoded['audio'].length}',
        );
        try {
          final bytes = base64Decode(decoded['audio']);
          developer.log('Decoded audio bytes: ${bytes.length}');
          _chats.add(
            ChatMessage(audioBytes: Uint8List.fromList(bytes), isUser: false),
          );
        } catch (e) {
          developer.log('Error decoding audio: $e');
          _chats.add(
            ChatMessage(text: 'Error: Failed to decode audio', isUser: false),
          );
        }
      }
      if (decoded['error'] != null) {
        developer.log('Server error: ${decoded['error']}');
        _chats.add(
          ChatMessage(text: 'Error: ${decoded['error']}', isUser: false),
        );
      }
      if (decoded['message'] != null &&
          !decoded['message'].toString().toLowerCase().contains(
            'internal server error',
          )) {
        developer.log('Internal server error: ${decoded['message']}');
        _chats.add(ChatMessage(text: 'Internal server error', isUser: false));
      }

      // Clear buffer after processing
      _audioBuffer.clear();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (e is FormatException) {
        developer.log('Partial message received, buffering: $e');
        // Check if buffer contains complete JSON objects
        final buffer = _audioBuffer.toString();
        int lastValidJsonEnd = 0;
        try {
          while (lastValidJsonEnd < buffer.length) {
            final nextJson = buffer.substring(lastValidJsonEnd);
            final decoded = jsonDecode(nextJson);
            developer.log('Parsed partial WebSocket response: $decoded');
            _chats.removeWhere((m) => m.isLoading);
            if (decoded['response'] != null) {
              developer.log('Response text: ${decoded['response']}');
              _chats.add(ChatMessage(text: decoded['response'], isUser: false));
            }
            if (decoded['audio'] != null) {
              developer.log(
                'Single audio received, base64 length: ${decoded['audio'].length}',
              );
              try {
                final bytes = base64Decode(decoded['audio']);
                developer.log('Decoded audio bytes: ${bytes.length}');
                _chats.add(
                  ChatMessage(
                    audioBytes: Uint8List.fromList(bytes),
                    isUser: false,
                  ),
                );

                // Save received audio for debugging
                if (kIsWeb) {
                  final blob = html.Blob([bytes]);
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final anchor =
                      html.AnchorElement(href: url)
                        ..setAttribute('download', 'received_audio.wav')
                        ..click();
                  html.Url.revokeObjectUrl(url);
                  developer.log('Saved received audio for debugging');
                }
              } catch (e) {
                developer.log('Error decoding audio: $e');
                _chats.add(
                  ChatMessage(
                    text: 'Error: Failed to decode audio',
                    isUser: false,
                  ),
                );
              }
            }
            if (decoded['audio_chunks'] != null &&
                decoded['audio_chunks'] is List) {
              developer.log(
                'Audio chunks received, count: ${decoded['audio_chunks'].length}',
              );
              try {
                final List<dynamic> chunks = decoded['audio_chunks'];
                final StringBuffer base64Buffer = StringBuffer();
                for (int i = 0; i < chunks.length; i++) {
                  if (chunks[i] is String) {
                    developer.log(
                      'Processing chunk ${i + 1}/${chunks.length}, length: ${chunks[i].length}',
                    );
                    base64Buffer.write(chunks[i]);
                  } else {
                    developer.log('Invalid chunk ${i + 1}: not a string');
                  }
                }
                final base64Audio = base64Buffer.toString();
                developer.log(
                  'Concatenated base64 audio length: ${base64Audio.length}',
                );
                final bytes = base64Decode(base64Audio);
                developer.log('Decoded audio bytes: ${bytes.length}');
                _chats.add(
                  ChatMessage(
                    audioBytes: Uint8List.fromList(bytes),
                    isUser: false,
                  ),
                );

                // Save received audio for debugging
                if (kIsWeb) {
                  final blob = html.Blob([bytes]);
                  final url = html.Url.createObjectUrlFromBlob(blob);
                  final anchor =
                      html.AnchorElement(href: url)
                        ..setAttribute('download', 'received_audio.wav')
                        ..click();
                  html.Url.revokeObjectUrl(url);
                  developer.log('Saved received audio for debugging');
                }
              } catch (e) {
                developer.log('Error processing audio chunks: $e');
                _chats.add(
                  ChatMessage(
                    text: 'Error: Failed to process audio chunks',
                    isUser: false,
                  ),
                );
              }
            }
            if (decoded['error'] != null) {
              developer.log('Server error: ${decoded['error']}');
              _chats.add(
                ChatMessage(text: 'Error: ${decoded['error']}', isUser: false),
              );
            }
            if (decoded['message'] != null &&
                decoded['message'].contains('Internal server error')) {
              developer.log('Internal server error: ${decoded['message']}');
              _chats.add(
                ChatMessage(text: 'Internal server error', isUser: false),
              );
            }
            lastValidJsonEnd += jsonEncode(decoded).length;
            _isLoading = false;
            notifyListeners();
          }
          // Clear processed portion of buffer
          _audioBuffer.clear();
          _audioBuffer.write(buffer.substring(lastValidJsonEnd));
        } catch (innerError) {
          developer.log('Error parsing partial buffer: $innerError');
          // Keep buffering until complete JSON is received
        }
        return;
      }
      developer.log('Error processing WebSocket response: $e');
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
              sampleRate: 16000, // 16 kHz for speech recognition
              numChannels: 1,
            ),
            path: '', // Empty path for in-memory recording
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

              // Save audio for debugging
              if (kIsWeb) {
                final blob = html.Blob([audioData]);
                final url = html.Url.createObjectUrlFromBlob(blob);
                // final anchor =
                //     html.AnchorElement(href: url)
                //       ..setAttribute('download', 'recorded_audio.wav')
                //       ..click();
                html.Url.revokeObjectUrl(url);
                developer.log('Saved audio for debugging');
              }

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
