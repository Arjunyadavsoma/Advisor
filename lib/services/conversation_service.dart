// lib/services/conversation_service.dart - CORRECTED & COMPLETE
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/character.dart';
import '../auth/auth_service.dart';

class ConversationService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();

  /// Create a new conversation
  Future<Conversation?> createConversation({
    required Character character,
    required String firstMessage,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return null;
      }

      final title = _generateTitle(firstMessage, character.name);
      final preview = firstMessage.length > 100 
          ? '${firstMessage.substring(0, 100)}...' 
          : firstMessage;


      final response = await _client.from('conversations').insert({
        'user_id': user.uid,
        'character_id': character.id,
        'title': title,
        'preview': preview,
        'message_count': 1,
        'last_message_at': DateTime.now().toIso8601String(),
      }).select().single();

      return Conversation.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Save a message to conversation (WITH IMAGE SUPPORT)
  Future<void> saveMessageToConversation({
    required String conversationId,
    required Message message,
  }) async {
    try {
      
      // Save message with all fields including image data
      await _client.from('conversation_messages').insert({
        'conversation_id': conversationId,
        'content': message.content,
        'sender_id': message.senderId,
        'sender_name': message.senderName,
        'is_from_user': message.isFromUser,
        'timestamp': message.timestamp.toIso8601String(),
        // 🔥 IMAGE SUPPORT FIELDS
        'image_url': message.imageUrl,
        'image_name': message.imageName,
        'has_image': message.hasImage,
      });


      // Update conversation metadata with image-aware preview
      String newPreview;
      if (message.hasImage) {
        newPreview = message.content.isNotEmpty 
            ? '📷 ${message.content}'
            : '📷 Shared an image';
      } else {
        newPreview = message.content.length > 100 
            ? '${message.content.substring(0, 100)}...' 
            : message.content;
      }

      await _client.from('conversations').update({
        'preview': newPreview,
        'updated_at': DateTime.now().toIso8601String(),
        'last_message_at': DateTime.now().toIso8601String(),
      }).match({'id': conversationId});

    } catch (e) {
    }
  }

  /// Get user's conversations with proper ordering
  Future<List<Conversation>> getUserConversations({
    int limit = 50,
    int offset = 0,
    bool bookmarkedOnly = false,
    bool newestFirst = true,
  }) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return [];
      }


      var query = _client
          .from('conversations')
          .select()
          .eq('user_id', user.uid);

      if (bookmarkedOnly) {
        query = query.eq('is_bookmarked', true);
      }

      // Order conversations correctly
      final response = await query
          .order('last_message_at', ascending: !newestFirst)
          .range(offset, offset + limit - 1);

      final conversations = (response as List<dynamic>)
          .map((e) => Conversation.fromMap(e as Map<String, dynamic>))
          .toList();

      return conversations;
    } catch (e) {
      return [];
    }
  }

  /// Get conversation messages with proper ordering (WITH IMAGE SUPPORT)
  Future<List<Message>> getConversationMessages(String conversationId) async {
    try {
      
      final response = await _client
          .from('conversation_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('timestamp', ascending: true); // Oldest messages first (chronological)

      final messages = (response as List<dynamic>)
          .map((e) => Message(
                id: e['id']?.toString() ?? '',
                content: e['content'] ?? '',
                senderId: e['sender_id'] ?? '',
                senderName: e['sender_name'] ?? '',
                timestamp: DateTime.parse(e['timestamp'] ?? DateTime.now().toIso8601String()),
                isFromUser: e['is_from_user'] ?? false,
                // 🔥 IMAGE SUPPORT FIELDS
                imageUrl: e['image_url'],
                imageName: e['image_name'],
                hasImage: e['has_image'] ?? false,
              ))
          .toList();

      return messages;
    } catch (e) {
      return [];
    }
  }

  /// Toggle bookmark status
  Future<bool> toggleBookmark(String conversationId) async {
    try {
      final current = await _client
          .from('conversations')
          .select('is_bookmarked')
          .eq('id', conversationId)
          .single();

      final newStatus = !(current['is_bookmarked'] ?? false);

      await _client
          .from('conversations')
          .update({'is_bookmarked': newStatus})
          .eq('id', conversationId);

      return newStatus;
    } catch (e) {
      return false;
    }
  }

  /// Delete conversation
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _client
          .from('conversations')
          .delete()
          .eq('id', conversationId);
      
    } catch (e) {
    }
  }

  /// Search conversations
  Future<List<Conversation>> searchConversations(String query) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return [];


      // Try database search first
      try {
        final response = await _client
            .from('conversations')
            .select()
            .eq('user_id', user.uid)
            .or('title.ilike.%$query%,preview.ilike.%$query%')
            .order('last_message_at', ascending: false);

        final results = (response as List<dynamic>)
            .map((e) => Conversation.fromMap(e as Map<String, dynamic>))
            .toList();
        
        return results;
      } catch (e) {
        
        // Fallback: get all conversations and filter locally
        final allConversations = await getUserConversations();
        
        final results = allConversations.where((conv) => 
          conv.title.toLowerCase().contains(query.toLowerCase()) ||
          (conv.preview?.toLowerCase().contains(query.toLowerCase()) ?? false)
        ).toList();
        
        return results;
      }
    } catch (e) {
      return [];
    }
  }

  /// Get conversation by ID
  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .single();

      return Conversation.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  /// Update conversation title
  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    try {
      await _client
          .from('conversations')
          .update({
            'title': newTitle, 
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', conversationId);
      
    } catch (e) {
    }
  }

  /// Get user's conversation count
  Future<int> getUserConversationCount() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return 0;

      final response = await _client
          .from('conversations')
          .select('id')
          .eq('user_id', user.uid);

      return (response as List<dynamic>).length;
    } catch (e) {
      return 0;
    }
  }

  /// Get conversations with images
  Future<List<Conversation>> getConversationsWithImages() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return [];

      // Get conversations that have messages with images
      final response = await _client
          .from('conversations')
          .select()
          .eq('user_id', user.uid)
          .order('last_message_at', ascending: false);

      final conversations = (response as List<dynamic>)
          .map((e) => Conversation.fromMap(e as Map<String, dynamic>))
          .toList();

      // Filter to only conversations that contain images
      List<Conversation> conversationsWithImages = [];
      
      for (final conversation in conversations) {
        final messages = await _client
            .from('conversation_messages')
            .select('has_image')
            .eq('conversation_id', conversation.id)
            .eq('has_image', true)
            .limit(1);
        
        if (messages.isNotEmpty) {
          conversationsWithImages.add(conversation);
        }
      }

      return conversationsWithImages;
    } catch (e) {
      return [];
    }
  }

  /// Generate conversation title
  String _generateTitle(String firstMessage, String characterName) {
    final words = firstMessage.split(' ').take(4).join(' ');
    final title = 'Chat with $characterName: $words';
    return title.length > 50 ? '${title.substring(0, 47)}...' : title;
  }

  /// Test database connectivity
  Future<bool> testConnection() async {
    try {
      await _client.from('conversations').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }
}
