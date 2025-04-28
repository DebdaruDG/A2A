import 'dart:typed_data';

class ChatMessage {
  final String? text; // For text messages
  final bool isUser; // True for user messages, false for assistant
  final Uint8List? audioBytes; // For voice notes
  final bool isLoading; // For loading state

  ChatMessage({
    this.text,
    required this.isUser,
    this.audioBytes,
    this.isLoading = false,
  });
}
