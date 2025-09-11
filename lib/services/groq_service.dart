// groq_service.dart - STREAMING VERSION
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

  /// Get character response with STREAMING support
  Stream<String> getCharacterResponseStream(
    Character character, 
    String userMessage, {
    String? conversationId,
    int maxHistoryLength = 10,
    double temperature = 0.8,
    int maxTokens = 400,
  }) async* {
    try {
      // Rate limiting
      await _enforceRateLimit();
      
      // Validate inputs
      if (_apiKey.isEmpty) {
        yield* Stream.error('Groq API key not found in environment variables');
        return;
      }
      
      if (userMessage.trim().isEmpty) {
        yield* Stream.error('User message cannot be empty');
        return;
      }

      // Get or create conversation history
      final historyKey = conversationId ?? '${character.id}_default';
      _conversationHistory[historyKey] ??= [];
      
      // Build messages with conversation context
      final messages = _buildMessages(character, userMessage, historyKey, maxHistoryLength);
      
      final requestBody = {
        'model': 'llama-3.3-70b-versatile',
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true, // ✅ Enable streaming
        'stop': null,
      };

      print('Sending STREAMING request to Groq API for character: ${character.name}');
      
      // Create streaming request
      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'User-Agent': 'AI-Advisor-App/1.0',
        'Accept': 'text/event-stream',
      });
      request.body = jsonEncode(requestBody);

      // Send request and get streaming response
      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        yield* Stream.error('API request failed with status ${streamedResponse.statusCode}');
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
          
          final data = line.substring(6); // Remove 'data: ' prefix
          
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
                yield fullResponse; // ✅ Yield progressive text
              }
            }
          } catch (e) {
            print('Error parsing streaming chunk: $e');
            continue;
          }
        }
      }
      
      // Update conversation history with final response
      if (fullResponse.isNotEmpty) {
        _updateConversationHistory(historyKey, userMessage, fullResponse);
      }
      
      client.close();
      
    } catch (e, stackTrace) {
      print('GroqService streaming error: $e');
      print('Stack trace: $stackTrace');
      yield* Stream.error(_getErrorResponse(e));
    }
  }

  /// Non-streaming version (fallback)
  Future<String> getCharacterResponse(
    Character character, 
    String userMessage, {
    String? conversationId,
    int maxHistoryLength = 10,
    double temperature = 0.8,
    int maxTokens = 400,
  }) async {
    try {
      // Rate limiting
      await _enforceRateLimit();
      
      // Validate inputs
      if (_apiKey.isEmpty) {
        throw Exception('Groq API key not found in environment variables');
      }
      
      if (userMessage.trim().isEmpty) {
        throw Exception('User message cannot be empty');
      }

      // Get or create conversation history
      final historyKey = conversationId ?? '${character.id}_default';
      _conversationHistory[historyKey] ??= [];
      
      // Build messages with conversation context
      final messages = _buildMessages(character, userMessage, historyKey, maxHistoryLength);
      
      final requestBody = {
        'model': 'llama-3.3-70b-versatile',
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': false,
        'stop': null,
      };

      print('Sending request to Groq API for character: ${character.name}');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'User-Agent': 'AI-Advisor-App/1.0',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      return _handleResponse(response, character, userMessage, historyKey);
      
    } catch (e, stackTrace) {
      print('GroqService error: $e');
      print('Stack trace: $stackTrace');
      return _getErrorResponse(e);
    }
  }

  /// Build messages array with system prompt and conversation history
  List<Map<String, String>> _buildMessages(
    Character character, 
    String userMessage, 
    String historyKey,
    int maxHistoryLength,
  ) {
    final messages = <Map<String, String>>[];
    
    // System message with enhanced character prompt
    final systemPrompt = _buildSystemPrompt(character);
    messages.add({
      'role': 'system',
      'content': systemPrompt,
    });
    
    // Add conversation history (keep recent messages for context)
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

  /// Build enhanced system prompt for character
  String _buildSystemPrompt(Character character) {
    final basePrompt = character.promptStyle.isNotEmpty
        ? character.promptStyle
        : 'You are ${character.name}. Respond authentically in their voice and style.';
    
    final enhancedPrompt = '''
$basePrompt

Important guidelines:
- Stay completely in character as ${character.name}
- Use their known speech patterns, vocabulary, and perspectives
- Reference their historical context and time period when relevant
- Keep responses engaging but concise (2-3 paragraphs maximum)
- If asked about modern topics they wouldn't know, respond as they would from their time period
- Show their personality, wisdom, and unique viewpoints
${character.works?.isNotEmpty == true ? '- You may reference your works: ${character.works!.join(", ")}' : ''}
''';
    
    return enhancedPrompt;
  }

  /// Handle non-streaming API response
  String _handleResponse(
    http.Response response, 
    Character character, 
    String userMessage,
    String historyKey,
  ) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Extract response content
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
      
      // Log usage for analytics
      _logUsage(data, character);
      
      return content;
      
    } else {
      final errorBody = response.body;
      print('Groq API Error ${response.statusCode}: $errorBody');
      
      // Handle specific error codes
      switch (response.statusCode) {
        case 401:
          throw Exception('Invalid API key');
        case 429:
          throw Exception('Rate limit exceeded. Please try again in a moment.');
        case 500:
          throw Exception('Groq server error. Please try again later.');
        default:
          throw Exception('API request failed with status ${response.statusCode}');
      }
    }
  }

  /// Update conversation history
  void _updateConversationHistory(String historyKey, String userMessage, String aiResponse) {
    _conversationHistory[historyKey] ??= [];
    
    // Add user message and AI response
    _conversationHistory[historyKey]!.addAll([
      {'role': 'user', 'content': userMessage},
      {'role': 'assistant', 'content': aiResponse},
    ]);
    
    // Keep history reasonable size (last 20 messages = 10 exchanges)
    if (_conversationHistory[historyKey]!.length > 20) {
      _conversationHistory[historyKey] = 
          _conversationHistory[historyKey]!.sublist(_conversationHistory[historyKey]!.length - 20);
    }
  }

  /// Log usage for analytics
  void _logUsage(Map<String, dynamic> responseData, Character character) {
    try {
      final usage = responseData['usage'] as Map<String, dynamic>?;
      if (usage != null) {
        print('API Usage - Character: ${character.name}, '
              'Prompt tokens: ${usage['prompt_tokens']}, '
              'Completion tokens: ${usage['completion_tokens']}, '
              'Total tokens: ${usage['total_tokens']}');
      }
    } catch (e) {
      print('Error logging usage: $e');
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

  /// Get user-friendly error response
  String _getErrorResponse(dynamic error) {
    final errorMessage = error.toString();
    
    if (errorMessage.contains('TimeoutException')) {
      return "I'm thinking deeply about your question, but it's taking longer than expected. Please try again.";
    } else if (errorMessage.contains('Rate limit')) {
      return "I need a moment to gather my thoughts. Please wait a few seconds and try again.";
    } else if (errorMessage.contains('API key')) {
      return "There seems to be an authentication issue. Please contact support.";
    } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
      return "I'm having trouble connecting right now. Please check your internet connection and try again.";
    } else {
      return "I apologize, but I'm having difficulty responding right now. Please try rephrasing your question.";
    }
  }

  /// Clear conversation history for a specific conversation
  void clearConversationHistory(String? conversationId, String characterId) {
    final historyKey = conversationId ?? '${characterId}_default';
    _conversationHistory.remove(historyKey);
  }

  /// Get conversation history length
  int getConversationLength(String? conversationId, String characterId) {
    final historyKey = conversationId ?? '${characterId}_default';
    return _conversationHistory[historyKey]?.length ?? 0;
  }

  /// Check if service is properly configured
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Test API connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.groq.com/openai/v1/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }
}
