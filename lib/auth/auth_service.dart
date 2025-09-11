// auth_service.dart - COMPLETE CORRECTED VERSION
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // User stream
  Stream<User?> get userChanges => _auth.userChanges();

  // CORRECTED: Stream user profile changes (Fixed switchMap issue)
  Stream<Map<String, dynamic>?> get userProfileStream {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        return doc.exists ? doc.data() as Map<String, dynamic>? : null;
      } catch (e) {
        print("Error fetching user profile: $e");
        return null;
      }
    });
  }

  // CORRECTED: Check real-time credit balance
  Stream<int> get chatCreditsStream {
    return userProfileStream.map((profile) => 
      profile?['chatCredits'] ?? 0
    );
  }

  // ALTERNATIVE: More efficient real-time stream for user profile
  Stream<Map<String, dynamic>?> getUserProfileStreamRealtime() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  // ALTERNATIVE: Real-time credits with direct Firestore stream
  Stream<int> getChatCreditsStreamRealtime() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0;
          final data = doc.data();
          return data?['chatCredits'] ?? 0;
        });
  }

  // Additional useful streams for AI advisor app
  Stream<String> get userTypeStream {
    return userProfileStream.map((profile) => 
      profile?['userType'] ?? 'free'
    );
  }

  Stream<List<String>> get favoriteCharactersStream {
    return userProfileStream.map((profile) => 
      List<String>.from(profile?['favoriteCharacters'] ?? [])
    );
  }

  Stream<bool> get canChatStream {
    return userProfileStream.map((profile) {
      if (profile == null) return false;
      int credits = profile['chatCredits'] ?? 0;
      String userType = profile['userType'] ?? 'free';
      return userType == 'premium' || credits > 0;
    });
  }

  // -------------------------
  // Email/Password Sign-Up
  // -------------------------
  Future<UserCredential?> signUpWithEmail(
      String email, String password, String displayName, {String userType = 'free'}) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty || displayName.isEmpty) {
        throw Exception('All fields are required');
      }

      if (!_isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }

      if (password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      if (displayName.length < 2) {
        throw Exception('Name must be at least 2 characters');
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name and reload user
      await userCredential.user?.updateDisplayName(displayName);
      await userCredential.user?.reload();

      // Get updated user
      User? updatedUser = _auth.currentUser;
      if (updatedUser != null) {
        await saveUserProfile(updatedUser, userType: userType);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return null;
    } catch (e) {
      print("Sign-Up Error: $e");
      return null;
    }
  }

  // -------------------------
  // Email/Password Login
  // -------------------------
  Future<UserCredential?> loginWithEmail(String email, String password) async {
    try {
      // Validate inputs
      if (email.isEmpty || password.isEmpty) {
        throw Exception('Email and password are required');
      }

      if (!_isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );

      // Save/update profile in Firestore
      if (userCredential.user != null) {
        await saveUserProfile(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return null;
    } catch (e) {
      print("Login Error: $e");
      return null;
    }
  }

  // -------------------------
  // Google Sign-In
  // -------------------------
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Clear any previous sessions
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign-In cancelled by user');
        return null; // User cancelled
      }

      // Obtain auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Validate tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      // Sign in to Firebase
      final userCredential = await _auth.signInWithCredential(credential);

      // Save profile to Firestore
      if (userCredential.user != null) {
        await saveUserProfile(userCredential.user!);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return null;
    } catch (e) {
      print("Google Sign-In Error: $e");
      return null;
    }
  }

  // -------------------------
  // Anonymous Sign-In
  // -------------------------
  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      
      if (userCredential.user != null) {
        await saveUserProfile(userCredential.user!);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print("Anonymous Sign-In Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return null;
    } catch (e) {
      print("Anonymous Sign-In Error: $e");
      return null;
    }
  }

  // -------------------------
  // Forgot Password
  // -------------------------
  Future<bool> sendPasswordReset(String email) async {
    try {
      if (email.isEmpty) {
        throw Exception('Email is required');
      }

      if (!_isValidEmail(email)) {
        throw Exception('Please enter a valid email address');
      }

      await _auth.sendPasswordResetEmail(email: email);
      print("Password reset email sent to $email");
      return true;
    } on FirebaseAuthException catch (e) {
      print("Password Reset Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return false;
    } catch (e) {
      print("Password Reset Error: $e");
      return false;
    }
  }

  // -------------------------
  // Email Verification
  // -------------------------
  Future<bool> sendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        print("Verification email sent");
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      print("Email Verification Error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      print("Email Verification Error: $e");
      return false;
    }
  }

  // -------------------------
  // Update Profile
  // -------------------------
  Future<bool> updateProfile({String? displayName, String? photoURL}) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      if (displayName != null) {
        await user.updateDisplayName(displayName);
      }
      
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }

      await user.reload();
      User? updatedUser = _auth.currentUser;
      
      if (updatedUser != null) {
        await saveUserProfile(updatedUser);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      print("Update Profile Error: ${e.code} - ${e.message}");
      return false;
    } catch (e) {
      print("Update Profile Error: $e");
      return false;
    }
  }

  // -------------------------
  // Update User Preferences for AI App
  // -------------------------
  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Update Preferences Error: $e");
    }
  }

  // -------------------------
  // Track Conversation Metrics
  // -------------------------
  Future<void> updateChatMetrics(String characterId, int messageCount) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'totalChats': FieldValue.increment(1),
        'totalMessages': FieldValue.increment(messageCount),
        'lastActiveCharacter': characterId,
        'lastChatAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Update Chat Metrics Error: $e");
    }
  }

  // -------------------------
  // Check if user can start new chat
  // -------------------------
  Future<bool> canStartNewChat() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      int chatCredits = userData['chatCredits'] ?? 0;
      String userType = userData['userType'] ?? 'free';

      return userType == 'premium' || chatCredits > 0;
    } catch (e) {
      print("Check Chat Credits Error: $e");
      return false;
    }
  }

  // -------------------------
  // Deduct Chat Credit
  // -------------------------
  Future<void> deductChatCredit() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'chatCredits': FieldValue.increment(-1),
      });
    } catch (e) {
      print("Deduct Credit Error: $e");
    }
  }

  // -------------------------
  // Add Chat Credits (for premium purchases or rewards)
  // -------------------------
  Future<void> addChatCredits(int credits) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'chatCredits': FieldValue.increment(credits),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Add Credits Error: $e");
    }
  }

  // -------------------------
  // Update User Type (free/premium/admin)
  // -------------------------
  Future<void> updateUserType(String userType) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'userType': userType,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Update User Type Error: $e");
    }
  }

  // -------------------------
  // Add/Remove Favorite Character
  // -------------------------
  Future<void> toggleFavoriteCharacter(String characterId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return;

      List<String> favorites = List<String>.from(
        (doc.data() as Map<String, dynamic>)['favoriteCharacters'] ?? []
      );

      if (favorites.contains(characterId)) {
        favorites.remove(characterId);
      } else {
        favorites.add(characterId);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'favoriteCharacters': favorites,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Toggle Favorite Character Error: $e");
    }
  }

  // -------------------------
  // Change Password
  // -------------------------
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    try {
      User? user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      // Re-authenticate user
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      
      print("Password updated successfully");
      return true;
    } on FirebaseAuthException catch (e) {
      print("Change Password Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return false;
    } catch (e) {
      print("Change Password Error: $e");
      return false;
    }
  }

  // -------------------------
  // Delete Account
  // -------------------------
  Future<bool> deleteAccount(String password) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      // Re-authenticate for sensitive operations
      if (user.email != null) {
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
      }

      // Delete user document from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();

      // Delete user account
      await user.delete();
      
      print("Account deleted successfully");
      return true;
    } on FirebaseAuthException catch (e) {
      print("Delete Account Error: ${e.code} - ${e.message}");
      _handleAuthException(e);
      return false;
    } catch (e) {
      print("Delete Account Error: $e");
      return false;
    }
  }

  // -------------------------
  // Save user profile to Firestore (Enhanced for AI App)
  // -------------------------
  Future<void> saveUserProfile(User user, {String userType = 'free'}) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      
      // Check if user already exists to preserve existing data
      DocumentSnapshot existingDoc = await docRef.get();
      Map<String, dynamic> existingData = existingDoc.exists 
          ? existingDoc.data() as Map<String, dynamic> 
          : {};

      final userData = {
        'uid': user.uid,
        'displayName': user.displayName ?? "",
        'email': user.email ?? "",
        'photoURL': user.photoURL ?? "",
        'emailVerified': user.emailVerified,
        'isAnonymous': user.isAnonymous,
        'userType': existingData['userType'] ?? userType, // Preserve existing userType
        'chatCredits': 9999999,
        'favoriteCharacters': existingData['favoriteCharacters'] ?? [],
        'conversationHistory': existingData['conversationHistory'] ?? [],
        'totalChats': existingData['totalChats'] ?? 0,
        'totalMessages': existingData['totalMessages'] ?? 0,
        'lastActiveCharacter': existingData['lastActiveCharacter'] ?? '',
        'preferences': existingData['preferences'] ?? {
          'autoSaveChats': true,
          'notificationsEnabled': true,
          'preferredLanguage': 'en'
        },
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': existingData['createdAt'] ?? user.metadata.creationTime?.millisecondsSinceEpoch,
      };

      await docRef.set(userData, SetOptions(merge: true));
      print("User profile saved to Firestore");
    } catch (e) {
      print("Save Profile Error: $e");
    }
  }

  // -------------------------
  // Get User Profile from Firestore
  // -------------------------
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Get Profile Error: $e");
      return null;
    }
  }

  // -------------------------
  // Get Current User Profile
  // -------------------------
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    return await getUserProfile(user.uid);
  }

  // -------------------------
  // Sign Out
  // -------------------------
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      print("User signed out successfully");
    } catch (e) {
      print("Sign-Out Error: $e");
    }
  }

  // -------------------------
  // Check if user is logged in
  // -------------------------
  bool get isLoggedIn => _auth.currentUser != null;

  // -------------------------
  // Get current user ID
  // -------------------------
  String? get currentUserId => _auth.currentUser?.uid;

  // -------------------------
  // Email Validation Helper
  // -------------------------
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // -------------------------
  // Get User-Friendly Error Message
  // -------------------------
  String getErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // -------------------------
  // Handle Firebase Auth Exceptions
  // -------------------------
  void _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        print('No user found for that email.');
        break;
      case 'wrong-password':
        print('Wrong password provided.');
        break;
      case 'email-already-in-use':
        print('The account already exists for that email.');
        break;
      case 'weak-password':
        print('The password provided is too weak.');
        break;
      case 'invalid-email':
        print('The email address is not valid.');
        break;
      case 'user-disabled':
        print('This user account has been disabled.');
        break;
      case 'too-many-requests':
        print('Too many requests. Try again later.');
        break;
      case 'operation-not-allowed':
        print('This operation is not allowed.');
        break;
      default:
        print('Authentication error: ${e.message}');
    }
  }

  // -------------------------
  // Dispose
  // -------------------------
  void dispose() {
    // Clean up any resources if needed
  }
}
