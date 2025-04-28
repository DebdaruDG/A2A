import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_provider.dart';
import 'voice_note.dart';

class ChatScreen extends StatelessWidget {
  ChatScreen({super.key});

  final TextEditingController _textController = TextEditingController();
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
                            item.isLoading
                                ? const _LoadingWidget()
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
              const _InputSection(),
              const SizedBox(height: 10),
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
            ],
          ),
        );
      },
    );
  }
}

// Loading widget when waiting for bot response
class _LoadingWidget extends StatelessWidget {
  const _LoadingWidget();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(width: 10),
        Text('Generating response...', style: TextStyle(color: Colors.white)),
      ],
    );
  }
}

// Text input section widget
class _InputSection extends StatelessWidget {
  const _InputSection();

  @override
  Widget build(BuildContext context) {
    final chatState = context.read<ChatState>();
    final TextEditingController _textController = TextEditingController();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  chatState.sendText(value.trim());
                  _textController.clear();
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
                    if (_textController.text.trim().isNotEmpty) {
                      chatState.sendText(_textController.text.trim());
                      _textController.clear();
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
