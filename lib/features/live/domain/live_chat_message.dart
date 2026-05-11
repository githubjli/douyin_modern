class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.message,
    required this.senderName,
    required this.createdAt,
  });

  final int id;
  final String message;
  final String senderName;
  final DateTime createdAt;

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    final dynamic user = json['user'];
    final String name = user is Map<String, dynamic>
        ? (user['display_name'] ?? user['username'] ?? 'Viewer').toString()
        : (json['sender_name'] ?? 'Viewer').toString();
    return LiveChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      message: json['message']?.toString() ?? '',
      senderName: name,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
