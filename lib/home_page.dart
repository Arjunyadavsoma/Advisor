import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:myapp/pages/characters_page.dart';
import 'package:myapp/pages/conversation_history_page.dart';
import 'package:myapp/pages/profile_page.dart';
import 'package:myapp/pages/chat_page.dart';
import 'package:myapp/widgets/custom_card.dart';
import 'package:myapp/widgets/activity_icon.dart';
import 'package:myapp/services/conversation_service.dart';
import 'package:myapp/services/groq_service.dart';
import 'package:myapp/services/chat_service.dart';
import 'package:myapp/models/character.dart';
import 'auth/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _auth = AuthService();
  final ConversationService _conversationService = ConversationService();
  final GroqService _groqService = GroqService();
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  
  // User data
  Map<String, dynamic>? userProfile;
  bool loading = true;
  int selectedIndex = 0;
  
  // Quote data
  String dailyQuote = '';
  String quoteAuthor = '';
  bool quoteLoading = true;
  
  // Chat data
  bool isSending = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadUserData(),
      _loadDailyQuote(),
    ]);
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await _auth.getCurrentUserProfile();
      
      if (mounted) {
        setState(() {
          userProfile = profile;
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _loadDailyQuote() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.quotable.io/random?maxLength=120'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            dailyQuote = data['content'] ?? 'Stay curious and keep learning.';
            quoteAuthor = data['author'] ?? 'Unknown';
            quoteLoading = false;
          });
        }
      } else {
        _setFallbackQuote();
      }
    } catch (e) {
      print('Error loading quote: $e');
      _setFallbackQuote();
    }
  }

  void _setFallbackQuote() {
    if (mounted) {
      setState(() {
        dailyQuote = 'The only way to do great work is to love what you do.';
        quoteAuthor = 'Steve Jobs';
        quoteLoading = false;
      });
    }
  }

  Future<void> _refreshQuote() async {
    setState(() => quoteLoading = true);
    await _loadDailyQuote();
  }

  void _shareQuote() {
    final quoteText = '"$dailyQuote" - $quoteAuthor';
    Clipboard.setData(ClipboardData(text: quoteText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote copied to clipboard!'),
        backgroundColor: Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _sendQuickMessage() async {
    if (_messageController.text.trim().isEmpty || isSending) return;

    setState(() => isSending = true);
    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      // Create a generic AI assistant character
      final quickChatCharacter = Character(
        id: 'ai_assistant',
        name: 'AI Assistant',
        description: 'A helpful AI assistant for quick questions',
        category: 'General',
        imageUrl: null,
        promptStyle: 'You are a helpful AI assistant. Provide concise, accurate, and friendly responses.',
      );

      // Start a new conversation and navigate to chat page
      await _navigateToQuickChat(quickChatCharacter, message);

    } catch (e) {
      if (mounted) {
        setState(() => isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _navigateToQuickChat(Character character, String initialMessage) async {
    try {
      // Navigate to chat page with the AI assistant character
      if (mounted) {
        setState(() => isSending = false);
        
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              character: character,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to chat: $e');
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: loading 
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF2196F3),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 24),
                          _buildQuickChatSection(),
                          const SizedBox(height: 24),
                          _buildQuoteCard(),
                          const SizedBox(height: 24),
                          _buildQuickActions(),
                          const SizedBox(height: 24),
                          _buildCategoriesSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    final user = _auth.currentUser;
    final displayName = user?.displayName ?? 'Explorer';
    final greeting = _getGreeting();
    
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting!',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            icon: const Icon(
              Icons.person_rounded,
              color: Color(0xFF2196F3),
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickChatSection() {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFF2196F3),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Quick Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const Spacer(),
                if (isSending)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Color(0xFF2196F3),
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Message input
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !isSending,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: isSending 
                            ? 'Starting chat...' 
                            : 'Ask AI anything and start chatting...',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                      onSubmitted: (_) => _sendQuickMessage(),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(4),
                    child: GestureDetector(
                      onTap: isSending ? null : _sendQuickMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSending 
                              ? Colors.grey[300]
                              : (_messageController.text.trim().isNotEmpty 
                                  ? const Color(0xFF2196F3)
                                  : Colors.grey[300]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: isSending || _messageController.text.trim().isEmpty
                              ? Colors.grey[500]
                              : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            Text(
              'Start a conversation with AI Assistant',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard() {
    return CustomCard(
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2196F3).withOpacity(0.8),
              const Color(0xFF1976D2).withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: quoteLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.format_quote,
                        color: Colors.white,
                        size: 32,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _refreshQuote,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'New Quote',
                      ),
                      IconButton(
                        onPressed: _shareQuote,
                        icon: const Icon(
                          Icons.share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Share Quote',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: Text(
                      dailyQuote,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          quoteAuthor,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return CustomCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Start Chat',
                    Icons.chat_rounded,
                    const Color(0xFF2196F3),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CharactersPage()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    'History',
                    Icons.history_rounded,
                    const Color(0xFF4CAF50),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ConversationHistoryPage()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Explore Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100, // Fixed height to prevent overflow
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.0,
            children: [
              ActivityIcon(
                icon: Icons.school_rounded,
                label: 'Philosophy',
                color: const Color(0xFF2196F3),
                onTap: () => _navigateToCategory('Philosophy'),
              ),
              ActivityIcon(
                icon: Icons.science_rounded,
                label: 'Science',
                color: const Color(0xFF4CAF50),
                onTap: () => _navigateToCategory('Science'),
              ),
              ActivityIcon(
                icon: Icons.history_edu_rounded,
                label: 'History',
                color: const Color(0xFFFF9800),
                onTap: () => _navigateToCategory('History'),
              ),
              ActivityIcon(
                icon: Icons.menu_book_rounded,
                label: 'Literature',
                color: const Color(0xFF9C27B0),
                onTap: () => _navigateToCategory('Literature'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CharactersPage(category: category),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              if (index == 0) return; // Already on home
              
              switch (index) {
                case 1:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CharactersPage()),
                  );
                  break;
                case 2:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConversationHistoryPage()),
                  );
                  break;
                case 3:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfilePage()),
                  );
                  break;
              }
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF2196F3),
            unselectedItemColor: Colors.grey[400],
            elevation: 0,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.home_rounded, size: 24),
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.people_rounded, size: 24),
                ),
                label: 'Characters',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.history_rounded, size: 24),
                ),
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.person_rounded, size: 24),
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
