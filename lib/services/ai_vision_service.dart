// lib/services/ai_vision_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/character.dart';

class AIVisionService {
  final String _openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  /// Analyze image with character-specific perspective
  Future<String> analyzeImageWithCharacter(
    String imageUrl, 
    Character character, 
    String userMessage,
  ) async {
    try {
      if (_openAIApiKey.isEmpty) {
        return _getFallbackResponse(character, userMessage);
      }

      final prompt = _buildCharacterSpecificPrompt(character, userMessage);

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_openAIApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'gpt-4-vision-preview',
          'messages': [
            {
              'role': 'system',
              'content': prompt,
            },
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': userMessage.isEmpty 
                      ? 'Please analyze this image from your perspective.'
                      : userMessage,
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': imageUrl,
                  },
                },
              ],
            },
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        return content ?? _getFallbackResponse(character, userMessage);
      } else {
        print('Vision API error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(character, userMessage);
      }
    } catch (e) {
      print('Error analyzing image: $e');
      return _getFallbackResponse(character, userMessage);
    }
  }

  /// Build character-specific analysis prompt
  String _buildCharacterSpecificPrompt(Character character, String userMessage) {
    switch (character.id) {
      case 'albert_einstein':
        return '''You are Albert Einstein. Analyze images through the lens of physics and scientific inquiry. Look for:
- Physical phenomena and scientific principles
- Mathematical concepts and relationships  
- Natural patterns and scientific beauty
- Opportunities to explain complex physics simply
Respond in Einstein's thoughtful, curious manner with "Ach, this is most fascinating..." style phrases.''';

      case 'marie_curie':
        return '''You are Marie Curie. Analyze images with a focus on:
- Chemical processes and scientific methodology
- Laboratory equipment and experimental setups
- Natural phenomena from a chemistry perspective
- The intersection of science and discovery
Speak with determination and scientific precision, often relating to your research experiences.''';

      case 'leonardo_da_vinci':
        return '''You are Leonardo da Vinci. Examine images as both artist and scientist:
- Artistic composition, light, shadow, and technique
- Engineering and mechanical principles
- Anatomical accuracy and natural forms
- Innovation and creative problem-solving
Respond with Renaissance curiosity and artistic insight, mixing Italian phrases naturally.''';

      case 'shakespeare':
        return '''You are William Shakespeare. View images through the lens of storytelling and human nature:
- Emotional content and human drama
- Symbolic meaning and metaphorical significance
- Beauty, tragedy, and the human condition
- Poetic inspiration and narrative possibilities
Respond in eloquent, slightly archaic English with poetic flair.''';

      default:
        return '''You are ${character.name}. Analyze this image from your unique historical perspective and expertise. 
Provide insights that reflect your knowledge, personality, and way of thinking. 
Be authentic to your character while offering valuable analysis.''';
    }
  }

  /// Fallback response when AI vision is unavailable
  String _getFallbackResponse(Character character, String userMessage) {
    switch (character.id) {
      case 'albert_einstein':
        return "Ach, what a fascinating image you've shared! While I cannot see all the details at this moment, I can sense there is much to discuss about what you've shown me. Please describe what you'd like me to focus on, and I shall share my thoughts on the physics and science involved!";
      
      case 'marie_curie':
        return "What an intriguing image! Though I cannot analyze it in full detail right now, I am eager to discuss what you've shared. Tell me more about what you're curious about, and I'll apply my scientific knowledge to help you understand it better.";
      
      case 'leonardo_da_vinci':
        return "Ah, un'immagine interessante! While I cannot perceive all the artistic and scientific details at this moment, I am most curious about your creation. Describe to me what you wish me to examine, and I shall offer insights from both my artistic and scientific perspectives!";
      
      case 'shakespeare':
        return "What a wondrous visual tale thou hast shared! Though mine eyes cannot behold every detail presently, I sense great meaning within. Prithee, tell me more of what thou wouldst have me observe, and I shall weave words around thy vision with poetic insight!";
      
      default:
        return "I see you've shared an image with me! While I cannot analyze all the visual details at this moment, I'd love to discuss what you've shown me. Please tell me more about what you'd like me to focus on, and I'll share my thoughts from my unique perspective.";
    }
  }
}
