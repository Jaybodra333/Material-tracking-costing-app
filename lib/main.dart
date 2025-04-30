import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/admin/admin_dashboard_page.dart';
import 'pages/admin/materials/material_list_page.dart';
import 'pages/admin/users/user_list_page.dart';
import 'pages/admin/analytics/analytics_page.dart';
import 'models/user_model.dart';
import 'utils/database_seed.dart';
import 'utils/admin_seed.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Seed initial data
  await DatabaseSeed().seedMaterialsData();
  await AdminSeed().seedAdminUser();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/admin/materials': (context) => MaterialListPage(),
        '/admin/users': (context) => UserListPage(),
        '/admin/analytics': (context) => AnalyticsPage(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoginPage();
          }
          
          // Check user role
          return FutureBuilder<UserModel?>( 
            future: AuthService().getCurrentUser(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data?.role == UserRole.admin) {
                return AdminDashboardPage();
              }

              return HomePage();
            },
          );
        },
      ),
    );
  }
}
