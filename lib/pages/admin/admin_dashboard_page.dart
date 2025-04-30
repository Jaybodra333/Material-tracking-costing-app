import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import 'materials/material_list_page.dart';
import 'users/user_list_page.dart';
import 'analytics/analytics_page.dart';

class AdminDashboardPage extends StatefulWidget {
  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _authService = AuthService();

  void _navigateToPage(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple),
              child: Text(
                'Admin Panel',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Manage Materials'),
              onTap: () => _navigateToPage(context, '/admin/materials'),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Manage Users'),
              onTap: () => _navigateToPage(context, '/admin/users'),
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Analytics'),
              onTap: () => _navigateToPage(context, '/admin/analytics'),
            ),
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('Reports'),
              onTap: () => _navigateToPage(context, '/admin/reports'),
            ),
          ],
        ),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildDashboardCard(
            'Materials',
            Icons.inventory,
            () => _navigateToPage(context, '/admin/materials'),
          ),
          _buildDashboardCard(
            'Users',
            Icons.people,
            () => _navigateToPage(context, '/admin/users'),
          ),
          _buildDashboardCard(
            'Analytics',
            Icons.analytics,
            () => _navigateToPage(context, '/admin/analytics'),
          ),
          _buildDashboardCard(
            'Reports',
            Icons.summarize,
            () => _navigateToPage(context, '/admin/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(String title, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
