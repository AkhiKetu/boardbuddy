import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/user_profile_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserProfileService _profileService = UserProfileService();

  StreamSubscription<User?>? _subscription;

  User? _user;

  bool _isLoading = false;
  bool _isInitialized = false;
  bool _disposed = false;

  String? _errorMessage;
  String? _profileSyncError;

  // Prevent duplicate profile synchronization.
  final Set<String> _syncingUserIds = {};
  final Set<String> _syncedUserIds = {};

  AuthProvider() {
    _user = _auth.currentUser;

    _subscription = _auth.userChanges().listen(
      (user) {
        _user = user;
        _isInitialized = true;

        notifyListeners();

        // Save the current user's profile when ready.
        if (user != null) {
          unawaited(_ensureUserProfile(user));
        }
      },
      onError: (Object error) {
        _isInitialized = true;
        _errorMessage = 'Unable to check authentication status.';
        notifyListeners();
      },
    );
  }

  // Current Firebase user
  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  String? get profileSyncError => _profileSyncError;

  String? get userId => _user?.uid;

  String? get email => _user?.email;

  String? get name => _user?.displayName;

  // Save user profile to Cloud Firestore.
  Future<void> _ensureUserProfile(User user) async {
    final uid = user.uid;

    // Registration may fire an auth event before
    // the display name has been updated.
    // Wait for a later userChanges event in that case.
    if ((user.displayName?.trim().length ?? 0) < 2) {
      return;
    }

    if (_syncedUserIds.contains(uid) || _syncingUserIds.contains(uid)) {
      return;
    }

    _syncingUserIds.add(uid);

    try {
      await _profileService.ensureProfile(user);

      _syncedUserIds.add(uid);
      _profileSyncError = null;

      debugPrint('Firestore user profile synchronized successfully.');
    } catch (error) {
      _profileSyncError = 'Unable to save your Firestore profile.';

      debugPrint('Firestore profile synchronization failed: $error');
    } finally {
      _syncingUserIds.remove(uid);

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  // Convert Firebase errors into readable messages.
  String _firebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Please use a stronger password.';

      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';

      case 'network-request-failed':
        return 'Please check your internet connection.';

      case 'operation-not-allowed':
        return 'Email/Password authentication is not enabled.';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      default:
        return error.message ?? 'Authentication failed.';
    }
  }

  // Register with name, email and password.
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (name.trim().length < 2) {
        _errorMessage = 'Please enter a valid full name.';
        return false;
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Save the display name in Firebase Auth.
      await credential.user?.updateDisplayName(name.trim());

      await credential.user?.reload();

      _user = _auth.currentUser;

      // Also trigger profile creation explicitly.
      if (_user != null) {
        unawaited(_ensureUserProfile(_user!));
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _firebaseError(error);
      return false;
    } catch (_) {
      _errorMessage = 'Registration could not be completed.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login using email and password.
  Future<bool> login({required String email, required String password}) async {
    if (_isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _user = credential.user;

      // Create a missing Firestore profile if needed.
      if (_user != null) {
        unawaited(_ensureUserProfile(_user!));
      }

      notifyListeners();
      return true;
    } on FirebaseAuthException catch (error) {
      _errorMessage = _firebaseError(error);
      return false;
    } catch (_) {
      _errorMessage = 'Login failed. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out of Firebase.
  Future<void> logout() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signOut();

      _user = null;
      _profileSyncError = null;
      _syncedUserIds.clear();

      notifyListeners();
    } on FirebaseAuthException catch (error) {
      _errorMessage = _firebaseError(error);
    } catch (_) {
      _errorMessage = 'Logout failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}
