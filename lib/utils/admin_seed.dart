import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AdminSeed {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> seedAdminUser() async {
    try {
      // Check if admin exists
      final adminEmail = 'admin@example.com';
      final adminPass = 'admin12';
      
      try {
        // Try to sign in first
        await _auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPass,
        );
      } catch (e) {
        // If sign in fails, create admin user
        final credential = await _auth.createUserWithEmailAndPassword(
          email: adminEmail,
          password: adminPass,
        );

        if (credential.user != null) {
          final adminUser = UserModel(
            id: credential.user!.uid,
            email: adminEmail,
            role: UserRole.admin,
            name: 'admin',
          );

          await _firestore
              .collection('users')
              .doc(credential.user!.uid)
              .set(adminUser.toMap());
        }
      }
    } catch (e) {
      print('Error seeding admin user: $e');
    }
  }
}
