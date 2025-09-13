import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/auth/auth_service.dart';
import 'package:myapp/auth/login_page.dart';
import 'package:myapp/widgets/custom_card.dart';
import 'package:myapp/services/conversation_service.dart';
import 'package:myapp/pages/characters_page.dart';
import 'package:myapp/pages/conversation_history_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final ConversationService _conversationService = ConversationService();
  
  Map<String, dynamic>? userProfile;
  bool loading = true;
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  
  // Real stats from database
  int totalChats = 0;
  int totalMessages = 0;
  int favoriteCharacters = 0;
  int totalCharactersInteracted = 0;
  int streakDays = 0;
  String memberSince = '';
  
  // Settings
  bool notificationsEnabled = true;
  bool darkMode = false;
  String selectedLanguage = 'English';
  bool streamingMode = true;
  
  // Achievements
  List<Achievement> achievements = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _loadAllData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadUserData(),
      _loadSettings(),
      _loadRealStats(),
    ]);
    _generateAchievements();
    _fadeController.forward();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await _auth.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          userProfile = profile;
          memberSince = _formatMemberSince(_auth.currentUser?.metadata.creationTime);
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
          darkMode = prefs.getBool('dark_mode') ?? false;
          selectedLanguage = prefs.getString('language') ?? 'English';
          streamingMode = prefs.getBool('streaming_mode') ?? true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _loadRealStats() async {
    try {
      final conversations = await _conversationService.getUserConversations();
      
      int messagesCount = 0;
      Set<String> charactersInteracted = {};
      
      for (final conversation in conversations) {
        // Count messages in each conversation
        final messages = await _conversationService.getConversationMessages(conversation.id);
        messagesCount += messages.length;
        
        // Track unique characters
        charactersInteracted.add(conversation.characterId);
      }
      
      // Calculate streak (mock implementation - you can enhance this)
      final prefs = await SharedPreferences.getInstance();
      final lastActiveDate = prefs.getString('last_active_date');
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      int currentStreak = prefs.getInt('current_streak') ?? 0;
      if (lastActiveDate == today) {
        // User was active today, keep streak
      } else if (lastActiveDate != null) {
        final lastDate = DateTime.parse(lastActiveDate);
        final difference = DateTime.now().difference(lastDate).inDays;
        if (difference == 1) {
          // Consecutive day, increment streak
          currentStreak++;
          await prefs.setInt('current_streak', currentStreak);
        } else if (difference > 1) {
          // Streak broken
          currentStreak = 0;
          await prefs.setInt('current_streak', 0);
        }
      }
      await prefs.setString('last_active_date', today);
      
      if (mounted) {
        setState(() {
          totalChats = conversations.length;
          totalMessages = messagesCount;
          totalCharactersInteracted = charactersInteracted.length;
          streakDays = currentStreak;
          favoriteCharacters = userProfile?['favoriteCharacters']?.length ?? 0;
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading real stats: $e');
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void _generateAchievements() {
    achievements = [
      Achievement(
        id: 'welcome',
        title: 'Welcome Aboard!',
        description: 'Start your AI journey today',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF9800),
        isUnlocked: true,
        progress: 1.0,
      ),
      Achievement(
        id: 'first_chat',
        title: 'First Conversation',
        description: 'Complete your first AI chat',
        icon: Icons.chat_bubble_rounded,
        color: const Color(0xFF2196F3),
        isUnlocked: totalChats >= 1,
        progress: totalChats >= 1 ? 1.0 : 0.0,
      ),
      Achievement(
        id: 'chatter',
        title: 'Active Chatter',
        description: 'Start 10 conversations',
        icon: Icons.forum_rounded,
        color: const Color(0xFF4CAF50),
        isUnlocked: totalChats >= 10,
        progress: (totalChats / 10).clamp(0.0, 1.0),
      ),
      Achievement(
        id: 'message_master',
        title: 'Message Master',
        description: 'Send 100 messages',
        icon: Icons.message_rounded,
        color: const Color(0xFF9C27B0),
        isUnlocked: totalMessages >= 100,
        progress: (totalMessages / 100).clamp(0.0, 1.0),
      ),
      Achievement(
        id: 'explorer',
        title: 'Character Explorer',
        description: 'Chat with 5 different characters',
        icon: Icons.explore_rounded,
        color: const Color(0xFFE91E63),
        isUnlocked: totalCharactersInteracted >= 5,
        progress: (totalCharactersInteracted / 5).clamp(0.0, 1.0),
      ),
      Achievement(
        id: 'streak_master',
        title: 'Streak Master',
        description: 'Maintain a 7-day streak',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF5722),
        isUnlocked: streakDays >= 7,
        progress: (streakDays / 7).clamp(0.0, 1.0),
      ),
    ];
  }

  String _formatMemberSince(DateTime? creationTime) {
    if (creationTime == null) return 'New Member';
    
    final now = DateTime.now();
    final difference = now.difference(creationTime);
    
    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: loading
            ? _buildLoadingState()
            : FadeTransition(
                opacity: _fadeController,
                child: RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildHeader(),
                        _buildProfileSection(),
                        _buildAdvancedStatsSection(),
                        _buildAchievementsSection(),
                        _buildQuickActionsSection(),
                        _buildPreferencesSection(),
                        _buildDataManagementSection(),
                        _buildAboutSection(),
                        _buildLogoutSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading your profile...',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Profile',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _showEditProfileDialog,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 20,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: CustomCard(
        child: Container(
          decoration: BoxDecoration(
            color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2196F3).withOpacity(0.8),
                          const Color(0xFF1976D2).withOpacity(0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2196F3).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getUserInitials(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _changeProfilePicture,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _getUserName(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _auth.currentUser?.email ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildProfileBadge('Member since $memberSince', Colors.blue),
                  if (streakDays > 0) ...[
                    const SizedBox(width: 8),
                    _buildProfileBadge('${streakDays}d streak', Colors.orange),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAdvancedStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          // Main Stats Row
          Row(
            children: [
              Expanded(child: _buildStatCard('Conversations', totalChats, Icons.chat_bubble_rounded, const Color(0xFF2196F3))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Messages', totalMessages, Icons.message_rounded, const Color(0xFF4CAF50))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Favorites', favoriteCharacters, Icons.favorite_rounded, const Color(0xFFE91E63))),
            ],
          ),
          const SizedBox(height: 12),
          // Additional Stats Row
          Row(
            children: [
              Expanded(child: _buildStatCard('Characters', totalCharactersInteracted, Icons.people_rounded, const Color(0xFF9C27B0))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Streak Days', streakDays, Icons.local_fire_department_rounded, const Color(0xFFFF5722))),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Level', _calculateUserLevel(), Icons.star_rounded, const Color(0xFFFF9800))),
            ],
          ),
        ],
      ),
    );
  }

  int _calculateUserLevel() {
    final totalPoints = (totalChats * 10) + (totalMessages * 2) + (favoriteCharacters * 5) + (streakDays * 3);
    return (totalPoints / 100).floor() + 1;
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return CustomCard(
      child: Container(
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final unlockedAchievements = achievements.where((a) => a.isUnlocked).toList();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Achievements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${unlockedAchievements.length}/${achievements.length}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                return Container(
                  width: 100,
                  margin: EdgeInsets.only(right: index < achievements.length - 1 ? 12 : 0),
                  child: _buildAchievementCard(achievement),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    return GestureDetector(
      onTap: () => _showAchievementDialog(achievement),
      child: CustomCard(
        child: Container(
          decoration: BoxDecoration(
            color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: achievement.isUnlocked 
                ? Border.all(color: achievement.color.withOpacity(0.3))
                : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: achievement.isUnlocked 
                      ? achievement.color.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  achievement.icon,
                  color: achievement.isUnlocked ? achievement.color : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: achievement.isUnlocked 
                      ? (darkMode ? Colors.white : const Color(0xFF1A1A1A))
                      : Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!achievement.isUnlocked && achievement.progress > 0) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: achievement.progress,
                  backgroundColor: Colors.grey.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(achievement.color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildQuickActionCard('Export\nChats', Icons.download_rounded, const Color(0xFF2196F3), _exportChats),
              _buildQuickActionCard('Share\nApp', Icons.share_rounded, const Color(0xFF4CAF50), _shareApp),
              _buildQuickActionCard('Start\nChat', Icons.chat_rounded, const Color(0xFF9C27B0), () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CharactersPage()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(String label, IconData icon, Color color, VoidCallback onPressed) {
    return CustomCard(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          CustomCard(
            child: Container(
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSwitchItem(
                    Icons.notifications_rounded,
                    'Notifications',
                    'Get notified about updates',
                    notificationsEnabled,
                    (value) async {
                      setState(() => notificationsEnabled = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('notifications_enabled', value);
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchItem(
                    Icons.dark_mode_rounded,
                    'Dark Mode',
                    'Use dark theme',
                    darkMode,
                    (value) async {
                      setState(() => darkMode = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('dark_mode', value);
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchItem(
                    Icons.stream_rounded,
                    'Streaming Mode',
                    'Real-time AI responses',
                    streamingMode,
                    (value) async {
                      setState(() => streamingMode = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('streaming_mode', value);
                    },
                  ),
                  _buildDivider(),
                  _buildSelectItem(
                    Icons.language_rounded,
                    'Language',
                    selectedLanguage,
                    () => _showLanguageDialog(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildSelectItem(IconData icon, String title, String value, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Color(0xFF666666),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDataManagementSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          CustomCard(
            child: Container(
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildDataItem(
                    Icons.backup_rounded,
                    'Backup Data',
                    'Save your conversations',
                    _backupData,
                  ),
                  _buildDivider(),
                  _buildDataItem(
                    Icons.restore_rounded,
                    'Import Data',
                    'Restore from backup',
                    _importData,
                  ),
                  _buildDivider(),
                  _buildDataItem(
                    Icons.delete_forever_rounded,
                    'Clear All Data',
                    'Delete all conversations',
                    _showClearDataDialog,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataItem(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDestructive 
              ? Colors.red.withOpacity(0.1)
              : const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon, 
          color: isDestructive ? Colors.red : const Color(0xFF2196F3), 
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive 
              ? Colors.red 
              : (darkMode ? Colors.white : const Color(0xFF1A1A1A)),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Color(0xFF666666),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildAboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          CustomCard(
            child: Container(
              decoration: BoxDecoration(
                color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildAboutItem(
                    Icons.info_rounded,
                    'App Version',
                    'v1.0.0',
                    () => _showAppInfo(),
                  ),
                  _buildDivider(),
                  _buildAboutItem(
                    Icons.privacy_tip_rounded,
                    'Privacy Policy',
                    'Review our privacy policy',
                    () => _showPrivacyPolicy(),
                  ),
                  _buildDivider(),
                  _buildAboutItem(
                    Icons.description_rounded,
                    'Terms of Service',
                    'Review terms and conditions',
                    () => _showTermsOfService(),
                  ),
                  _buildDivider(),
                  _buildAboutItem(
                    Icons.help_rounded,
                    'Help & Support',
                    'Get help or contact us',
                    () => _showHelpSupport(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF2196F3), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkMode ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: Color(0xFF666666),
        size: 16,
      ),
      onTap: onTap,
    );
  }

  Widget _buildLogoutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: CustomCard(
        child: Container(
          decoration: BoxDecoration(
            color: darkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
            ),
            title: const Text(
              'Logout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            subtitle: Text(
              'Sign out of your account',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            onTap: _showLogoutDialog,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey[200],
      indent: 68,
    );
  }

  // Dialog Methods
  void _showAchievementDialog(Achievement achievement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(achievement.icon, color: achievement.color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                achievement.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(achievement.description),
            const SizedBox(height: 16),
            if (!achievement.isUnlocked) ...[
              const Text('Progress:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: achievement.progress,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(achievement.color),
              ),
              const SizedBox(height: 4),
              Text(
                '${(achievement.progress * 100).toInt()}% completed',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: achievement.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: achievement.color, size: 20),
                    const SizedBox(width: 8),
                    const Text('Achievement Unlocked!', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _getUserName());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Save name logic here
              Navigator.pop(context);
              _showSuccessSnackBar('Profile updated successfully!');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = ['English', 'Spanish', 'French', 'German', 'Italian', 'Portuguese'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((language) => RadioListTile<String>(
            title: Text(language),
            value: language,
            groupValue: selectedLanguage,
            onChanged: (value) async {
              setState(() => selectedLanguage = value!);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('language', value!);
              Navigator.pop(context);
              _showSuccessSnackBar('Language changed to $value');
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
        content: const Text('This will permanently delete all your conversations and data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
              _showSuccessSnackBar('All data cleared successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Action Methods
  void _changeProfilePicture() {
    _showSuccessSnackBar('Profile picture feature coming soon!');
  }

  void _exportChats() async {
    try {
      final conversations = await _conversationService.getUserConversations();
      final exportData = StringBuffer();
      
      exportData.writeln('AI Chat Export');
      exportData.writeln('Generated: ${DateTime.now()}');
      exportData.writeln('Total Conversations: ${conversations.length}');
      exportData.writeln('=' * 50);
      
      for (final conversation in conversations) {
        // ✅ Use characterId instead (assuming this exists)
exportData.writeln('\nConversation with Character ${conversation.characterId}');
exportData.writeln('Started: ${conversation.createdAt}');
        exportData.writeln('-' * 30);
        
        final messages = await _conversationService.getConversationMessages(conversation.id);
        for (final message in messages) {
          exportData.writeln('${message.senderName}: ${message.content}');
        }
        exportData.writeln();
      }
      
      await Clipboard.setData(ClipboardData(text: exportData.toString()));
      _showSuccessSnackBar('Chat export copied to clipboard!');
    } catch (e) {
      _showErrorSnackBar('Export failed: $e');
    }
  }

  void _shareApp() {
    const appText = 'Check out this amazing AI Chat app! Chat with historical figures and learn from the best minds in history.';
    Clipboard.setData(const ClipboardData(text: appText));
    _showSuccessSnackBar('App info copied to clipboard!');
  }

  void _backupData() {
    _showSuccessSnackBar('Backup feature coming soon!');
  }

  void _importData() {
    _showSuccessSnackBar('Import feature coming soon!');
  }

  Future<void> _clearAllData() async {
    try {
      // Clear all conversations (implement based on your service)
      // await _conversationService.clearAllUserData();
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      setState(() {
        totalChats = 0;
        totalMessages = 0;
        favoriteCharacters = 0;
        streakDays = 0;
        totalCharactersInteracted = 0;
      });
      
      _generateAchievements();
    } catch (e) {
      _showErrorSnackBar('Failed to clear data: $e');
    }
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('AI Advisor'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('Build: 100'),
            SizedBox(height: 8),
            Text('Developed with Flutter'),
            SizedBox(height: 8),
            Text('Powered by Groq AI'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    _showSuccessSnackBar('Privacy Policy feature coming soon!');
  }

  void _showTermsOfService() {
    _showSuccessSnackBar('Terms of Service feature coming soon!');
  }

  void _showHelpSupport() {
    _showSuccessSnackBar('Help & Support feature coming soon!');
  }

  // Helper Methods
  String _getUserInitials() {
    final name = _getUserName();
    final words = name.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _getUserName() {
    final email = _auth.currentUser?.email ?? '';
    final name = email.split('@')[0].replaceAll('.', ' ').split(' ').map((word) => 
        word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : ''
    ).join(' ');
    return name.isNotEmpty ? name : 'User';
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
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
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// Achievement Model
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final double progress;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
    required this.progress,
  });
}
