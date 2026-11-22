import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<User?>? _subscription;

  User? _user;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _auth.currentUser;

    // Detect login and logout automatically.
    _subscription = _auth.userChanges().listen((user) {
      _user = user;
      _isInitialized = true;
      notifyListeners();
    });
  }

  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get isLoading => _isLoading;

  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  String? get userId => _user?.uid;

  String? get email => _user?.email;

  String? get name => _user?.displayName;

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
      if (name.trim().isEmpty) {
        _errorMessage = 'Please enter your name.';
        return false;
      }

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      _user = _auth.currentUser;
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

  // Logout from Firebase.
  Future<void> logout() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth.signOut();
      _user = null;
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
    _subscription?.cancel();
    super.dispose();
  }
}
