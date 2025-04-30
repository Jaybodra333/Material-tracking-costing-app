import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, operator }

class UserModel {
  final String id;
  final String email;
  final UserRole role;
  final String name;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    required this.name,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.operator,
      ),
      name: data['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.toString().split('.').last,
      'name': name,
    };
  }
}
