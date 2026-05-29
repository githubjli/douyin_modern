class LiveChatMessage {
  const LiveChatMessage({
    required this.id,
    required this.message,
    required this.senderName,
    required this.createdAt,
    this.type = 'chat',
    this.messageType = 'text',
    this.isPinned = false,
    this.userId,
    this.userAvatarUrl,
    this.payload = const <String, dynamic>{},
  });

  final int id;
  final String message;
  final String senderName;
  final DateTime createdAt;

  /// Event category: chat | system | gift | product | payment
  final String type;

  /// Content kind: text | product
  final String messageType;

  final bool isPinned;
  final int? userId;
  final String? userAvatarUrl;

  /// Extra data for non-chat events (gift details, product info, etc.)
  final Map<String, dynamic> payload;

  bool get isGift => type == 'gift';
  bool get isSystem => type == 'system';
  bool get isProduct => messageType == 'product';

  factory LiveChatMessage.fromJson(Map<String, dynamic> json) {
    final dynamic user = json['user'];
    final String name;
    int? userId;
    String? avatarUrl;

    if (user is Map<String, dynamic>) {
      name = (user['name'] ?? user['display_name'] ?? user['username'] ?? 'Viewer')
          .toString();
      userId = (user['id'] as num?)?.toInt();
      avatarUrl = user['avatar_url']?.toString();
    } else {
      name = (json['sender_name'] ?? 'Viewer').toString();
    }

    return LiveChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      // content is the canonical field; message is the legacy alias
      message: json['content']?.toString() ?? json['message']?.toString() ?? '',
      senderName: name,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      type: json['type']?.toString() ?? 'chat',
      messageType: json['message_type']?.toString() ?? 'text',
      isPinned: json['is_pinned'] as bool? ?? false,
      userId: userId,
      userAvatarUrl: (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null,
      payload: json['payload'] is Map<String, dynamic>
          ? json['payload'] as Map<String, dynamic>
          : const <String, dynamic>{},
    );
  }

  LiveChatMessage copyWith({
    bool? isPinned,
    String? message,
  }) {
    return LiveChatMessage(
      id: id,
      message: message ?? this.message,
      senderName: senderName,
      createdAt: createdAt,
      type: type,
      messageType: messageType,
      isPinned: isPinned ?? this.isPinned,
      userId: userId,
      userAvatarUrl: userAvatarUrl,
      payload: payload,
    );
  }
}
