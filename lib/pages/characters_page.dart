// lib/pages/characters_page.dart
import 'package:flutter/material.dart';
import 'package:myapp/pages/chat_page.dart';
import '../services/supabase_service.dart';
import '../models/character.dart';

class CharactersPage extends StatefulWidget {
  const CharactersPage({super.key});

  @override
  State<CharactersPage> createState() => _CharactersPageState();
}

class _CharactersPageState extends State<CharactersPage> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Character> _characters = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;
  bool _searching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      
      final futures = await Future.wait([
        _supabaseService.fetchCharacters(),
        _supabaseService.getCategories(),
      ]);
      
      if (mounted) {
        setState(() {
          _characters = futures[0] as List<Character>;
          _categories = futures[1] as List<String>;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading characters: $e')),
        );
      }
    }
  }

  Future<void> _searchCharacters(String query) async {
    if (query.isEmpty) {
      _loadData();
      return;
    }

    try {
      setState(() => _searching = true);
      
      final results = await _supabaseService.searchCharacters(
        query,
        category: _selectedCategory,
      );
      
      if (mounted) {
        setState(() {
          _characters = results;
          _searching = false;
        });
      }
    } catch (e) {
      print('Search error: $e');
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _filterByCategory(String? category) async {
    try {
      setState(() {
        _selectedCategory = category;
        _loading = true;
      });
      
      final characters = await _supabaseService.fetchCharacters(
        category: category,
      );
      
      if (mounted) {
        setState(() {
          _characters = characters;
          _loading = false;
        });
      }
    } catch (e) {
      print('Filter error: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Historical Characters',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _characters.isEmpty
                    ? _buildEmptyState()
                    : _buildCharactersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search characters...',
              prefixIcon: const Icon(Icons.search, color: Colors.teal),
              suffixIcon: _searching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                            _loadData();
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.teal.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              if (value.isEmpty) {
                _loadData();
              } else {
                // Debounce search
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_searchController.text == value) {
                    _searchCharacters(value);
                  }
                });
              }
            },
          ),
          const SizedBox(height: 16),
          
          // Category Filter
          if (_categories.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length + 1, // +1 for "All" option
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildCategoryChip('All', null);
                  }
                  final category = _categories[index - 1];
                  return _buildCategoryChip(category, category);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _filterByCategory(category),
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.teal.shade100,
        labelStyle: TextStyle(
          color: isSelected ? Colors.teal.shade700 : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(
          color: isSelected ? Colors.teal : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No characters found for "$_searchQuery"'
                : 'No characters available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Characters will appear here once added',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharactersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _characters.length,
      itemBuilder: (context, index) {
        final character = _characters[index];
        return _buildCharacterCard(character);
      },
    );
  }

  Widget _buildCharacterCard(Character character) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.teal.shade100,
          backgroundImage: character.imageUrl?.isNotEmpty == true
              ? NetworkImage(character.imageUrl!)
              : null,
          child: character.imageUrl?.isEmpty ?? true
              ? Text(
                  character.name.isNotEmpty ? character.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                )
              : null,
        ),
        title: Text(
          character.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade200),
              ),
              child: Text(
                character.category,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              character.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.teal,
        ),
        onTap: () => _startChat(character),
      ),
    );
  }

  void _startChat(Character character) {
    Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatPage(character: character),
    ),
  );
    // TODO: Navigate to chat page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting chat with ${character.name}...'),
        backgroundColor: Colors.teal,
      ),
    );
    
    // For now, show character details
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(character.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Category: ${character.category}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(character.description),
              if (character.works?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notable Works:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...character.works!.map((work) => Text('• $work')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Start actual chat
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }
}
