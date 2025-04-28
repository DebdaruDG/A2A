import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_model.dart';
import 'chat_provider.dart';

class VoiceNoteWidget extends StatefulWidget {
  final ChatMessage message;
  final ChatState chatState;

  const VoiceNoteWidget({
    Key? key,
    required this.message,
    required this.chatState,
  }) : super(key: key);

  @override
  _VoiceNoteWidgetState createState() => _VoiceNoteWidgetState();
}

class _VoiceNoteWidgetState extends State<VoiceNoteWidget> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = widget.chatState.sharedPlayer;
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.setSource(BytesSource(widget.message.audioBytes!));
      await _audioPlayer.resume();
    }

    setState(() {
      _isPlaying = !_isPlaying;
    });
    widget.chatState.togglePlayPause(widget.message.audioBytes!);
  }

  void _seekTo(double value) async {
    final seekPosition = Duration(seconds: value.toInt());
    await _audioPlayer.seek(seekPosition);
    setState(() {
      _currentPosition = seekPosition;
    });
  }

  @override
  void dispose() {
    super.dispose();
    _audioPlayer.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          if (!widget.message.isUser)
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.blue,
              ),
              onPressed: _togglePlayPause,
            ),
          if (!widget.message.isUser)
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 50.0, // Fixed height for the waveform container
                    child: CustomPaint(
                      painter: AudioWaveformPainter(
                        audioBytes: widget.message.audioBytes!,
                        currentPosition: _currentPosition,
                        totalDuration: _totalDuration,
                      ),
                    ),
                  ),
                  Slider(
                    value: _currentPosition.inSeconds.toDouble(),
                    min: 0,
                    max: _totalDuration.inSeconds.toDouble(),
                    onChanged: (value) {
                      if (!_isSeeking) {
                        _seekTo(value);
                      }
                    },
                    onChangeStart: (_) {
                      setState(() {
                        _isSeeking = true;
                      });
                    },
                    onChangeEnd: (_) {
                      setState(() {
                        _isSeeking = false;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5.0),
                    child: Text(
                      "${_currentPosition.inSeconds}s / ${_totalDuration.inSeconds}s",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AudioWaveformPainter extends CustomPainter {
  final Uint8List audioBytes;
  final Duration currentPosition;
  final Duration totalDuration;

  AudioWaveformPainter({
    required this.audioBytes,
    required this.currentPosition,
    required this.totalDuration,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final path = Path();

    // This part is for drawing the waveform. We simulate it by dividing the audio bytes.
    int waveLength = audioBytes.length;
    double step = size.width / waveLength;
    double amplitude = size.height / 2;

    for (int i = 0; i < waveLength; i++) {
      double x = i * step;
      double y = amplitude + (audioBytes[i] - 128) * (amplitude / 128);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw the waveform path
    canvas.drawPath(path, paint);

    // Optional: Draw current position indicator
    double currentPositionX =
        (currentPosition.inSeconds / totalDuration.inSeconds) * size.width;
    final positionPaint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 4;
    canvas.drawLine(
      Offset(currentPositionX, 0),
      Offset(currentPositionX, size.height),
      positionPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
