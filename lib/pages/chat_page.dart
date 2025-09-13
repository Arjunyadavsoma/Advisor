import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../auth/auth_service.dart';
import 'conversation_history_page.dart';

class ChatPage extends StatefulWidget {
  final Character character;
  final String? existingConversationId;

  const ChatPage({
    super.key, 
    required this.character,
    this.existingConversationId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  int _chatCredits = 999999;
  bool _useStreaming = true;
  bool _isExistingConversation = false;
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _isExistingConversation = widget.existingConversationId != null;
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _initializeChat();
    _loadUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    await _chatService.startConversation(
      widget.character,
      existingConversationId: widget.existingConversationId,
    );
    _scrollToBottom();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await _authService.getCurrentUserProfile();
      setState(() {
        _chatCredits = profile?['chatCredits'] ?? 999999;
      });
    } catch (e) {
      setState(() {
        _chatCredits = 999999;
      });
    }
  }

  void _toggleStreaming() {
    setState(() {
      _useStreaming = !_useStreaming;
    });
    _showSuccessSnackBar(_useStreaming ? 'Streaming mode ON' : 'Streaming mode OFF');
  }

  void _exportConversation() {
    final exportText = _chatService.exportConversationAsText();
    Clipboard.setData(ClipboardData(text: exportText));
    _showSuccessSnackBar('Conversation copied to clipboard!');
  }

  void _goToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationHistoryPage()),
    );
  }

  void _clearConversation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Conversation',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Are you sure you want to clear this conversation? This will start a new chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _chatService.clearConversation();
              _initializeChat();
              _showSuccessSnackBar('Conversation cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadConversation() async {
    if (_chatService.isConversationPersisted) {
      await _chatService.reloadConversation();
      _showSuccessSnackBar('Conversation reloaded');
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
            if (_chatService.isConversationPersisted) _buildConversationInfo(),
            Expanded(child: _buildMessagesList()),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Character Avatar
          _buildCharacterAvatar(radius: 24),
          const SizedBox(width: 12),
          
          // Character Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.character.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                
                // Status badges
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(widget.character.category).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.character.category,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getCategoryColor(widget.character.category),
                        ),
                      ),
                    ),
                    if (_useStreaming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 4, color: Color(0xFF4CAF50)),
                            SizedBox(width: 2),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 8,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isExistingConversation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'RESUMED',
                          style: TextStyle(
                            fontSize: 8,
                            color: Color(0xFF2196F3),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Credits Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$_chatCredits',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Menu Button
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF666666),
                size: 18,
              ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              _buildMenuItem('streaming', _useStreaming ? Icons.stream_rounded : Icons.message_rounded, _useStreaming ? 'Disable Streaming' : 'Enable Streaming'),
              _buildMenuItem('export', Icons.share_rounded, 'Export Chat'),
              _buildMenuItem('history', Icons.history_rounded, 'Chat History'),
              if (_chatService.isConversationPersisted) _buildMenuItem('reload', Icons.refresh_rounded, 'Reload'),
              _buildMenuItem('clear', Icons.clear_all_rounded, 'Clear Chat'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterAvatar({double radius = 24}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: _getCategoryColor(widget.character.category).withOpacity(0.15),
        borderRadius: BorderRadius.circular(radius * 0.6),
        border: Border.all(
          color: _getCategoryColor(widget.character.category).withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          widget.character.name.isNotEmpty ? widget.character.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: radius * 0.75,
            fontWeight: FontWeight.w700,
            color: _getCategoryColor(widget.character.category),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF666666)),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'streaming':
        _toggleStreaming();
        break;
      case 'export':
        _exportConversation();
        break;
      case 'history':
        _goToHistory();
        break;
      case 'clear':
        _clearConversation();
        break;
      case 'reload':
        _reloadConversation();
        break;
    }
  }

  Widget _buildConversationInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: const Color(0xFF2196F3).withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.save_rounded,
              size: 14,
              color: Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Conversation saved • ${_chatService.messageCount} messages',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _isExistingConversation ? 'Resumed' : 'Auto-saved',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF2196F3),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<Message>>(
      stream: _chatService.messagesStream,
      initialData: _chatService.messages,
      builder: (context, snapshot) {
        final messages = snapshot.data ?? [];
        
        if (messages.isEmpty) {
          return _buildEmptyState();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isLastMessage = index == messages.length - 1;
            final isStreaming = !message.isFromUser && isLastMessage && _isSending;
            
            return _buildMessageBubble(message, isStreaming: isStreaming);
          },
        );
      },
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
                color: _getCategoryColor(widget.character.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.psychology_rounded,
                size: 40,
                color: _getCategoryColor(widget.character.category),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start your conversation with\n${widget.character.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions or just say hello!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, {bool isStreaming = false}) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: message.isFromUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isFromUser) ...[
              _buildCharacterAvatar(radius: 18),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: message.isFromUser
                      ? _getCategoryColor(widget.character.category)
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: message.isFromUser
                        ? const Radius.circular(18)
                        : const Radius.circular(6),
                    bottomRight: message.isFromUser
                        ? const Radius.circular(6)
                        : const Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(message.isFromUser ? 0.08 : 0.04),
                      blurRadius: message.isFromUser ? 8 : 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: isStreaming 
                      ? Border.all(color: _getCategoryColor(widget.character.category).withOpacity(0.3), width: 1)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!message.isFromUser)
                      Row(
                        children: [
                          Text(
                            message.senderName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _getCategoryColor(widget.character.category),
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (isStreaming) ...[
                            const SizedBox(width: 8),
                            AnimatedBuilder(
                              animation: _typingAnimationController,
                              builder: (context, child) {
                                return Row(
                                  children: List.generate(3, (index) {
                                    final delay = index * 0.2;
                                    final opacity = (0.4 + 0.6 * 
                                      ((_typingAnimationController.value - delay).clamp(0.0, 1.0))).clamp(0.4, 1.0);
                                    return Container(
                                      margin: const EdgeInsets.only(right: 2),
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Text(
                                          '●',
                                          style: TextStyle(
                                            color: _getCategoryColor(widget.character.category),
                                            fontSize: 8,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    if (!message.isFromUser) const SizedBox(height: 8),
                    
                    // TEXT CONTENT
                    Text(
                      message.content.isEmpty && isStreaming 
                          ? "Thinking..." 
                          : message.content,
                      style: TextStyle(
                        fontSize: 15,
                        color: message.isFromUser
                            ? Colors.white
                            : message.content.isEmpty && isStreaming
                                ? Colors.grey.shade600
                                : const Color(0xFF1A1A1A),
                        height: 1.5,
                        letterSpacing: -0.1,
                        fontStyle: message.content.isEmpty && isStreaming 
                            ? FontStyle.italic 
                            : FontStyle.normal,
                      ),
                    ),
                      
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTime(message.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: message.isFromUser
                                ? Colors.white.withOpacity(0.8)
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isStreaming)
                          Text(
                            'Generating...',
                            style: TextStyle(
                              fontSize: 11,
                              color: message.isFromUser 
                                  ? Colors.white.withOpacity(0.8)
                                  : _getCategoryColor(widget.character.category),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (message.isFromUser) ...[
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            _buildOptionTile(
              icon: Icons.copy_rounded,
              title: 'Copy Message',
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                _showSuccessSnackBar('Message copied!');
              },
            ),
            if (!message.isFromUser)
              _buildOptionTile(
                icon: Icons.share_rounded,
                title: 'Share Response',
                onTap: () {
                  Navigator.pop(context);
                  _showSuccessSnackBar('Share feature coming soon!');
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _getCategoryColor(widget.character.category).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: _getCategoryColor(widget.character.category), size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  enabled: !_isSending,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: _isSending 
                        ? (_useStreaming ? 'Processing...' : 'Analyzing...')
                        : 'Message ${widget.character.name}...',
                    hintStyle: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    suffixIcon: _useStreaming 
                        ? Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Icon(
                              Icons.stream_rounded,
                              color: _getCategoryColor(widget.character.category).withOpacity(0.5),
                              size: 18,
                            ),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty && !_isSending) {
                      _sendMessage(text);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSending
                    ? _getCategoryColor(widget.character.category).withOpacity(0.1)
                    : _messageController.text.trim().isNotEmpty 
                        ? _getCategoryColor(widget.character.category)
                        : Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: _isSending
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _getCategoryColor(widget.character.category),
                            strokeWidth: 2,
                          ),
                        ),
                        if (_useStreaming)
                          Icon(
                            Icons.stream_rounded,
                            size: 12,
                            color: _getCategoryColor(widget.character.category),
                          ),
                      ],
                    )
                  : IconButton(
                      onPressed: _messageController.text.trim().isNotEmpty && !_isSending
                          ? () => _sendMessage(_messageController.text)
                          : null,
                      icon: Icon(
                        _useStreaming ? Icons.stream_rounded : Icons.send_rounded,
                        color: _messageController.text.trim().isNotEmpty 
                            ? Colors.white 
                            : Colors.grey[400],
                        size: 20,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _typingAnimationController.repeat();
    _messageController.clear();
    
    try {
      Message? response;
      
      if (_useStreaming) {
        response = await _chatService.sendMessageStreaming(content, widget.character);
      } else {
        response = await _chatService.sendMessage(content, widget.character);
      }
      
      if (response != null) {
        _scrollToBottom();
      } else {
        _showErrorSnackBar('Failed to send message. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('Error sending message: $e');
    } finally {
      setState(() => _isSending = false);
      _typingAnimationController.stop();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'philosophy':
        return const Color(0xFF2196F3);
      case 'science':
        return const Color(0xFF4CAF50);
      case 'history':
        return const Color(0xFFFF9800);
      case 'literature':
        return const Color(0xFF9C27B0);
      case 'strategy':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF607D8B);
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _getCategoryColor(widget.character.category),
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
}
