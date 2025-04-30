import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user with role
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return UserModel.fromFirestore(doc);
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
    String name,
    UserRole role,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // For login, we don't create a new user document, but verify it exists
      if (credential.user != null) {
        final doc = await _firestore.collection('users').doc(credential.user!.uid).get();
        if (!doc.exists) {
          // Create user document if it doesn't exist (fallback)
          final userModel = UserModel(
            id: credential.user!.uid,
            email: email,
            role: role,
            name: name.isEmpty ? email : name,
          );
          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(userModel.toMap());
        }
      }
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Register with email and password
  Future<UserModel?> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
    UserRole role,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      if (credential.user != null) {
        final userModel = UserModel(
          id: credential.user!.uid,
          email: email,
          role: role,
          name: name,
        );
        
        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(userModel.toMap());
            
        return userModel;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Handle Firebase Auth errors
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password';
      default:
        return e.message ?? 'An unknown error occurred';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<bool> isAdmin() async {
    final user = await getCurrentUser();
    return user?.role == UserRole.admin;
  }

  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .toList());
  }
}
