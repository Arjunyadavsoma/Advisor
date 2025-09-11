// lib/models/message.dart - ENHANCED WITH IMAGE SUPPORT
class Message {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isFromUser;
  final String? imageUrl;      // Add this
  final String? imageName;     // Add this
  final bool hasImage;         // Add this

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    required this.isFromUser,
    this.imageUrl,
    this.imageName,
    this.hasImage = false,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      isFromUser: map['is_from_user'] ?? false,
      imageUrl: map['image_url'],
      imageName: map['image_name'],
      hasImage: map['has_image'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'sender_id': senderId,
      'sender_name': senderName,
      'timestamp': timestamp.toIso8601String(),
      'is_from_user': isFromUser,
      'image_url': imageUrl,
      'image_name': imageName,
      'has_image': hasImage,
    };
  }

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderName,
    DateTime? timestamp,
    bool? isFromUser,
    String? imageUrl,
    String? imageName,
    bool? hasImage,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      isFromUser: isFromUser ?? this.isFromUser,
      imageUrl: imageUrl ?? this.imageUrl,
      imageName: imageName ?? this.imageName,
      hasImage: hasImage ?? this.hasImage,
    );
  }
}
