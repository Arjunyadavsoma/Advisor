import 'dart:convert';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/character.dart';

class GroqService {
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  
  // Conversation history for context
  final Map<String, List<Map<String, String>>> _conversationHistory = {};
  
  // Rate limiting
  DateTime? _lastRequestTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 500);

  /// Get character response with streaming support - UPDATED MODEL
  Stream<String> getCharacterResponseStream(
    Character character, 
    String userMessage, {
    String? conversationId,
    int maxHistoryLength = 8,
    double temperature = 0.7,
    int maxTokens = 400,
  }) async* {
    try {
      print('🤖 🎬 Starting Groq streaming response...');
      
      // Validate API key first
      if (_apiKey.isEmpty) {
        print('🤖 ❌ No GROQ_API_KEY found in environment');
        yield* Stream.error('Groq API key not configured');
        return;
      }
      
      if (userMessage.trim().isEmpty) {
        yield* Stream.error('User message cannot be empty');
        return;
      }

      // Rate limiting
      await _enforceRateLimit();

      // Get conversation history
      final historyKey = conversationId ?? '${character.id}_default';
      _conversationHistory[historyKey] ??= [];
      
      // Build messages
      final messages = _buildSimpleMessages(character, userMessage, historyKey, maxHistoryLength);
      
      final requestBody = {
        'model': 'llama-3.1-8b-instant', // ✅ UPDATED MODEL
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
        'top_p': 1,
        'stop': null,
      };

      print('🤖 Request body: ${jsonEncode(requestBody)}');
      
      // Create streaming request
      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      });
      request.body = jsonEncode(requestBody);

      // Send request and get streaming response
      final client = http.Client();
      final streamedResponse = await client.send(request);

      print('🤖 Response status: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        print('🤖 ❌ Error response: $errorBody');
        yield* Stream.error('API request failed: ${streamedResponse.statusCode} - $errorBody');
        client.close();
        return;
      }

      String fullResponse = '';
      
      // Process streaming response
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        
        for (String line in lines) {
          line = line.trim();
          
          if (line.isEmpty || !line.startsWith('data: ')) {
            continue;
          }
          
          final data = line.substring(6);
          
          if (data == '[DONE]') {
            break;
          }
          
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final choices = json['choices'] as List?;
            
            if (choices?.isNotEmpty == true) {
              final choice = choices!.first as Map<String, dynamic>;
              final delta = choice['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              
              if (content != null) {
                fullResponse += content;
                yield fullResponse;
              }
            }
          } catch (e) {
            continue;
          }
        }
      }
      
      // Update conversation history
      if (fullResponse.isNotEmpty) {
        _updateConversationHistory(historyKey, userMessage, fullResponse);
        print('🤖 ✅ Streaming completed: ${fullResponse.length} chars');
      }
      
      client.close();
      
    } catch (e) {
      print('🤖 ❌ Streaming error: $e');
      yield* Stream.error(_getErrorResponse(e));
    }
  }

  /// Non-streaming version - UPDATED MODEL
  Future<String> getCharacterResponse(
    Character character, 
    String userMessage, {
    String? conversationId,
    int maxHistoryLength = 8,
    double temperature = 0.7,
    int maxTokens = 400,
  }) async {
    try {
      print('🤖 📝 Starting Groq regular response...');
      
      // Validate API key
      if (_apiKey.isEmpty) {
        throw Exception('Groq API key not found in environment variables');
      }
      
      if (userMessage.trim().isEmpty) {
        throw Exception('User message cannot be empty');
      }

      // Rate limiting
      await _enforceRateLimit();

      // Get conversation history
      final historyKey = conversationId ?? '${character.id}_default';
      _conversationHistory[historyKey] ??= [];
      
      // Build messages
      final messages = _buildSimpleMessages(character, userMessage, historyKey, maxHistoryLength);
      
      final requestBody = {
        'model': 'llama-3.1-8b-instant', // ✅ UPDATED MODEL
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': false,
        'top_p': 1,
        'stop': null,
      };

      print('🤖 Making regular request to Groq...');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response, character, userMessage, historyKey);
      
    } catch (e) {
      print('🤖 ❌ Regular response error: $e');
      return _getErrorResponse(e);
    }
  }

  /// Build simplified messages
  List<Map<String, String>> _buildSimpleMessages(
    Character character, 
    String userMessage, 
    String historyKey,
    int maxHistoryLength,
  ) {
    final messages = <Map<String, String>>[];
    
    // Simplified system prompt
    messages.add({
      'role': 'system',
      'content': _buildSimpleSystemPrompt(character),
    });
    
    // Add limited conversation history
    final history = _conversationHistory[historyKey] ?? [];
    final recentHistory = history.length > maxHistoryLength 
        ? history.sublist(history.length - maxHistoryLength)
        : history;
    
    messages.addAll(recentHistory);
    
    // Add current user message
    messages.add({
      'role': 'user', 
      'content': userMessage,
    });
    
    return messages;
  }

  /// Simplified system prompt
  String _buildSimpleSystemPrompt(Character character) {
    switch (character.id) {
      case 'sun_tzu':
        return 'You are Sun Tzu, the ancient Chinese military strategist and philosopher. Respond with wisdom about strategy, leadership, and warfare. Use your teachings from The Art of War. Be concise and insightful.';
      
      case 'socrates':
        return 'You are Socrates, the ancient Greek philosopher. Ask probing questions and guide users to discover truth through dialogue. Use the Socratic method. Be curious and wise.';
      
      case 'albert_einstein':
        return 'You are Albert Einstein. Explain scientific concepts simply and show curiosity about the universe. Reference physics and relativity when relevant. Be thoughtful and encouraging.';
      
      case 'shakespeare':
        return 'You are William Shakespeare. Respond with eloquent language and poetic insight. Use Early Modern English style and reference human nature and drama.';
      
      default:
        return 'You are ${character.name}. Respond authentically in their voice and style, sharing wisdom from their expertise. Be engaging and stay in character.';
    }
  }

  /// Handle API response
  String _handleResponse(
    http.Response response, 
    Character character, 
    String userMessage,
    String historyKey,
  ) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      final choices = data['choices'] as List?;
      if (choices?.isEmpty ?? true) {
        throw Exception('No response choices returned from API');
      }
      
      final choice = choices!.first as Map<String, dynamic>;
      final message = choice['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String?;
      
      if (content?.isEmpty ?? true) {
        throw Exception('Empty response content from API');
      }
      
      // Update conversation history
      _updateConversationHistory(historyKey, userMessage, content!);
      
      print('🤖 ✅ Regular response completed: ${content.length} characters');
      return content;
      
    } else {
      final errorBody = response.body;
      print('🤖 ❌ API Error ${response.statusCode}: $errorBody');
      
      switch (response.statusCode) {
        case 401:
          throw Exception('Invalid Groq API key');
        case 429:
          throw Exception('Rate limit exceeded. Please try again in a moment.');
        case 400:
          throw Exception('Invalid request format. Check your Groq API configuration.');
        default:
          throw Exception('API request failed with status ${response.statusCode}');
      }
    }
  }

  /// Update conversation history
  void _updateConversationHistory(String historyKey, String userMessage, String aiResponse) {
    _conversationHistory[historyKey] ??= [];
    
    _conversationHistory[historyKey]!.addAll([
      {'role': 'user', 'content': userMessage},
      {'role': 'assistant', 'content': aiResponse},
    ]);
    
    // Keep history reasonable size
    if (_conversationHistory[historyKey]!.length > 16) {
      _conversationHistory[historyKey] = 
          _conversationHistory[historyKey]!.sublist(_conversationHistory[historyKey]!.length - 16);
    }
  }

  /// Enforce rate limiting
  Future<void> _enforceRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Get error response
  String _getErrorResponse(dynamic error) {
    final errorMessage = error.toString();
    
    if (errorMessage.contains('API key')) {
      return "I'm having trouble with my connection. Please check that your Groq API key is configured correctly.";
    } else if (errorMessage.contains('Rate limit')) {
      return "I need a moment to gather my thoughts. Please wait a few seconds and try again.";
    } else if (errorMessage.contains('400')) {
      return "I'm having trouble understanding the request format. Please try again.";
    } else {
      return "I apologize, but I'm having difficulty responding right now. Please try again in a moment.";
    }
  }

  /// Clear conversation history
  void clearConversationHistory(String? conversationId, String characterId) {
    final historyKey = conversationId ?? '${characterId}_default';
    _conversationHistory.remove(historyKey);
    print('🧹 Cleared conversation history for: $historyKey');
  }

  /// Get conversation length
  int getConversationLength(String? conversationId, String characterId) {
    final historyKey = conversationId ?? '${characterId}_default';
    return _conversationHistory[historyKey]?.length ?? 0;
  }

  /// Check if configured
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Test connection
  Future<bool> testConnection() async {
    try {
      print('🤖 🧪 Testing Groq connection...');
      
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      final success = response.statusCode == 200;
      print('🤖 🧪 Connection test: ${success ? "✅ Success" : "❌ Failed"}');
      
      if (!success) {
        print('🤖 🧪 Error response: ${response.body}');
      }
      
      return success;
    } catch (e) {
      print('🤖 🧪 Connection test failed: $e');
      return false;
    }
  }
}
