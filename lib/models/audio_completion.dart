class AudioCompletionResponse {
  final int statusCode;
  final bool isBase64Encoded;
  final Headers headers;
  final String body;

  AudioCompletionResponse({
    required this.statusCode,
    required this.isBase64Encoded,
    required this.headers,
    required this.body,
  });

  // Factory method to create an instance from JSON
  factory AudioCompletionResponse.fromJson(Map<String, dynamic> json) {
    return AudioCompletionResponse(
      statusCode: json['statusCode'] as int,
      isBase64Encoded: json['isBase64Encoded'] as bool,
      headers: Headers.fromJson(json['headers'] as Map<String, dynamic>),
      body: json['body'] as String,
    );
  }

  // Convert instance back to JSON (if needed for sending)
  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'isBase64Encoded': isBase64Encoded,
      'headers': headers.toJson(),
      'body': body,
    };
  }
}

class Headers {
  final String contentType;

  Headers({required this.contentType});

  factory Headers.fromJson(Map<String, dynamic> json) {
    return Headers(contentType: json['Content-Type'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'Content-Type': contentType};
  }
}
