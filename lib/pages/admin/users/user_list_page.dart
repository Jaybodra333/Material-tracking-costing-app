import 'package:flutter/material.dart';
import '../../../models/user_model.dart';
import '../../../services/auth_service.dart';

class UserListPage extends StatefulWidget {
  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showUserForm(context),
          ),
        ],
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: _authService.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final users = snapshot.data ?? [];
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showUserForm(context, user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteUser(user),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showUserForm(BuildContext context, [UserModel? user]) async {
    // Implement user form dialog
  }

  Future<void> _deleteUser(UserModel user) async {
    // Implement user deletion with confirmation
  }
}
