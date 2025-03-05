import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Firebase Authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Function to handle user signup
  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phonenumber,
  }) async {
    try {
      // Create user in Firebase Authentication with email and password
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Save additional user data (name, role) in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'phonenumber': phonenumber.trim(),
        'role': role, // Role determines if user is Admin or User
      });

      return null; // Success: no error message
    } catch (e) {
      return e.toString(); // Error: return the exception message
    }
  }

  // Function to handle user login
  Future<String?> login({required String email, required String password}) async {
  try {
    // Sign in the user using Firebase Authentication

    await Future.delayed(const Duration(milliseconds: 500));

    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    print("Login successful for user: ${userCredential.user?.uid}");

    // Fetch the user's role from Firestore
     DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      print("User document exists: ${userDoc.exists}");
      if (userDoc.exists) {
        print("User role: ${userDoc['role']}");
        return userDoc['role']; // Return the user's role (Company/User)
      } else {
        print("User document does not exist in Firestore");
        return "User data not found";
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors with clear messages
      print("FirebaseAuthException: ${e.code} - ${e.message}");
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Wrong password provided';
        case 'invalid-credential':
          return 'Invalid email or password';
        case 'too-many-requests':
          return 'Too many attempts. Try again later';
        default:
          return e.message ?? 'Authentication failed';
      }
    } catch (e) {
      print("Login error: $e");
      return e.toString(); // Generic error handler
    }
  }

  // for user log out
 Future<void> signOut() async {
    await _auth.signOut();
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
  
  // Check if user is logged in
  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }
}

//OLD