// lib/services/chat_service.dart - COMPLETE WITH IMAGE SUPPORT
import 'dart:io';
import '../models/message.dart';
import '../models/character.dart';
import '../models/conversation.dart';
import 'groq_service.dart';
import 'conversation_service.dart';
import 'image_service.dart';
import 'ai_vision_service.dart';
import '../auth/auth_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math' as math;

class ChatService {
  final GroqService _groqService = GroqService();
  final AuthService _authService = AuthService();
  final ConversationService _conversationService = ConversationService();
  final ImageService _imageService = ImageService();
  final AIVisionService _aiVisionService = AIVisionService();
  final _uuid = const Uuid();

  // Current conversation state
  List<Message> _messages = [];
  String? _currentCharacterId;
  String? _conversationId;
  String? _currentConversationDbId; // Database conversation ID

  // Stream controller for real-time message updates
  final StreamController<List<Message>> _messagesController = 
      StreamController<List<Message>>.broadcast();

  List<Message> get messages => List.unmodifiable(_messages);
  String? get currentCharacterId => _currentCharacterId;
  String? get currentConversationId => _currentConversationDbId;
  
  // Stream of messages for real-time updates
  Stream<List<Message>> get messagesStream => _messagesController.stream;

  /// Start a new conversation with a character - ALWAYS CREATE IN DATABASE
  Future<void> startConversation(Character character, {String? existingConversationId}) async {
    print('💾 === STARTING CONVERSATION ===');
    print('💾 Character: ${character.name}');
    print('💾 Existing conversation ID: $existingConversationId');
    
    if (existingConversationId != null) {
      await loadExistingConversation(existingConversationId, character);
      return;
    }

    _currentCharacterId = character.id;
    _conversationId = _uuid.v4();
    _messages.clear();

    // 🔥 IMMEDIATELY CREATE CONVERSATION IN DATABASE
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

    // 🔥 IMMEDIATELY SAVE WELCOME MESSAGE TO DATABASE
    await _saveMessageToDatabase(welcomeMessage);
    
    print('💾 === CONVERSATION CREATED & WELCOME MESSAGE SAVED ===');
  }

  /// Create new conversation in database immediately
  Future<void> _createNewConversationInDatabase(Character character) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('💾 ❌ No authenticated user for conversation creation');
        return;
      }

      print('💾 Creating new conversation in database...');
      print('💾 User: ${user.email}');
      print('💾 Character: ${character.name} (${character.id})');

      final conversation = await _conversationService.createConversation(
        character: character,
        firstMessage: "New conversation started with ${character.name}",
      );

      if (conversation != null) {
        _currentConversationDbId = conversation.id;
        print('💾 ✅ New conversation created in DB: $_currentConversationDbId');
        print('💾 Conversation title: ${conversation.title}');
      } else {
        print('💾 ❌ Failed to create conversation in database');
      }
    } catch (e) {
      print('💾 ❌ Error creating conversation in database: $e');
    }
  }

  /// Load existing conversation from database
  Future<void> loadExistingConversation(String conversationDbId, Character character) async {
    try {
      print('📂 Loading existing conversation: $conversationDbId');
      
      _currentCharacterId = character.id;
      _conversationId = _uuid.v4(); // Generate new session ID for Groq context
      _currentConversationDbId = conversationDbId;
      
      // Load messages from database
      final messages = await _conversationService.getConversationMessages(conversationDbId);
      
      // Ensure messages are in chronological order
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      _messages = messages;
      _messagesController.add(_messages);
      
      print('📂 ✅ Loaded ${messages.length} messages from existing conversation');
      if (messages.isNotEmpty) {
        final imageMessages = messages.where((m) => m.hasImage).length;
        print('📂 📸 ${imageMessages} messages contain images');
      }
    } catch (e) {
      print('📂 ❌ Error loading conversation: $e');
      // Fallback to new conversation
      await startConversation(character);
    }
  }

  /// 📸 SEND IMAGE MESSAGE WITH AI ANALYSIS
  Future<Message?> sendImageMessage(
    String content, 
    File imageFile, 
    Character character,
    {bool useStreaming = true}
  ) async {
    try {
      print('📸💬 === SENDING IMAGE MESSAGE ===');
      print('📸💬 Text content: $content');
      print('📸💬 Character: ${character.name}');
      print('📸💬 Use streaming: $useStreaming');
      
      if (_currentConversationDbId == null) {
        print('📸💬 ❌ No active conversation');
        return null;
      }

      // 1. Upload image first
      print('📸💬 Uploading image...');
      final imageUrl = await _imageService.uploadImage(imageFile, _currentConversationDbId!);
      
      if (imageUrl == null) {
        print('📸💬 ❌ Failed to upload image');
        return null;
      }

      print('📸💬 ✅ Image uploaded: $imageUrl');

      // 2. Create user message with image
      final userMessage = Message(
        id: _uuid.v4(),
        content: content.isEmpty ? "Shared an image" : content,
        senderId: 'user',
        senderName: _authService.currentUser?.displayName ?? 'You',
        timestamp: DateTime.now(),
        isFromUser: true,
        imageUrl: imageUrl,
        imageName: imageFile.path.split('/').last,
        hasImage: true,
      );

      _messages.add(userMessage);
      _messagesController.add(_messages);
      
      // 3. Save user message to database
      await _saveMessageToDatabase(userMessage);

      // 4. Get AI analysis of the image
      print('📸💬 Getting AI analysis...');
      
      if (useStreaming) {
        return await _getStreamingImageAnalysis(imageUrl, content, character);
      } else {
        return await _getRegularImageAnalysis(imageUrl, content, character);
      }
      
    } catch (e) {
      print('📸💬 ❌ Error sending image message: $e');
      return await _handleErrorMessage(character, e.toString());
    }
  }

  /// Get streaming AI analysis of image
  Future<Message?> _getStreamingImageAnalysis(
    String imageUrl, 
    String userMessage, 
    Character character,
  ) async {
    try {
      // Create placeholder AI message for streaming
      final aiMessageId = _uuid.v4();
      final aiMessage = Message(
        id: aiMessageId,
        content: '', // Start empty
        senderId: character.id,
        senderName: character.name,
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      _messages.add(aiMessage);
      _messagesController.add(_messages);

      // Get AI analysis
      final analysis = await _aiVisionService.analyzeImageWithCharacter(
        imageUrl, 
        character, 
        userMessage,
      );

      // Simulate streaming by revealing words gradually
      final words = analysis.split(' ');
      String progressive = '';
      
      for (int i = 0; i < words.length; i++) {
        progressive += (i == 0 ? '' : ' ') + words[i];
        
        final messageIndex = _messages.indexWhere((m) => m.id == aiMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = Message(
            id: aiMessageId,
            content: progressive,
            senderId: character.id,
            senderName: character.name,
            timestamp: DateTime.now(),
            isFromUser: false,
          );
          
          _messagesController.add(_messages);
        }
        
        await Future.delayed(const Duration(milliseconds: 50));
      }

      // Save final AI analysis to database
      final finalAiMessage = _messages.firstWhere((m) => m.id == aiMessageId);
      await _saveMessageToDatabase(finalAiMessage);

      print('📸💬 ✅ Streaming image analysis complete');
      return finalAiMessage;
    } catch (e) {
      print('📸💬 ❌ Error in streaming image analysis: $e');
      return null;
    }
  }

  /// Get regular AI analysis of image
  Future<Message?> _getRegularImageAnalysis(
    String imageUrl, 
    String userMessage, 
    Character character,
  ) async {
    try {
      final analysis = await _aiVisionService.analyzeImageWithCharacter(
        imageUrl, 
        character, 
        userMessage,
      );

      final aiMessage = Message(
        id: _uuid.v4(),
        content: analysis,
        senderId: character.id,
        senderName: character.name,
        timestamp: DateTime.now(),
        isFromUser: false,
      );

      _messages.add(aiMessage);
      _messagesController.add(_messages);

      await _saveMessageToDatabase(aiMessage);

      print('📸💬 ✅ Regular image analysis complete');
      return aiMessage;
    } catch (e) {
      print('📸💬 ❌ Error in regular image analysis: $e');
      return null;
    }
  }

  /// Send a message with simulated streaming
  Future<Message?> sendMessageStreaming(String content, Character character) async {
    try {
      print('💬 === STREAMING MESSAGE START ===');
      print('💬 Content: ${content.substring(0, math.min(50, content.length))}...');
      print('💬 Character: ${character.name}');
      print('💬 Current conversation DB ID: $_currentConversationDbId');
      
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
      print('💬 Added user message to local list');

      // Save user message to database immediately
      await _saveMessageToDatabase(userMessage);

      // Create placeholder AI message for streaming
      final aiMessageId = _uuid.v4();
      final aiMessage = Message(
        id: aiMessageId,
        content: '', // Start empty
        senderId: character.id,
        senderName: character.name, // 🔥 ENSURE AI NAME IS SAVED
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      _messages.add(aiMessage);
      _messagesController.add(_messages);

      // Get full AI response first
      print('💬 Calling Groq API...');
      final fullResponse = await _groqService.getCharacterResponse(
        character,
        content,
        conversationId: _conversationId,
      );
      print('💬 Got AI response: ${fullResponse.substring(0, math.min(100, fullResponse.length))}...');

      // Simulate streaming by revealing words gradually
      final words = fullResponse.split(' ');
      String progressive = '';
      
      for (int i = 0; i < words.length; i++) {
        progressive += (i == 0 ? '' : ' ') + words[i];
        
        // Update the AI message content in real-time
        final messageIndex = _messages.indexWhere((m) => m.id == aiMessageId);
        if (messageIndex != -1) {
          _messages[messageIndex] = Message(
            id: aiMessageId,
            content: progressive,
            senderId: character.id,
            senderName: character.name, // 🔥 ENSURE AI NAME IS MAINTAINED
            timestamp: DateTime.now(),
            isFromUser: false,
          );
          
          // Notify UI of the update
          _messagesController.add(_messages);
        }
        
        // Add delay for streaming effect
        await Future.delayed(const Duration(milliseconds: 80));
      }

      // Save final AI message to database with full content and character name
      final finalAiMessage = Message(
        id: aiMessageId,
        content: fullResponse, // Full response content
        senderId: character.id,
        senderName: character.name, // 🔥 AI CHARACTER NAME
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      
      // Update local message list
      final messageIndex = _messages.indexWhere((m) => m.id == aiMessageId);
      if (messageIndex != -1) {
        _messages[messageIndex] = finalAiMessage;
      }
      
      // Save to database
      await _saveMessageToDatabase(finalAiMessage);

      print('💬 ✅ Streaming complete and message saved to database');
      print('💬 === STREAMING MESSAGE END ===');

      return finalAiMessage;
      
    } catch (e) {
      print('💬 ❌ Streaming Error: $e');
      return await _handleErrorMessage(character, e.toString());
    }
  }

  /// Send a message (non-streaming version)
  Future<Message?> sendMessage(String content, Character character) async {
    try {
      print('💬 === REGULAR MESSAGE START ===');
      print('💬 Content: ${content.substring(0, math.min(50, content.length))}...');
      print('💬 Character: ${character.name}');
      print('💬 Current conversation DB ID: $_currentConversationDbId');
      
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
      print('💬 Added user message to local list');

      // Save user message to database immediately
      await _saveMessageToDatabase(userMessage);

      // Get AI response
      print('💬 Calling Groq API...');
      final aiResponse = await _groqService.getCharacterResponse(
        character,
        content,
        conversationId: _conversationId,
      );
      print('💬 Got AI response: ${aiResponse.substring(0, math.min(100, aiResponse.length))}...');

      // Create AI message with character name
      final aiMessage = Message(
        id: _uuid.v4(),
        content: aiResponse,
        senderId: character.id,
        senderName: character.name, // 🔥 ENSURE AI NAME IS SAVED
        timestamp: DateTime.now(),
        isFromUser: false,
      );
      _messages.add(aiMessage);
      _messagesController.add(_messages);
      print('💬 Added AI message to local list');

      // Save AI message to database
      await _saveMessageToDatabase(aiMessage);

      print('💬 ✅ Regular message complete and saved to database');
      print('💬 === REGULAR MESSAGE END ===');

      return aiMessage;
    } catch (e) {
      print('💬 ❌ Regular Message Error: $e');
      return await _handleErrorMessage(character, e.toString());
    }
  }

  /// Save any message to database (WITH IMAGE SUPPORT)
  Future<void> _saveMessageToDatabase(Message message) async {
    try {
      if (_currentConversationDbId == null) {
        print('💾 ❌ No conversation DB ID - cannot save message');
        return;
      }

      print('💾 Saving message to database...');
      print('💾 Conversation ID: $_currentConversationDbId');
      print('💾 Message from: ${message.senderName} (${message.isFromUser ? 'User' : 'AI'})');
      print('💾 Has image: ${message.hasImage}');
      print('💾 Content preview: ${message.content.substring(0, math.min(50, message.content.length))}...');

      await _conversationService.saveMessageToConversation(
        conversationId: _currentConversationDbId!,
        message: message,
      );
      
      print('💾 ✅ Message saved to database successfully');
      
      // Update conversation message count and preview
      await _updateConversationMetadata();
      
    } catch (e) {
      print('💾 ❌ Error saving message to database: $e');
    }
  }

  /// Update conversation metadata (message count, last activity)
  Future<void> _updateConversationMetadata() async {
    try {
      if (_currentConversationDbId == null) return;
      
      // Get current message count from database
      final messages = await _conversationService.getConversationMessages(_currentConversationDbId!);
      
      print('💾 Updating conversation metadata: ${messages.length} total messages');
    } catch (e) {
      print('💾 Error updating conversation metadata: $e');
    }
  }

  /// Handle error messages and save them too
  Future<Message?> _handleErrorMessage(Character character, String error) async {
    final errorMessage = Message(
      id: _uuid.v4(),
      content: "Sorry, I'm having trouble responding right now. Please try again.",
      senderId: character.id,
      senderName: character.name, // 🔥 ENSURE AI NAME FOR ERROR MESSAGES TOO
      timestamp: DateTime.now(),
      isFromUser: false,
    );
    _messages.add(errorMessage);
    _messagesController.add(_messages);
    
    // Save error message to database too
    await _saveMessageToDatabase(errorMessage);
    
    return errorMessage;
  }

  /// 📸 Get messages with images
  List<Message> getMessagesWithImages() {
    return _messages.where((message) => message.hasImage).toList();
  }

  /// 📸 Count images in current conversation
  int getImageCount() {
    return _messages.where((message) => message.hasImage).length;
  }

  /// 📸 Get latest image message
  Message? getLatestImageMessage() {
    final imageMessages = _messages.where((message) => message.hasImage).toList();
    return imageMessages.isNotEmpty ? imageMessages.last : null;
  }

  /// Get comprehensive debug status
  Map<String, dynamic> getDebugStatus() {
    final imageCount = getImageCount();
    return {
      'currentCharacterId': _currentCharacterId,
      'conversationSessionId': _conversationId,
      'currentConversationDbId': _currentConversationDbId,
      'messageCount': _messages.length,
      'imageCount': imageCount,
      'isConversationPersisted': isConversationPersisted,
      'hasWelcomeMessage': _messages.isNotEmpty && !_messages.first.isFromUser,
      'userEmail': _authService.currentUser?.email,
      'userUid': _authService.currentUser?.uid,
      'lastMessageTime': _messages.isNotEmpty ? _messages.last.timestamp.toString() : 'None',
      'conversationTitle': getConversationTitle(),
      'hasImages': imageCount > 0,
    };
  }

  /// Test conversation saving functionality
  Future<void> testConversationSaving() async {
    try {
      final user = _authService.currentUser;
      print('🧪 === CONVERSATION SAVING TEST ===');
      print('🧪 Current user: ${user?.email}');
      print('🧪 Current conversation DB ID: $_currentConversationDbId');
      print('🧪 Message count: ${_messages.length}');
      print('🧪 Image count: ${getImageCount()}');
      print('🧪 Is conversation persisted: $isConversationPersisted');
      
      if (_currentConversationDbId != null) {
        // Test saving a message
        final testMessage = Message(
          id: _uuid.v4(),
          content: 'Test message for debugging ${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'test_user',
          senderName: 'Test User',
          timestamp: DateTime.now(),
          isFromUser: true,
        );
        
        await _saveMessageToDatabase(testMessage);
        
        print('🧪 ✅ Test message saved successfully');
      } else {
        print('🧪 ⚠️  No active conversation to test with');
      }
      
      print('🧪 === TEST COMPLETE ===');
    } catch (e) {
      print('🧪 ❌ Test saving error: $e');
    }
  }

  /// Get conversation title suggestion
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

  /// Get conversation preview (with image awareness)
  String getConversationPreview() {
    if (_messages.length > 1) {
      final lastMessage = _messages.last;
      if (lastMessage.hasImage) {
        return lastMessage.content.isNotEmpty 
            ? '📷 ${lastMessage.content}'
            : '📷 Shared an image';
      }
      return lastMessage.content.length > 100 
          ? '${lastMessage.content.substring(0, 100)}...'
          : lastMessage.content;
    }
    return '';
  }

  /// Clear current conversation
  void clearConversation() {
    print('🧹 ChatService: Clearing conversation');
    _messages.clear();
    _currentCharacterId = null;
    _conversationId = null;
    _currentConversationDbId = null;
    _messagesController.add(_messages);
  }

  /// Get message count for current conversation
  int get messageCount => _messages.length;

  /// Check if conversation has been saved to database
  bool get isConversationPersisted => _currentConversationDbId != null;

  /// Reload conversation from database
  Future<void> reloadConversation() async {
    if (_currentConversationDbId != null) {
      try {
        final messages = await _conversationService.getConversationMessages(_currentConversationDbId!);
        
        // Ensure chronological order
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        _messages = messages;
        _messagesController.add(_messages);
        
        final imageMessages = messages.where((m) => m.hasImage).length;
        print('ChatService: Reloaded ${messages.length} messages (${imageMessages} with images)');
      } catch (e) {
        print('ChatService: Error reloading conversation: $e');
      }
    }
  }

  /// Export conversation as text (with image indicators)
  String exportConversationAsText() {
    final buffer = StringBuffer();
    buffer.writeln('Conversation Export');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Character: ${_currentCharacterId ?? 'Unknown'}');
    buffer.writeln('Messages: ${_messages.length}');
    buffer.writeln('Images: ${getImageCount()}');
    buffer.writeln('${'=' * 50}');
    
    for (final message in _messages) {
      buffer.writeln();
      if (message.hasImage) {
        buffer.writeln('📷 ${message.senderName} (${_formatTime(message.timestamp)}) shared an image:');
        if (message.imageUrl != null) {
          buffer.writeln('Image URL: ${message.imageUrl}');
        }
      } else {
        buffer.writeln('${message.senderName} (${_formatTime(message.timestamp)}):');
      }
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
        return "Hello! I am Albert Einstein. I'm delighted to discuss the wonders of the universe with you. What questions about physics, science, or life would you like to explore together? Feel free to share images for me to analyze from a scientific perspective!";
      case 'marie_curie':
        return "Greetings! I am Marie Curie. It's wonderful to meet someone interested in science and discovery. What would you like to know about my research or the fascinating world of radioactivity? I'd love to examine any scientific images you might have!";
      case 'shakespeare':
        return "Good morrow to thee! I am William Shakespeare, humble servant of the written word. What tales of love, tragedy, or the human condition shall we explore together? Share images with me, and I shall weave stories from what mine eyes behold!";
      case 'leonardo_da_vinci':
        return "Salve, my curious friend! I am Leonardo da Vinci. Whether 'tis art, science, invention, or the mysteries of nature, I am eager to share my insights with thee! Show me your drawings, inventions, or any visual wonders for my analysis!";
      default:
        return "Hello! I'm ${character.name}. I'm excited to chat with you today and analyze any images you'd like to share. What would you like to discuss?";
    }
  }
}
