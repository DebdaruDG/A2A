import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart' as record;
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatState with ChangeNotifier {
  String _responseAudio = '';
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  final List<String> _messages = [];
  late final record.AudioRecorder audioRecorder;
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebSocketChannel? _channel;
  final StringBuffer _audioBuffer = StringBuffer();

  AudioPlayer get audioPlayer => _audioPlayer;
  String get responseAudio => _responseAudio;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  List<String> get messages => _messages;

  ChatState() {
    audioRecorder = record.AudioRecorder();
    connectWebSocket();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        _isPlaying = false;
        notifyListeners();
      }
    });
  }

  void connectWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse(
        'wss://pu6niet7nl.execute-api.ap-south-1.amazonaws.com/production/',
      ),
    );
  }

  Future<void> startRecording() async {
    if (await audioRecorder.hasPermission()) {
      _isRecording = true;
      notifyListeners();
      await audioRecorder.start(
        const record.RecordConfig(
          encoder: record.AudioEncoder.pcm16bits,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: 'audio.wav',
      );
    }
  }

  Future<void> stopRecording() async {
    _isRecording = false;
    notifyListeners();
    String? path = await audioRecorder.stop();
    if (path != null) {
      await sendAudio(File(path));
      _messages.add('User: Audio sent'); // Add user message for audio
    }
  }

  Future<void> sendText(String text) async {
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
        log('WebSocket error: $error');
        _isLoading = false;
        notifyListeners();
        _messages.add('WebSocket Error: $error');
      },
      onDone: () {
        log('WebSocket connection closed');
        _isLoading = false;
        notifyListeners();
        _messages.add('WebSocket connection closed');
      },
      cancelOnError: false,
    );
  }

  Future<void> sendAudio(File audioFile) async {
    _isLoading = true;
    notifyListeners();

    List<int> audioBytes = await audioFile.readAsBytes();
    String base64Audio = base64Encode(audioBytes);

    final event = {
      "action": "AudioProcessing",
      "audio": base64Audio,
      "use_assistant": false,
    };

    _channel?.sink.add(jsonEncode(event));

    _channel?.stream.listen(
      (message) {
        _handleResponse(message);
      },
      onError: (error) {
        _isLoading = false;
        notifyListeners();
        _messages.add('Error: $error');
      },
    );
  }

  void _handleResponse(dynamic message) {
    log('message received: $message');
    try {
      if (message is String &&
          message.contains('Sent WebSocket response (chunked)')) {
        return;
      }

      _audioBuffer.write(message);
      String fullMessage = _audioBuffer.toString();

      final decoded = jsonDecode(fullMessage);
      log('decoded JSON: $decoded');

      if (decoded['audio'] != null) {
        _responseAudio = decoded['audio'];
        _audioBuffer.clear();
        _isLoading = false;
        notifyListeners();
        _playResponse();
      }
      if (decoded['response'] != null) {
        _messages.add('Assistant: ${decoded['response']}');
        _audioBuffer.clear();
        notifyListeners();
        log('Text response added to messages: ${decoded['response']}');
      }
    } catch (e) {
      log('Error in _handleResponse: $e');
      if (e is FormatException) {
        log('Partial JSON received, buffering...');
      } else {
        _isLoading = false;
        notifyListeners();
        _messages.add('Error processing response: $e');
        _audioBuffer.clear();
      }
    }
  }

  Future<void> _playResponse() async {
    log(
      'Starting to play response as stream. Audio length: ${_responseAudio.length} chars',
    );
    _isPlaying = true;
    notifyListeners();

    try {
      List<int> decodedBytes = base64Decode(_responseAudio);
      log('Decoded bytes length: ${decodedBytes.length}');

      Uint8List audioData = Uint8List.fromList(decodedBytes);
      await _audioPlayer.play(BytesSource(audioData));
      log('Audio playback completed successfully');
    } catch (e) {
      log('Error in _playResponse: $e');
      _isPlaying = false;
      notifyListeners();
      _messages.add('Failed to play audio: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
