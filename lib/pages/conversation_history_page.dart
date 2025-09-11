// lib/pages/conversation_history_page.dart - COMPLETE WITH SORTING
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/character.dart';
import '../services/conversation_service.dart';
import '../services/supabase_service.dart';
import 'chat_page.dart';

class ConversationHistoryPage extends StatefulWidget {
  const ConversationHistoryPage({super.key});

  @override
  State<ConversationHistoryPage> createState() => _ConversationHistoryPageState();
}

class _ConversationHistoryPageState extends State<ConversationHistoryPage> {
  final ConversationService _conversationService = ConversationService();
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Conversation> _conversations = [];
  bool _loading = true;
  bool _showBookmarkedOnly = false;
  bool _newestFirst = true; // Show newest conversations first (default)
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Toggle sort order
  void _toggleSortOrder() {
    setState(() {
      _newestFirst = !_newestFirst;
    });
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _loading = true);
    
    try {
      List<Conversation> conversations;
      
      if (_searchQuery.isNotEmpty) {
        conversations = await _conversationService.searchConversations(_searchQuery);
        // Apply local sorting for search results
        if (_newestFirst) {
          conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        } else {
          conversations.sort((a, b) => a.lastMessageAt.compareTo(b.lastMessageAt));
        }
      } else {
        conversations = await _conversationService.getUserConversations(
          bookmarkedOnly: _showBookmarkedOnly,
          newestFirst: _newestFirst, // Pass sort preference
        );
      }
      
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
      
      print('📋 Loaded ${conversations.length} conversations (${_newestFirst ? 'newest' : 'oldest'} first)');
      
    } catch (e) {
      print('Error loading conversations: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          // Sort toggle button
          IconButton(
            icon: Icon(
              _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
              color: Colors.white,
            ),
            onPressed: _toggleSortOrder,
            tooltip: _newestFirst ? 'Show Oldest First' : 'Show Newest First',
          ),
          // Bookmark filter button
          IconButton(
            icon: Icon(
              _showBookmarkedOnly ? Icons.bookmark : Icons.bookmark_outline,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showBookmarkedOnly = !_showBookmarkedOnly;
              });
              _loadConversations();
            },
            tooltip: _showBookmarkedOnly ? 'Show All' : 'Show Bookmarked',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          // Sort indicator bar
          if (_conversations.isNotEmpty) _buildSortIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadConversations,
              color: Colors.teal,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                  : _conversations.isEmpty
                      ? _buildEmptyState()
                      : _buildConversationsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search conversations...',
          prefixIcon: const Icon(Icons.search, color: Colors.teal),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _loadConversations();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          // Debounce search
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_searchController.text == value) {
              _loadConversations();
            }
          });
        },
      ),
    );
  }

  Widget _buildSortIndicator() {
    return Container(
      width: double.infinity,
      color: Colors.teal.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            _newestFirst ? Icons.schedule : Icons.history,
            size: 16,
            color: Colors.teal.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            'Sorted by: ${_newestFirst ? 'Most Recent First' : 'Oldest First'}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.teal.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_showBookmarkedOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark, size: 12, color: Colors.teal.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Bookmarked Only',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.teal.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showBookmarkedOnly ? Icons.bookmark_outline : Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _showBookmarkedOnly 
                ? 'No bookmarked conversations yet'
                : _searchQuery.isNotEmpty
                    ? 'No conversations found'
                    : 'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showBookmarkedOnly
                ? 'Bookmark conversations by tapping the bookmark icon'
                : _searchQuery.isNotEmpty
                    ? 'Try different keywords or clear the search'
                    : 'Start chatting with characters to see your conversations here',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (!_showBookmarkedOnly && _searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('Start Chatting'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _buildConversationCard(conversation, index);
      },
    );
  }

  Widget _buildConversationCard(Conversation conversation, int index) {
    final isRecent = DateTime.now().difference(conversation.lastMessageAt).inHours < 24;
    
    return Card(
      elevation: isRecent ? 3 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isRecent 
            ? BorderSide(color: Colors.teal.withOpacity(0.3), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Stack(
          children: [
            FutureBuilder<Character?>(
              future: _getCharacterInfo(conversation.characterId),
              builder: (context, snapshot) {
                final character = snapshot.data;
                return CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.teal.shade100,
                  backgroundImage: character?.imageUrl?.isNotEmpty == true
                      ? NetworkImage(character!.imageUrl!)
                      : null,
                  child: character?.imageUrl?.isEmpty ?? true
                      ? Text(
                          character?.name.isNotEmpty == true 
                              ? character!.name[0].toUpperCase() 
                              : '?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade700,
                          ),
                        )
                      : null,
                );
              },
            ),
            // Recent indicator
            if (isRecent)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                conversation.title,
                style: TextStyle(
                  fontWeight: isRecent ? FontWeight.bold : FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (conversation.isBookmarked)
              Icon(Icons.bookmark, color: Colors.teal, size: 16),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conversation.preview != null) ...[
              const SizedBox(height: 4),
              Text(
                conversation.preview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.message, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '${conversation.messageCount} messages',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatDate(conversation.lastMessageAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isRecent ? Colors.teal.shade600 : Colors.grey.shade500,
                    fontWeight: isRecent ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, conversation),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'bookmark',
              child: Row(
                children: [
                  Icon(
                    conversation.isBookmarked 
                        ? Icons.bookmark_remove 
                        : Icons.bookmark_add,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(conversation.isBookmarked 
                      ? 'Remove Bookmark' 
                      : 'Add Bookmark'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openConversation(conversation),
      ),
    );
  }

  Future<Character?> _getCharacterInfo(String characterId) async {
    try {
      return await _supabaseService.fetchCharacterById(characterId);
    } catch (e) {
      print('Error fetching character info: $e');
      return null;
    }
  }

  void _handleMenuAction(String action, Conversation conversation) async {
    switch (action) {
      case 'bookmark':
        try {
          final newStatus = await _conversationService.toggleBookmark(conversation.id);
          setState(() {
            final index = _conversations.indexWhere((c) => c.id == conversation.id);
            if (index != -1) {
              _conversations[index] = conversation.copyWith(isBookmarked: newStatus);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newStatus ? 'Bookmarked!' : 'Bookmark removed'),
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating bookmark: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'delete':
        _showDeleteDialog(conversation);
        break;
    }
  }

  void _showDeleteDialog(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this conversation?'),
            const SizedBox(height: 8),
            Text(
              '"${conversation.title}"',
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text('This action cannot be undone.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _conversationService.deleteConversation(conversation.id);
                _loadConversations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversation deleted'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting conversation: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openConversation(Conversation conversation) async {
    try {
      final character = await _getCharacterInfo(conversation.characterId);
      if (character != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              character: character,
              existingConversationId: conversation.id,
            ),
          ),
        );
        
        // Refresh conversations when returning from chat
        if (result == null) {
          _loadConversations();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Character not found'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening conversation: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
