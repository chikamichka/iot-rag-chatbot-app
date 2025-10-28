class Message {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<Source>? sources;

  Message({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.sources,
  }) : timestamp = timestamp ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      content: json['response'] ?? json['content'] ?? '',
      isUser: false,
      sources: json['sources'] != null
          ? (json['sources'] as List)
              .map((s) => Source.fromJson(s))
              .toList()
          : null,
    );
  }
}

class Source {
  final String text;
  final double score;

  Source({
    required this.text,
    required this.score,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      text: json['text'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
    );
  }
}