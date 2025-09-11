// lib/pages/chat_page.dart - COMPLETE PRODUCTION VERSION WITH IMAGE SUPPORT
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/character.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/image_service.dart';
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

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ImageService _imageService = ImageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isSending = false;
  int _chatCredits = 999999;
  bool _useStreaming = true;
  bool _isExistingConversation = false;

  @override
  void initState() {
    super.initState();
    _isExistingConversation = widget.existingConversationId != null;
    _initializeChat();
    _loadUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
        _chatCredits = 999999;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_useStreaming ? 'Streaming mode ON' : 'Streaming mode OFF'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _exportConversation() {
    final exportText = _chatService.exportConversationAsText();
    Clipboard.setData(ClipboardData(text: exportText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conversation copied to clipboard!'),
        backgroundColor: Colors.teal,
      ),
    );
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
        title: const Text('Clear Conversation'),
        content: const Text('Are you sure you want to clear this conversation? This will start a new chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _chatService.clearConversation();
              _initializeChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Conversation cleared'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadConversation() async {
    if (_chatService.isConversationPersisted) {
      await _chatService.reloadConversation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conversation reloaded'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  // 📸 IMAGE FUNCTIONALITY
  Future<void> _handleImageSelection() async {
    if (_isSending) return;
    
    try {
      final imageFile = await _imageService.showImageSourceDialog(context);
      
      if (imageFile != null) {
        // Validate image
        if (!_imageService.isValidImage(imageFile)) {
          _showError('Please select a valid image file (JPG, PNG, GIF, etc.)');
          return;
        }
        
        // Check file size (limit to 10MB)
        final sizeInMB = await _imageService.getFileSizeInMB(imageFile);
        if (sizeInMB > 10) {
          _showError('Image too large. Please select an image under 10MB.');
          return;
        }
        
        await _sendImageMessage(imageFile);
      }
    } catch (e) {
      _showError('Error selecting image: $e');
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    if (_isSending) return;

    setState(() => _isSending = true);
    
    try {
      final message = _messageController.text.trim();
      _messageController.clear();
      
      final response = await _chatService.sendImageMessage(
        message,
        imageFile,
        widget.character,
        useStreaming: _useStreaming,
      );
      
      if (response != null) {
        _scrollToBottom();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Image shared with ${widget.character.name}'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _showError('Failed to send image. Please try again.');
      }
    } catch (e) {
      _showError('Error sending image: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.character.imageUrl?.isNotEmpty == true
                  ? NetworkImage(widget.character.imageUrl!)
                  : null,
              backgroundColor: Colors.teal.shade100,
              child: widget.character.imageUrl?.isEmpty ?? true
                  ? Text(
                      widget.character.name[0],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.character.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        widget.character.category,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_useStreaming)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'STREAMING',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (_isExistingConversation) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'RESUMED',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
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
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'streaming',
                child: Row(
                  children: [
                    Icon(_useStreaming ? Icons.stream : Icons.message, size: 18),
                    const SizedBox(width: 8),
                    Text(_useStreaming ? 'Disable Streaming' : 'Enable Streaming'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text('Export Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history, size: 18),
                    SizedBox(width: 8),
                    Text('Chat History'),
                  ],
                ),
              ),
              if (_chatService.isConversationPersisted)
                const PopupMenuItem(
                  value: 'reload',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 18),
                      SizedBox(width: 8),
                      Text('Reload'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 18),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_chatCredits credits',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Conversation info bar
          if (_chatService.isConversationPersisted)
            Container(
              width: double.infinity,
              color: Colors.teal.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.save, size: 16, color: Colors.teal.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conversation saved • ${_chatService.messageCount} messages',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade600,
                      ),
                    ),
                  ),
                  Text(
                    _isExistingConversation ? 'Resumed' : 'Auto-saved',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildMessageInput(),
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
          return const Center(
            child: CircularProgressIndicator(color: Colors.teal),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
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

  Widget _buildMessageBubble(Message message, {bool isStreaming = false}) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      onTap: message.hasImage && message.imageUrl != null 
          ? () => _showImagePreview(message.imageUrl!, message.content)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: message.isFromUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isFromUser) ...[
              CircleAvatar(
                radius: 16,
                backgroundImage: widget.character.imageUrl?.isNotEmpty == true
                    ? NetworkImage(widget.character.imageUrl!)
                    : null,
                backgroundColor: Colors.teal.shade100,
                child: widget.character.imageUrl?.isEmpty ?? true
                    ? Text(
                        widget.character.name[0],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: message.isFromUser
                      ? Colors.teal
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: message.isFromUser
                        ? const Radius.circular(12)
                        : const Radius.circular(4),
                    bottomRight: message.isFromUser
                        ? const Radius.circular(4)
                        : const Radius.circular(12),
                  ),
                  border: isStreaming 
                      ? Border.all(color: Colors.teal.withOpacity(0.3), width: 1)
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
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade700,
                            ),
                          ),
                          if (isStreaming) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.teal.shade400),
                              ),
                            ),
                          ],
                        ],
                      ),
                    if (!message.isFromUser) const SizedBox(height: 4),
                    
                    // 📸 IMAGE DISPLAY
                    if (message.hasImage && message.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 250,
                            maxHeight: 200,
                          ),
                          child: Stack(
                            children: [
                              Image.network(
                                message.imageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / 
                                                  loadingProgress.expectedTotalBytes!
                                                : null,
                                            color: Colors.teal,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Loading image...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error, color: Colors.red, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(color: Colors.red, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Image overlay for tap indication
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.black.withOpacity(0.1),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.zoom_in,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (message.content.isNotEmpty) const SizedBox(height: 8),
                    ],
                    
                    // TEXT CONTENT
                    if (message.content.isNotEmpty || (!message.hasImage && isStreaming))
                      Text(
                        message.content.isEmpty && isStreaming 
                            ? (message.hasImage ? "Analyzing image..." : "Thinking...") 
                            : message.content,
                        style: TextStyle(
                          fontSize: 14,
                          color: message.isFromUser
                              ? Colors.white
                              : message.content.isEmpty && isStreaming
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                          height: 1.4,
                          fontStyle: message.content.isEmpty && isStreaming 
                              ? FontStyle.italic 
                              : FontStyle.normal,
                        ),
                      ),
                      
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _formatTime(message.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: message.isFromUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ),
                            if (message.hasImage) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.image,
                                size: 12,
                                color: message.isFromUser
                                    ? Colors.white70
                                    : Colors.grey.shade600,
                              ),
                            ],
                          ],
                        ),
                        if (isStreaming)
                          Text(
                            message.hasImage ? 'Analyzing...' : 'Generating...',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.teal.shade400,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (message.isFromUser) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.teal.shade100,
                child: Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String imageUrl, String caption) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
            if (caption.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    caption,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(Message message) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied!')),
                );
              },
            ),
            if (message.hasImage && message.imageUrl != null)
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('View Full Image'),
                onTap: () {
                  Navigator.pop(context);
                  _showImagePreview(message.imageUrl!, message.content);
                },
              ),
            if (!message.isFromUser)
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Response'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share feature coming soon!')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 📸 IMAGE ATTACHMENT BUTTON
          IconButton(
            onPressed: _isSending ? null : _handleImageSelection,
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              foregroundColor: _isSending ? Colors.grey : Colors.teal,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.image),
            tooltip: 'Share Image',
          ),
          const SizedBox(width: 8),
          // TEXT INPUT
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_isSending,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isSending 
                    ? (_useStreaming ? 'Processing...' : 'Analyzing...')
                    : 'Ask ${widget.character.name} or share an image...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                suffixIcon: _useStreaming 
                    ? Icon(Icons.stream, color: Colors.teal.shade300, size: 16)
                    : null,
              ),
              onChanged: (value) {
                setState(() {}); // Trigger rebuild
              },
              onSubmitted: (text) {
                if (text.trim().isNotEmpty && !_isSending) {
                  _sendMessage(text);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          // SEND BUTTON
          _isSending
              ? Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.teal,
                          strokeWidth: 2,
                        ),
                      ),
                      if (_useStreaming)
                        Icon(
                          Icons.stream,
                          size: 12,
                          color: Colors.teal.shade700,
                        ),
                    ],
                  ),
                )
              : IconButton(
                  onPressed: _messageController.text.trim().isNotEmpty && !_isSending
                      ? () => _sendMessage(_messageController.text)
                      : null,
                  style: IconButton.styleFrom(
                    backgroundColor: _messageController.text.trim().isNotEmpty 
                        ? Colors.teal 
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(_useStreaming ? Icons.stream : Icons.send),
                ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
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
        _showError('Failed to send message. Please try again.');
      }
    } catch (e) {
      _showError('Error sending message: $e');
    } finally {
      setState(() => _isSending = false);
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
