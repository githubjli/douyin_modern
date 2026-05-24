class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.message,
    required this.senderName,
    required this.createdAt,
    this.type = 'chat',
    this.payload = const <String, dynamic>{},
  });

  final int id;
  final String message;
  final String senderName;
  final DateTime createdAt;

  /// One of: chat | system | gift | product | payment
  final String type;

  /// Extra data for non-chat events (gift details, product info, etc.)
  final Map<String, dynamic> payload;

  bool get isGift => type == 'gift';
  bool get isSystem => type == 'system';

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    final dynamic user = json['user'];
    final String name = user is Map<String, dynamic>
        ? (user['display_name'] ?? user['username'] ?? 'Viewer').toString()
        : (json['sender_name'] ?? 'Viewer').toString();

    return LiveChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      // content is the new field name; message is the legacy name
      message: json['content']?.toString() ?? json['message']?.toString() ?? '',
      senderName: name,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      type: json['type']?.toString() ?? 'chat',
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }
}
