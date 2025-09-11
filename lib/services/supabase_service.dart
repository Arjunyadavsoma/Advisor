// supabase_service.dart - FINAL CORRECTED VERSION
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/character.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  
  // Cache for frequently accessed data
  final Map<String, List<Character>> _characterCache = {};
  final Map<String, Character> _singleCharacterCache = {};
  final Map<String, int> _countCache = {};
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Fetch all characters with caching and pagination
  Future<List<Character>> fetchCharacters({
    String? category,
    int limit = 50,
    int offset = 0,
    bool useCache = true,
  }) async {
    try {
      // Check cache first
      final cacheKey = '${category ?? 'all'}_${limit}_$offset';
      if (useCache && _isDataCached(cacheKey)) {
        print('Returning cached characters for: $cacheKey');
        return _characterCache[cacheKey]!;
      }

      print('Fetching characters from database...');
      var query = _client.from('characters').select();
      
      // Apply filters
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      
      // Apply pagination and ordering
      final response = await query
          .order('name')
          .range(offset, offset + limit - 1);

      final characters = (response as List<dynamic>)
          .map((e) => Character.fromMap(e as Map<String, dynamic>))
          .toList();
      
      // Cache the results
      if (useCache) {
        _characterCache[cacheKey] = characters;
        _lastCacheUpdate = DateTime.now();
      }
      
      print('Fetched ${characters.length} characters');
      return characters;
      
    } catch (error) {
      print('Failed to fetch characters: $error');
      throw Exception('Failed to fetch characters: $error');
    }
  }

  /// Fetch character by ID with caching
  Future<Character> fetchCharacterById(String id, {bool useCache = true}) async {
    try {
      // Check cache first
      if (useCache && _singleCharacterCache.containsKey(id)) {
        print('Returning cached character: $id');
        return _singleCharacterCache[id]!;
      }

      print('Fetching character from database: $id');
      final response = await _client
          .from('characters')
          .select()
          .eq('id', id)
          .single();

      final character = Character.fromMap(response);
      
      // Cache the result
      if (useCache) {
        _singleCharacterCache[id] = character;
      }
      
      return character;
      
    } catch (error) {
      print('Failed to fetch character: $error');
      throw Exception('Failed to fetch character: $error');
    }
  }

  /// Get character count - SIMPLIFIED VERSION THAT WORKS
  Future<int> getCharacterCount({String? category, bool useCache = true}) async {
    try {
      final cacheKey = 'count_${category ?? 'all'}';
      
      // Check cache first
      if (useCache && _countCache.containsKey(cacheKey) && 
          _lastCacheUpdate != null &&
          DateTime.now().difference(_lastCacheUpdate!).inMinutes < 2) {
        return _countCache[cacheKey]!;
      }

      print('Getting character count for: ${category ?? 'all'}');
      
      // Simple method: Fetch all and count locally
      // This is reliable and works with all Supabase versions
      var query = _client.from('characters').select('id'); // Only select ID for efficiency
      
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      
      final response = await query;
      final count = (response as List<dynamic>).length;
      
      // Cache the count
      if (useCache) {
        _countCache[cacheKey] = count;
        _lastCacheUpdate = DateTime.now();
      }
      
      print('Character count for ${category ?? 'all'}: $count');
      return count;
      
    } catch (error) {
      print('Failed to get character count: $error');
      return 0; // Return 0 instead of throwing exception
    }
  }

  /// Enhanced search with multiple criteria
  Future<List<Character>> searchCharacters(
    String searchTerm, {
    String? category,
    int limit = 20,
    bool useCache = false, // Search results typically not cached
  }) async {
    try {
      if (searchTerm.trim().isEmpty) {
        return [];
      }

      print('Searching for: "$searchTerm" in category: ${category ?? 'all'}');
      
      var query = _client.from('characters').select();
      
      // Build search conditions - using ilike for case-insensitive search
      query = query.or(
        'name.ilike.%$searchTerm%,description.ilike.%$searchTerm%'
      );
      
      // Apply category filter if specified
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      
      final response = await query
          .order('name')
          .limit(limit);

      final results = (response as List<dynamic>)
          .map((e) => Character.fromMap(e as Map<String, dynamic>))
          .toList();
      
      print('Search returned ${results.length} results');
      return results;
      
    } catch (error) {
      print('Failed to search characters: $error');
      throw Exception('Failed to search characters: $error');
    }
  }

  /// Get characters by category with enhanced filtering
  Future<List<Character>> getCharactersByCategory(
    String category, {
    int limit = 50,
    int offset = 0,
    String orderBy = 'name',
    bool ascending = true,
  }) async {
    try {
      final response = await _client
          .from('characters')
          .select()
          .eq('category', category)
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return (response as List<dynamic>)
          .map((e) => Character.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('Failed to fetch characters by category: $error');
      throw Exception('Failed to fetch characters by category: $error');
    }
  }

  /// Get available categories
  Future<List<String>> getCategories() async {
    try {
      final response = await _client
          .from('characters')
          .select('category')
          .order('category');

      final categories = (response as List<dynamic>)
          .map((e) => e['category'] as String)
          .toSet()
          .where((category) => category.isNotEmpty) // Filter out empty categories
          .toList();
      
      categories.sort();
      return categories;
    } catch (error) {
      print('Failed to fetch categories: $error');
      throw Exception('Failed to fetch categories: $error');
    }
  }

  /// Add character with validation
  Future<String> addCharacter(Character character) async {
    try {
      // Validate character data
      _validateCharacter(character);
      
      final characterData = {
        'id': character.id,
        'name': character.name.trim(),
        'category': character.category.trim(),
        'description': character.description.trim(),
        'prompt_style': character.promptStyle.trim(),
        'image_url': character.imageUrl,
        'works': character.works ?? [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _client
          .from('characters')
          .insert(characterData)
          .select()
          .single();

      // Clear cache to ensure fresh data
      _clearCache();
      
      print('Successfully added character: ${character.name}');
      return response['id'] as String;
      
    } catch (error) {
      print('Failed to add character: $error');
      throw Exception('Failed to add character: $error');
    }
  }

  /// Update character with validation
  Future<void> updateCharacter(Character character) async {
    try {
      _validateCharacter(character);
      
      final updateData = {
        'name': character.name.trim(),
        'category': character.category.trim(),
        'description': character.description.trim(),
        'prompt_style': character.promptStyle.trim(),
        'image_url': character.imageUrl,
        'works': character.works ?? [],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _client
          .from('characters')
          .update(updateData)
          .eq('id', character.id);

      // Clear cache to ensure fresh data
      _clearCache();
      
      print('Successfully updated character: ${character.name}');
      
    } catch (error) {
      print('Failed to update character: $error');
      throw Exception('Failed to update character: $error');
    }
  }

  /// Delete character with cascade handling
  Future<void> deleteCharacter(String id) async {
    try {
      // First check if character exists
      final character = await fetchCharacterById(id, useCache: false);
      
      // Delete the character
      await _client
          .from('characters')
          .delete()
          .eq('id', id);

      // Clear cache
      _clearCache();
      
      print('Successfully deleted character: ${character.name}');
      
    } catch (error) {
      print('Failed to delete character: $error');
      throw Exception('Failed to delete character: $error');
    }
  }

  /// Batch operations for multiple characters
  Future<void> addMultipleCharacters(List<Character> characters) async {
    try {
      final batch = characters.map((character) => {
        'id': character.id,
        'name': character.name.trim(),
        'category': character.category.trim(),
        'description': character.description.trim(),
        'prompt_style': character.promptStyle.trim(),
        'image_url': character.imageUrl,
        'works': character.works ?? [],
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).toList();

      await _client.from('characters').insert(batch);
      _clearCache();
      
      print('Successfully added ${characters.length} characters');
      
    } catch (error) {
      print('Failed to add multiple characters: $error');
      throw Exception('Failed to add multiple characters: $error');
    }
  }

  /// Get database statistics - SIMPLIFIED VERSION
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final totalCount = await getCharacterCount(useCache: false);
      final categories = await getCategories();
      
      final categoryStats = <String, int>{};
      for (final category in categories) {
        try {
          categoryStats[category] = await getCharacterCount(
            category: category, 
            useCache: false
          );
        } catch (e) {
          print('Error getting count for category $category: $e');
          categoryStats[category] = 0;
        }
      }

      return {
        'totalCharacters': totalCount,
        'totalCategories': categories.length,
        'categoryCounts': categoryStats,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    } catch (error) {
      print('Failed to get database stats: $error');
      return {
        'error': error.toString(),
        'totalCharacters': 0,
        'totalCategories': 0,
        'categoryCounts': <String, int>{},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get paginated characters with total count
  Future<Map<String, dynamic>> getPaginatedCharacters({
    String? category,
    int page = 1,
    int itemsPerPage = 10,
  }) async {
    try {
      final offset = (page - 1) * itemsPerPage;
      
      // Get characters for this page
      final characters = await fetchCharacters(
        category: category,
        limit: itemsPerPage,
        offset: offset,
        useCache: false,
      );
      
      // Get total count
      final totalCount = await getCharacterCount(category: category);
      final totalPages = totalCount > 0 ? (totalCount / itemsPerPage).ceil() : 0;
      
      return {
        'characters': characters,
        'pagination': {
          'currentPage': page,
          'itemsPerPage': itemsPerPage,
          'totalItems': totalCount,
          'totalPages': totalPages,
          'hasNextPage': page < totalPages,
          'hasPreviousPage': page > 1,
        }
      };
    } catch (error) {
      print('Failed to get paginated characters: $error');
      throw Exception('Failed to get paginated characters: $error');
    }
  }

  /// Check if character exists
  Future<bool> characterExists(String id) async {
    try {
      await fetchCharacterById(id, useCache: false);
      return true;
    } catch (error) {
      return false;
    }
  }

  /// Get random characters
  Future<List<Character>> getRandomCharacters({int limit = 5}) async {
    try {
      // Get all characters and shuffle them
      final allCharacters = await fetchCharacters(limit: 1000, useCache: true);
      
      if (allCharacters.isEmpty) return [];
      
      allCharacters.shuffle();
      return allCharacters.take(limit).toList();
    } catch (error) {
      print('Failed to get random characters: $error');
      return [];
    }
  }

  /// Get all characters (no limit) - useful for small datasets
  Future<List<Character>> getAllCharacters({String? category}) async {
    try {
      var query = _client.from('characters').select();
      
      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      
      final response = await query.order('name');
      
      return (response as List<dynamic>)
          .map((e) => Character.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (error) {
      print('Failed to get all characters: $error');
      throw Exception('Failed to get all characters: $error');
    }
  }

  /// Validate character data
  void _validateCharacter(Character character) {
    if (character.name.trim().isEmpty) {
      throw Exception('Character name cannot be empty');
    }
    if (character.category.trim().isEmpty) {
      throw Exception('Character category cannot be empty');
    }
    if (character.description.trim().isEmpty) {
      throw Exception('Character description cannot be empty');
    }
    if (character.promptStyle.trim().isEmpty) {
      throw Exception('Character prompt style cannot be empty');
    }
    
    // Additional validations
    if (character.name.length > 100) {
      throw Exception('Character name is too long (max 100 characters)');
    }
    if (character.description.length > 1000) {
      throw Exception('Character description is too long (max 1000 characters)');
    }
  }

  /// Check if data is cached and not expired
  bool _isDataCached(String cacheKey) {
    return _characterCache.containsKey(cacheKey) &&
           _lastCacheUpdate != null &&
           DateTime.now().difference(_lastCacheUpdate!).inMinutes < _cacheExpiry.inMinutes;
  }

  /// Clear all caches
  void _clearCache() {
    _characterCache.clear();
    _singleCharacterCache.clear();
    _countCache.clear();
    _lastCacheUpdate = null;
  }

  /// Clear specific cache entry
  void clearSpecificCache(String cacheKey) {
    _characterCache.remove(cacheKey);
  }

  /// Test database connection
  Future<bool> testConnection() async {
    try {
      await _client.from('characters').select('id').limit(1);
      return true;
    } catch (e) {
      print('Database connection test failed: $e');
      return false;
    }
  }

  /// Force refresh cache
  void refreshCache() {
    _clearCache();
  }

  /// Get health check info
  Future<Map<String, dynamic>> getHealthCheck() async {
    try {
      final startTime = DateTime.now();
      
      // Test basic connectivity
      final isConnected = await testConnection();
      
      final endTime = DateTime.now();
      final responseTime = endTime.difference(startTime).inMilliseconds;
      
      return {
        'status': isConnected ? 'healthy' : 'unhealthy',
        'responseTime': responseTime,
        'timestamp': DateTime.now().toIso8601String(),
        'cacheSize': _characterCache.length,
      };
    } catch (error) {
      return {
        'status': 'error',
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
