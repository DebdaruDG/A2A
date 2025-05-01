class PunjabiBotResponse {
  List<AudioChunks>? audioChunks;
  String? message;
  TimingInfo? timingInfo;

  PunjabiBotResponse({this.audioChunks, this.message, this.timingInfo});

  PunjabiBotResponse.fromJson(Map<String, dynamic> json) {
    if (json['audio_chunks'] != null) {
      audioChunks = <AudioChunks>[];
      json['audio_chunks'].forEach((v) {
        audioChunks!.add(AudioChunks.fromJson(v));
      });
    }
    message = json['message'];
    timingInfo =
        json['timing_info'] != null
            ? TimingInfo.fromJson(json['timing_info'])
            : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (audioChunks != null) {
      data['audio_chunks'] = audioChunks!.map((v) => v.toJson()).toList();
    }
    data['message'] = message;
    if (timingInfo != null) {
      data['timing_info'] = timingInfo!.toJson();
    }
    return data;
  }
}

class AudioChunks {
  String? messageId;
  int? chunkIndex;
  int? totalChunks;
  String? data;

  AudioChunks({this.messageId, this.chunkIndex, this.totalChunks, this.data});

  AudioChunks.fromJson(Map<String, dynamic> json) {
    messageId = json['messageId'];
    chunkIndex = json['chunkIndex'];
    totalChunks = json['totalChunks'];
    data = json['data'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['messageId'] = messageId;
    data['chunkIndex'] = chunkIndex;
    data['totalChunks'] = totalChunks;
    data['data'] = this.data;
    return data;
  }
}

class TimingInfo {
  int? parseInput;
  int? decodeAudio;
  int? saveWav;
  int? transcription;
  int? assistantResponse;
  int? textToSpeech;
  int? chunkingAudio;
  int? totalTime;

  TimingInfo({
    this.parseInput,
    this.decodeAudio,
    this.saveWav,
    this.transcription,
    this.assistantResponse,
    this.textToSpeech,
    this.chunkingAudio,
    this.totalTime,
  });

  TimingInfo.fromJson(Map<String, dynamic> json) {
    parseInput = json['parse_input'];
    decodeAudio = json['decode_audio'];
    saveWav = json['save_wav'];
    transcription = json['transcription'];
    assistantResponse = json['assistant_response'];
    textToSpeech = json['text_to_speech'];
    chunkingAudio = json['chunking_audio'];
    totalTime = json['total_time'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['parse_input'] = parseInput;
    data['decode_audio'] = decodeAudio;
    data['save_wav'] = saveWav;
    data['transcription'] = transcription;
    data['assistant_response'] = assistantResponse;
    data['text_to_speech'] = textToSpeech;
    data['chunking_audio'] = chunkingAudio;
    data['total_time'] = totalTime;
    return data;
  }
}
