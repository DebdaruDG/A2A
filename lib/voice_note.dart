import 'dart:developer';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import 'chat_provider.dart';

class VoiceNoteWidget extends StatefulWidget {
  final Uint8List audioBytes; // Decoded audio bytes

  const VoiceNoteWidget({super.key, required this.audioBytes});

  @override
  _VoiceNoteWidgetState createState() => _VoiceNoteWidgetState();
}

class _VoiceNoteWidgetState extends State<VoiceNoteWidget> {
  late AudioPlayer _audioPlayer;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Listen to audio duration changes
    _audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() {
        _duration = d;
      });
    });

    // Listen to audio position changes
    _audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() {
        _position = p;
      });
    });

    // Listen for when the audio completes
    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (state == PlayerState.completed) {
        // setState(() {
        //   _isPlaying = false;
        //   _position = Duration.zero;
        // });
      }
    });

    // Set the audio source using BytesSource
    _audioPlayer.setSource(BytesSource(widget.audioBytes));
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {}

  // A simple waveform painter to mimic the UI in the image
  Widget _buildWaveform() {
    return SizedBox(
      height: 30,
      width: 150,
      child: CustomPaint(painter: WaveformPainter(_position, _duration)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatState>(
      builder: (context, state, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color.fromARGB(255, 244, 243, 243),
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  state.isPlaying == false ? Icons.play_arrow : Icons.pause,
                  color: Colors.blue,
                  size: 30,
                ),
                onPressed: () {
                  state.togglePlayPause;
                },
              ),
              SizedBox(width: 10),
              _buildWaveform(),
              SizedBox(width: 10),
              Text(
                "${_duration.inSeconds.toString().padLeft(2, '0')}:${(_duration.inMilliseconds % 1000).toString().padLeft(3, '0').substring(0, 2)}",
                style: TextStyle(color: Colors.blue, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Custom painter for the waveform visualization
class WaveformPainter extends CustomPainter {
  final Duration position;
  final Duration duration;

  WaveformPainter(this.position, this.duration);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2
          ..style = PaintingStyle.fill;

    final barWidth = 2.0;
    final barSpacing = 1.0;
    final totalBars = (size.width / (barWidth + barSpacing)).floor();
    final progress =
        duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

    for (int i = 0; i < totalBars; i++) {
      final barHeight =
          (i < totalBars / 3 || i > 2 * totalBars / 3)
              ? size.height * 0.3
              : (i < totalBars / 2 || i > 1.5 * totalBars / 2)
              ? size.height * 0.5
              : size.height * 0.8;

      final x = i * (barWidth + barSpacing);
      final isActive = i / totalBars <= progress;

      paint.color = isActive ? Colors.blue : Colors.grey;
      canvas.drawRect(
        Rect.fromLTWH(x, (size.height - barHeight) / 2, barWidth, barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
