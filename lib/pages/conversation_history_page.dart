import 'package:flutter/material.dart';
import 'package:myapp/widgets/custom_card.dart';
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
  bool _newestFirst = true;
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
        if (_newestFirst) {
          conversations.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
        } else {
          conversations.sort((a, b) => a.lastMessageAt.compareTo(b.lastMessageAt));
        }
      } else {
        conversations = await _conversationService.getUserConversations(
          bookmarkedOnly: _showBookmarkedOnly,
          newestFirst: _newestFirst,
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
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchSection(),
            _buildFilterChips(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadConversations,
                color: const Color(0xFF2196F3),
                child: _loading
                    ? _buildLoadingState()
                    : _conversations.isEmpty
                        ? _buildEmptyState()
                        : _buildConversationsList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Chat History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                _newestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                size: 20,
                color: const Color(0xFF2196F3),
              ),
              onPressed: _toggleSortOrder,
              splashRadius: 20,
              tooltip: _newestFirst ? 'Show Oldest First' : 'Show Newest First',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(
                Icons.search_rounded,
                color: Colors.grey[500],
                size: 22,
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadConversations();
                    },
                    splashRadius: 20,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
            if (value.isEmpty) {
              _loadConversations();
            } else {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchController.text == value) {
                  _loadConversations();
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 70,
      padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
      child: Row(
        children: [
          _buildFilterChip(
            label: _newestFirst ? 'Newest First' : 'Oldest First',
            icon: _newestFirst ? Icons.schedule_rounded : Icons.history_rounded,
            isSelected: false,
            onTap: _toggleSortOrder,
          ),
          const SizedBox(width: 12),
          _buildFilterChip(
            label: 'Bookmarked',
            icon: Icons.bookmark_rounded,
            isSelected: _showBookmarkedOnly,
            onTap: () {
              setState(() {
                _showBookmarkedOnly = !_showBookmarkedOnly;
              });
              _loadConversations();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2196F3) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF666666),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF666666),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                _showBookmarkedOnly 
                    ? Icons.bookmark_outline_rounded 
                    : Icons.chat_bubble_outline_rounded,
                size: 40,
                color: const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _showBookmarkedOnly 
                  ? 'No bookmarked chats'
                  : _searchQuery.isNotEmpty
                      ? 'No conversations found'
                      : 'No conversations yet',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showBookmarkedOnly
                  ? 'Bookmark conversations by tapping the bookmark icon during chats'
                  : _searchQuery.isNotEmpty
                      ? 'Try different keywords or clear the search'
                      : 'Start chatting with AI characters to see your conversations here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_showBookmarkedOnly && _searchQuery.isEmpty) ...[
              const SizedBox(height: 32),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                  child: const Text(
                    'Start Chatting',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        return _buildConversationCard(conversation, index);
      },
    );
  }

  Widget _buildConversationCard(Conversation conversation, int index) {
    final isRecent = DateTime.now().difference(conversation.lastMessageAt).inHours < 24;
    
    return Padding(
      padding: EdgeInsets.only(bottom: index == _conversations.length - 1 ? 0 : 16),
      child: CustomCard(
        onTap: () => _openConversation(conversation),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      FutureBuilder<Character?>(
                        future: _getCharacterInfo(conversation.characterId),
                        builder: (context, snapshot) {
                          final character = snapshot.data;
                          return Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              image: character?.imageUrl?.isNotEmpty == true
                                  ? DecorationImage(
                                      image: NetworkImage(character!.imageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: character?.imageUrl?.isEmpty ?? true
                                ? Center(
                                    child: Text(
                                      character?.name.isNotEmpty == true 
                                          ? character!.name[0].toUpperCase() 
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      if (isRecent)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                conversation.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isRecent ? FontWeight.w700 : FontWeight.w600,
                                  color: const Color(0xFF1A1A1A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conversation.isBookmarked)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.bookmark_rounded,
                                  size: 14,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                          ],
                        ),
                        if (conversation.preview != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            conversation.preview!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              height: 1.3,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(value, conversation),
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'bookmark',
                        child: Row(
                          children: [
                            Icon(
                              conversation.isBookmarked 
                                  ? Icons.bookmark_remove_rounded 
                                  : Icons.bookmark_add_rounded,
                              size: 18,
                              color: const Color(0xFF2196F3),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              conversation.isBookmarked 
                                  ? 'Remove Bookmark' 
                                  : 'Add Bookmark',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.red[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildStatChip(
                    icon: Icons.message_rounded,
                    text: '${conversation.messageCount} messages',
                    color: const Color(0xFF666666),
                  ),
                  const SizedBox(width: 16),
                  _buildStatChip(
                    icon: Icons.access_time_rounded,
                    text: _formatDate(conversation.lastMessageAt),
                    color: isRecent ? const Color(0xFF2196F3) : const Color(0xFF666666),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ],
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
          
          _showSuccessSnackBar(newStatus ? 'Bookmarked!' : 'Bookmark removed');
        } catch (e) {
          _showErrorSnackBar('Error updating bookmark: $e');
        }
        break;
      case 'delete':
        _showDeleteDialog(conversation);
        break;
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showDeleteDialog(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Conversation',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this conversation?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${conversation.title}"',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _conversationService.deleteConversation(conversation.id);
                _loadConversations();
                _showSuccessSnackBar('Conversation deleted');
              } catch (e) {
                _showErrorSnackBar('Error deleting conversation: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _openConversation(Conversation conversation) async {
    try {
      final character = await _getCharacterInfo(conversation.characterId);
      if (character != null && mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              character: character,
              existingConversationId: conversation.id,
            ),
          ),
        );
        
        if (result == null) {
          _loadConversations();
        }
      } else {
        _showErrorSnackBar('Character not found');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening conversation: $e');
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
