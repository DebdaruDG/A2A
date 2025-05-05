import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';
import 'voice_note.dart';

class ChatScreen extends StatelessWidget {
  ChatScreen({super.key});

  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatState>(
      builder: (context, state, _) {
        _scrollToBottom();
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Voice Chat App',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.black,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: state.chats.length,
                  itemBuilder: (context, index) {
                    final item = state.chats[index];
                    log(
                      'state.isReceivingAudioChunks :- ${state.isReceivingAudioChunks}',
                    );
                    return Align(
                      alignment:
                          item.isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 5,
                          horizontal: 10,
                        ),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.isUser ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child:
                            // item.isLoading
                            state.isLoading
                                ? _LoadingWidget()
                                // const DancingDots() // Always show DancingDots for loading
                                : item.audioBytes != null
                                ? VoiceNoteWidget(
                                  message: item,
                                  chatState: state,
                                )
                                : Text(
                                  item.text ?? '',
                                  style: TextStyle(
                                    color:
                                        item.isUser
                                            ? Colors.black
                                            : Colors.white,
                                  ),
                                ),
                      ),
                    );
                  },
                ),
              ),
              if (!state.isLoading) // Show button only when not loading
                ElevatedButton(
                  onPressed:
                      state.isRecording
                          ? state.stopRecording
                          : state.startRecording,
                  child: Text(
                    state.isRecording ? 'Stop Recording' : 'Tap to Speak',
                  ),
                ),
              const SizedBox(height: 10),
              const _InputSection(),
            ],
          ),
        );
      },
    );
  }
}

class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(color: Colors.white),
        ),
        SizedBox(width: 10),
        Text('Generating response...', style: TextStyle(color: Colors.white)),
      ],
    );
  }
}

class _InputSection extends StatelessWidget {
  const _InputSection();

  @override
  Widget build(BuildContext context) {
    final chatState = context.read<ChatState>();
    final TextEditingController textController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  chatState.sendText(value.trim());
                  textController.clear();
                }
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                hintText: 'Type a message',
                hintStyle: const TextStyle(color: Colors.black45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (textController.text.trim().isNotEmpty) {
                      chatState.sendText(textController.text.trim());
                      textController.clear();
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
