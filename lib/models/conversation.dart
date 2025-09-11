// lib/models/conversation.dart
class Conversation {
  final String id;
  final String userId;
  final String characterId;
  final String title;
  final String? preview;
  final bool isBookmarked;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;

  Conversation({
    required this.id,
    required this.userId,
    required this.characterId,
    required this.title,
    this.preview,
    this.isBookmarked = false,
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      characterId: map['character_id'] ?? '',
      title: map['title'] ?? '',
      preview: map['preview'],
      isBookmarked: map['is_bookmarked'] ?? false,
      messageCount: map['message_count'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      lastMessageAt: DateTime.parse(map['last_message_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'character_id': characterId,
      'title': title,
      'preview': preview,
      'is_bookmarked': isBookmarked,
      'message_count': messageCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message_at': lastMessageAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? id,
    String? userId,
    String? characterId,
    String? title,
    String? preview,
    bool? isBookmarked,
    int? messageCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      characterId: characterId ?? this.characterId,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      messageCount: messageCount ?? this.messageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}
