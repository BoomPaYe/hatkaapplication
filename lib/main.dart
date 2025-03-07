import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hatka/Service/Notification_service.dart';
import 'package:hatka/user/user_screen.dart';
import 'package:hatka/company/company_screen.dart'; // Assuming this exists
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  Widget? _initialScreen;

  @override
  void initState() {
    super.initState();
    _determineInitialRoute();
  }

  Future<void> _determineInitialRoute() async {
    try {
      print("✅ Starting authentication check");
      
      // Check if user is already logged in
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        print("✅ User is logged in: ${user.uid}");
        
        // Try to get cached role first for faster startup
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String? cachedRole = prefs.getString('userRole');
        
        if (cachedRole != null) {
          print("✅ Using cached role: $cachedRole");
          _navigateBasedOnRole(cachedRole);
        }
        
        // Always fetch the latest role from Firestore to ensure it's up-to-date
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          
          if (userDoc.exists && userDoc.data() != null) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            String role = userData['role'] ?? '';
            print("✅ Firestore role: $role");
            
            // Update cached role
            await prefs.setString('userRole', role);
            
            // Navigate based on role
            _navigateBasedOnRole(role);
          } else {
            print("❌ User document doesn't exist or is empty");
            setState(() {
              _initialScreen = UserScreen(); // Default to user screen
              _isLoading = false;
            });
          }
        } catch (e) {
          print("❌ Error fetching user data: $e");
          // If we have a cached role, we've already navigated
          // If not, default to user screen
          if (cachedRole == null) {
            setState(() {
              _initialScreen = UserScreen();
              _isLoading = false;
            });
          }
        }
      } else {
        print("✅ No user logged in, showing user screen");
        setState(() {
          _initialScreen = UserScreen(); // No user logged in, show user screen
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ Error during initial route determination: $e");
      setState(() {
        _initialScreen = UserScreen(); // Default to user screen on error
        _isLoading = false;
      });
    }
  }

  void _navigateBasedOnRole(String role) {
    setState(() {
      if (role.toLowerCase() == 'company') {
        _initialScreen = CompanyScreen(); // Navigate to company screen
      } else {
        _initialScreen = UserScreen(); // Navigate to user screen
      }
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return _initialScreen ?? UserScreen();
  }
}