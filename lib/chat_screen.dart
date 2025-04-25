import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';
import 'voice_note.dart';

class ChatScreen extends StatelessWidget {
  final TextEditingController _textController = TextEditingController();

  ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatState>(
      builder: (context, state, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text('Voice Chat App'),
            backgroundColor: Colors.black,
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
          ),
          body: SingleChildScrollView(
            // Wrap with SingleChildScrollView to handle overflow
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height -
                    kToolbarHeight -
                    16 * 2,
              ), // Adjust for app bar and padding
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Minimize the column height
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap:
                            true, // Allow ListView to take only needed space
                        physics:
                            ClampingScrollPhysics(), // Prevent over-scrolling
                        itemCount: state.messages.length,
                        itemBuilder: (context, index) {
                          final message = state.messages[index];
                          bool isUserMessage = message.startsWith('User:');
                          return Align(
                            alignment:
                                isUserMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 10,
                              ),
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color:
                                    isUserMessage ? Colors.white : Colors.black,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                message.replaceAll(
                                  RegExp(r'^User: |^Assistant: '),
                                  '',
                                ),
                                style: TextStyle(
                                  color:
                                      isUserMessage
                                          ? Colors.black
                                          : Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (state.isLoading)
                      CircularProgressIndicator(color: Colors.black),
                    if (state.responseAudio.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: StreamBuilder<Duration>(
                              stream: state.audioPlayer.onPositionChanged,
                              builder: (context, positionSnapshot) {
                                if (!positionSnapshot.hasData) {
                                  return SizedBox.shrink();
                                }
                                return StreamBuilder<Duration>(
                                  stream: state.audioPlayer.onDurationChanged,
                                  builder: (context, durationSnapshot) {
                                    final position = positionSnapshot.data!;
                                    final duration =
                                        durationSnapshot.data ?? Duration.zero;
                                    final maxDuration =
                                        duration.inMilliseconds > 0
                                            ? duration.inMilliseconds.toDouble()
                                            : 1.0; // Default to 1 to avoid division by zero
                                    log(
                                      'state.isPlaying :- ${state.isPlaying}',
                                    );
                                    return VoiceNoteWidget(
                                      audioBytes: state.audioData,
                                    );

                                    // Row(
                                    //   children: [
                                    //     IconButton(
                                    //       icon: Icon(
                                    //         state.isPlaying
                                    //             ? Icons.pause
                                    //             : Icons.play_arrow,
                                    //         color: Colors.white,
                                    //       ),
                                    //       onPressed: () {
                                    //         if (state.isPlaying) {
                                    //           state.audioPlayer.pause();
                                    //         } else {
                                    //           state.audioPlayer.resume();
                                    //         }
                                    //       },
                                    //     ),
                                    //     Slider(
                                    //       value: position.inMilliseconds
                                    //           .toDouble()
                                    //           .clamp(0.0, maxDuration),
                                    //       max: maxDuration,
                                    //       onChanged: (value) {
                                    //         state.audioPlayer.seek(
                                    //           Duration(
                                    //             milliseconds: value.toInt(),
                                    //           ),
                                    //         );
                                    //       },
                                    //       activeColor: Colors.white,
                                    //       inactiveColor: Colors.grey[400],
                                    //     ),
                                    //     Text(
                                    //       '${position.inMinutes}:${(position.inSeconds % 60).toString().padLeft(2, '0')} / '
                                    //       '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                                    //       style: TextStyle(color: Colors.white),
                                    //     ),
                                    //   ],
                                    // );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: 'Type a message',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.send, color: Colors.black),
                          onPressed: () {
                            try {
                              if (_textController.text.isNotEmpty) {
                                state.sendText(_textController.text);
                                state.messages.add(
                                  'User: ${_textController.text}',
                                );
                                _textController.clear();
                              }
                            } catch (obj) {
                              log('exception :- $obj');
                            }
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed:
                              state.isRecording
                                  ? state.stopRecording
                                  : state.startRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            state.isRecording
                                ? 'Stop Recording'
                                : 'Tap to Speak',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                        SizedBox(width: 10),
                        if (state.isPlaying)
                          Text(
                            'Speaking...',
                            style: TextStyle(color: Colors.black),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
