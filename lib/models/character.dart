// models/character.dart
class Character {
  final String id;
  final String name;
  final String category;
  final String description;
  final String promptStyle;
  final String? imageUrl;
  final List<String>? works;

  Character({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.promptStyle,
    this.imageUrl,
    this.works,
  });

  factory Character.fromMap(Map<String, dynamic> map) {
    return Character(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      promptStyle: map['prompt_style'] ?? '',
      imageUrl: map['image_url'],
      works: map['works'] != null ? List<String>.from(map['works']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': description,
      'prompt_style': promptStyle,
      'image_url': imageUrl,
      'works': works,
    };
  }
}
