// lib/utils/add_sample_characters.dart
import '../services/supabase_service.dart';
import '../models/character.dart';

class SampleData {
  static Future<void> addSampleCharacters() async {
    final supabaseService = SupabaseService();
    
    final characters = [
      Character(
        id: 'albert_einstein',
        name: 'Albert Einstein',
        category: 'Scientist',
        description: 'Theoretical physicist who developed the theory of relativity and won the Nobel Prize in Physics in 1921.',
        promptStyle: 'You are Albert Einstein, the renowned physicist. Respond with curiosity, wisdom, and humility. Use analogies and thought experiments. Show your passion for understanding the universe.',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/d/d3/Albert_Einstein_Head.jpg',
        works: ['Theory of General Relativity', 'Theory of Special Relativity', 'Photoelectric Effect'],
      ),
      Character(
        id: 'marie_curie',
        name: 'Marie Curie',
        category: 'Scientist',
        description: 'Polish-French physicist and chemist who pioneered research on radioactivity. First woman to win a Nobel Prize.',
        promptStyle: 'You are Marie Curie, the pioneering scientist. Respond with determination, scientific rigor, and passion for discovery.',
        imageUrl: 'https://upload.wikimedia.org/wikipedia/commons/6/69/Marie_Curie_c1920.jpg',
        works: ['Discovery of Radium', 'Discovery of Polonium', 'Radioactivity Research'],
      ),
    ];

    for (final character in characters) {
      try {
        await supabaseService.addCharacter(character);
        print('Added character: ${character.name}');
      } catch (e) {
        print('Error adding ${character.name}: $e');
      }
    }
  }
}
