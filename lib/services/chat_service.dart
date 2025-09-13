import '../models/message.dart';
import '../models/character.dart';
import 'groq_service.dart';
import 'conversation_service.dart';
import '../auth/auth_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class ChatService {
  final GroqService _groqService = GroqService();
  final AuthService _authService = AuthService();
  final ConversationService _conversationService = ConversationService();
  final _uuid = const Uuid();

  // Current conversation state
  List<Message> _messages = [];
  String? _currentCharacterId;
  String? _conversationId;
  String? _currentConversationDbId;

  // Stream controller for real-time message updates
  final StreamController<List<Message>> _messagesController = 
      StreamController<List<Message>>.broadcast();

  List<Message> get messages => List.unmodifiable(_messages);
  String? get currentCharacterId => _currentCharacterId;
  String? get currentConversationId => _currentConversationDbId;
  
  Stream<List<Message>> get messagesStream => _messagesController.stream;

  /// Start a new conversation with a character
  Future<void> startConversation(Character character, {String? existingConversationId}) async {
    print('🔥 Starting conversation with ${character.name}');
    
    if (existingConversationId != null) {
      await loadExistingConversation(existingConversationId, character);
      return;
    }

    _currentCharacterId = character.id;
    _conversationId = _uuid.v4();
    _messages.clear();

    // Immediately create conversation in database
    await _createNewConversationInDatabase(character);

    // Add welcome message from character
    final welcomeMessage = Message(
      id: _uuid.v4(),
      content: _getWelcomeMessage(character),
      senderId: character.id,
      senderName: character.name,
      timestamp: DateTime.now(),
      isFromUser: false,
    );

    _messages.add(welcomeMessage);
    _messagesController.add(_messages);

    // Save welcome message to database
    await _saveMessageToDatabase(welcomeMessage);
    
    print('🔥 ✅ Conversation started successfully');
  }

  /// Create new conversation in database immediately
  Future<void> _createNewConversationInDatabase(Character character) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('🔥 ❌ No authenticated user');
        return;
      }

      print('🔥 Creating conversation in database...');

      final conversation = await _conversationService.createConversation(
        character: character,
        firstMessage: "New conversation started with ${character.name}",
      );

      if (conversation != null) {
        _currentConversationDbId = conversation.id;
        print('🔥 ✅ Conversation created with ID: ${conversation.id}');
      } else {
        print('🔥 ⚠️ Failed to create conversation in database');
      }
    } catch (e) {
      print('🔥 ❌ Error creating conversation: $e');
    }
  }

  /// Load existing conversation from database
  Future<void> loadExistingConversation(String conversationDbId, Character character) async {
    try {
      print('🔥 Loading existing conversation: $conversationDbId');
      
      _currentCharacterId = character.id;
      _conversationId = _uuid.v4();
      _currentConversationDbId = conversationDbId;
      
      // Load messages from database
      final messages = await _conversationService.getConversationMessages(conversationDbId);
      
      // Ensure chronological order
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      _messages = messages;
      _messagesController.add(_messages);
      
      print('🔥 ✅ Loaded ${messages.length} messages');
    } catch (e) {
      print('🔥 ❌ Error loading conversation, falling back to new: $e');
      await startConversation(character);
    }
  }

  /// Send message with streaming using Groq Llama
  Future<Message?> sendMessageStreaming(String content, Character character) async {
    try {
      print('💬 🎬 Starting streaming text message...');
      
      // Add user message first
      final userMessage = Message(
        id: _uuid.v4(),
        content: content,
        senderId: 'user',
        senderName: _authService.currentUser?.displayName ?? 'You',
        timestamp: DateTime.now(),
        isFromUser: true,
      );
      _messages.add(userMessage);
      _messagesController.add(_messages);

      // Save user message to database immediately
      await _saveMessageToDatabase(userMessage);

      // Create placeholder AI message for streaming
      final aiMessageId = _uuid.v4();
      final aiMessage = Message(
        id: aiMessageId,
        content: '',
        senderId: character.id,
        senderName: character.name,
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      _messages.add(aiMessage);
      _messagesController.add(_messages);

      String accumulatedResponse = '';

      // Use Groq streaming
      await for (final chunk in _groqService.getCharacterResponseStream(
        character,
        content,
        conversationId: _conversationId,
      )) {
        accumulatedResponse = chunk;
        
        // Update the AI message content in real-time
        final messageIndex = _messages.indexWhere((m) => m.id == aiMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = Message(
            id: aiMessageId,
            content: accumulatedResponse,
            senderId: character.id,
            senderName: character.name,
            timestamp: DateTime.now(),
            isFromUser: false,
          );
          
          _messagesController.add(_messages);
        }
      }

      // Save final AI message to database
      final finalAiMessage = Message(
        id: aiMessageId,
        content: accumulatedResponse,
        senderId: character.id,
        senderName: character.name,
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      
      final messageIndex = _messages.indexWhere((m) => m.id == aiMessageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = finalAiMessage;
      }
      
      await _saveMessageToDatabase(finalAiMessage);

      print('💬 ✅ Streaming text message completed');
      return finalAiMessage;
      
    } catch (e) {
      print('💬 ❌ Error in streaming message: $e');
      return await _handleErrorMessage(character, e.toString());
    }
  }

  /// Send regular message using Groq Llama
  Future<Message?> sendMessage(String content, Character character) async {
    try {
      print('💬 📝 Starting regular text message...');
      
      // Add user message first
      final userMessage = Message(
        id: _uuid.v4(),
        content: content,
        senderId: 'user',
        senderName: _authService.currentUser?.displayName ?? 'You',
        timestamp: DateTime.now(),
        isFromUser: true,
      );
      _messages.add(userMessage);
      _messagesController.add(_messages);

      // Save user message to database immediately
      await _saveMessageToDatabase(userMessage);

      // Get AI response from Groq
      final aiResponse = await _groqService.getCharacterResponse(
        character,
        content,
        conversationId: _conversationId,
      );

      // Create AI message
      final aiMessage = Message(
        id: _uuid.v4(),
        content: aiResponse,
        senderId: character.id,
        senderName: character.name,
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      _messages.add(aiMessage);
      _messagesController.add(_messages);

      // Save AI message to database
      await _saveMessageToDatabase(aiMessage);

      print('💬 ✅ Regular text message completed');
      return aiMessage;
    } catch (e) {
      print('💬 ❌ Error in regular message: $e');
      return await _handleErrorMessage(character, e.toString());
    }
  }

  /// Save message to database with proper error handling
  Future<void> _saveMessageToDatabase(Message message) async {
    try {
      if (_currentConversationDbId == null) {
        print('💾 ⚠️ No conversation ID, skipping database save');
        return;
      }

      await _conversationService.saveMessageToConversation(
        conversationId: _currentConversationDbId!,
        message: message,
      );
      
      await _updateConversationMetadata();
      print('💾 ✅ Message saved to database');
      
    } catch (e) {
      print('💾 ❌ Error saving message to database: $e');
    }
  }

  /// Update conversation metadata
  Future<void> _updateConversationMetadata() async {
    try {
      if (_currentConversationDbId == null) return;
      
      final messages = await _conversationService.getConversationMessages(_currentConversationDbId!);
      print('💾 📊 Updated conversation metadata: ${messages.length} messages');
      
    } catch (e) {
      print('💾 ❌ Error updating conversation metadata: $e');
    }
  }

  /// Handle error messages
  Future<Message?> _handleErrorMessage(Character character, String error) async {
    final errorMessage = Message(
      id: _uuid.v4(),
      content: "I apologize, but I'm having trouble responding right now. Please try again in a moment.",
      senderId: character.id,
      senderName: character.name,
      timestamp: DateTime.now(),
      isFromUser: false,
    );
    _messages.add(errorMessage);
    _messagesController.add(_messages);
    
    await _saveMessageToDatabase(errorMessage);
    
    return errorMessage;
  }

  /// Get debug status
  Map<String, dynamic> getDebugStatus() {
    return {
      'currentCharacterId': _currentCharacterId,
      'conversationSessionId': _conversationId,
      'currentConversationDbId': _currentConversationDbId,
      'messageCount': _messages.length,
      'isConversationPersisted': isConversationPersisted,
      'hasWelcomeMessage': _messages.isNotEmpty && !_messages.first.isFromUser,
      'userEmail': _authService.currentUser?.email,
      'userUid': _authService.currentUser?.uid,
      'lastMessageTime': _messages.isNotEmpty ? _messages.last.timestamp.toString() : 'None',
      'conversationTitle': getConversationTitle(),
    };
  }

  /// Get conversation title
  String getConversationTitle() {
    if (_messages.isNotEmpty) {
      final firstUserMessage = _messages.firstWhere(
        (msg) => msg.isFromUser,
        orElse: () => _messages.first,
      );
      final words = firstUserMessage.content.split(' ').take(5).join(' ');
      return words.length > 30 ? '${words.substring(0, 30)}...' : words;
    }
    return 'New Conversation';
  }

  /// Get conversation preview
  String getConversationPreview() {
    if (_messages.length > 1) {
      final lastMessage = _messages.last;
      return lastMessage.content.length > 100 
          ? '${lastMessage.content.substring(0, 100)}...'
          : lastMessage.content;
    }
    return '';
  }

  /// Clear current conversation
  void clearConversation() {
    _messages.clear();
    _currentCharacterId = null;
    _conversationId = null;
    _currentConversationDbId = null;
    _messagesController.add(_messages);
  }

  /// Get message count
  int get messageCount => _messages.length;

  /// Check if conversation is persisted
  bool get isConversationPersisted => _currentConversationDbId != null;

  /// Reload conversation from database
  Future<void> reloadConversation() async {
    if (_currentConversationDbId != null) {
      try {
        final messages = await _conversationService.getConversationMessages(_currentConversationDbId!);
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        _messages = messages;
        _messagesController.add(_messages);
        
        print('🔄 ✅ Conversation reloaded: ${messages.length} messages');
      } catch (e) {
        print('🔄 ❌ Error reloading conversation: $e');
      }
    }
  }

  /// Export conversation as text
  String exportConversationAsText() {
    final buffer = StringBuffer();
    buffer.writeln('Conversation Export');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Character: ${_currentCharacterId ?? 'Unknown'}');
    buffer.writeln('Messages: ${_messages.length}');
    buffer.writeln('=' * 50);
    
    for (final message in _messages) {
      buffer.writeln();
      buffer.writeln('${message.senderName} (${_formatTime(message.timestamp)}):');
      if (message.content.isNotEmpty) {
        buffer.writeln(message.content);
      }
      buffer.writeln('-' * 30);
    }
    
    return buffer.toString();
  }

  /// Format time for export
  String _formatTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Dispose resources
  void dispose() {
    _messagesController.close();
  }

  /// Generate welcome message for character
  String _getWelcomeMessage(Character character) {
    switch (character.id) {
      case 'albert_einstein':
        return "Hello! I am Albert Einstein. I'm delighted to discuss the wonders of the universe with you. What questions about physics, science, or life would you like to explore together?";
      case 'marie_curie':
        return "Greetings! I am Marie Curie. It's wonderful to meet someone interested in science and discovery. What would you like to know about my research or the fascinating world of radioactivity?";
      case 'shakespeare':
        return "Good morrow to thee! I am William Shakespeare, humble servant of the written word. What tales of love, tragedy, or the human condition shall we explore together?";
      case 'leonardo_da_vinci':
        return "Salve, my curious friend! I am Leonardo da Vinci. Whether 'tis art, science, invention, or the mysteries of nature, I am eager to share my insights with thee!";
      default:
        return "Hello! I'm ${character.name}. I'm excited to chat with you today. What would you like to discuss?";
    }
  }
}
