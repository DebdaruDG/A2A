import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math';

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

  late List<double> _barHeights;
  late List<double> _targetHeights;
  late Timer _waveformTimer;
  final int _barCount = 20;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(_barCount, (_) => 10);
    _targetHeights = List.generate(_barCount, (_) => 10);

    _audioPlayer = widget.chatState.sharedPlayer;

    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() => _totalDuration = duration);
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() => _currentPosition = position);
    });

    _waveformTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (_isPlaying) {
        setState(() {
          for (int i = 0; i < _barCount; i++) {
            // Every few ticks, generate a new target
            if (_random.nextDouble() < 0.1) {
              _targetHeights[i] = 10 + _random.nextDouble() * 30;
            }
            _barHeights[i] =
                lerpDouble(_barHeights[i], _targetHeights[i], 0.2)!;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _waveformTimer.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(BytesSource(widget.message.audioBytes!));
    }
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    String formatDuration(Duration d) {
      return d
          .toString()
          .split('.')
          .first
          .padLeft(8, "0")
          .substring(3); // MM:SS
    }

    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.35,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: _togglePlayPause,
          ),
          Text(
            formatDuration(_currentPosition),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 30,
              child: CustomPaint(
                painter: AnimatedWaveformPainter(
                  barHeights: _barHeights,
                  progress:
                      _totalDuration.inMilliseconds == 0
                          ? 0
                          : _currentPosition.inMilliseconds /
                              _totalDuration.inMilliseconds,
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            formatDuration(_totalDuration),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
    // return SizedBox(
    //   width: MediaQuery.sizeOf(context).width * 0.35,
    //   child: Row(
    //     children: [
    //       IconButton(
    //         icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
    //         onPressed: _togglePlayPause,
    //       ),
    //       Expanded(
    //         child: SizedBox(
    //           height: 30,
    //           child: CustomPaint(
    //             painter: AnimatedWaveformPainter(
    //               barHeights: _barHeights,
    //               progress:
    //                   _totalDuration.inMilliseconds == 0
    //                       ? 0
    //                       : _currentPosition.inMilliseconds /
    //                           _totalDuration.inMilliseconds,
    //             ),
    //           ),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}

class AnimatedWaveformPainter extends CustomPainter {
  final List<double> barHeights;
  final double progress;

  AnimatedWaveformPainter({required this.barHeights, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final int barCount = barHeights.length;
    final double spacing = size.width / barCount;

    final Paint playedPaint =
        Paint()
          ..color = Colors.deepPurple
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2;

    final Paint unplayedPaint =
        Paint()
          ..color = Colors.deepPurple.shade100
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2;

    for (int i = 0; i < barCount; i++) {
      final double barHeight = barHeights[i].clamp(10.0, size.height);
      final double x = i * spacing + spacing / 2;
      final double y1 = size.height / 2 - barHeight / 2;
      final double y2 = size.height / 2 + barHeight / 2;

      final paint = (i / barCount <= progress) ? playedPaint : unplayedPaint;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
