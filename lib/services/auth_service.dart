import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // Login user
  Future<User?> login(
    String email,
    String password,
  ) async {
    try {
      UserCredential result =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user;
    } on FirebaseAuthException catch (e){
      print("===========FIREBASE ERROR=========");
      print("Code: ${e.code}");
      print("Message: ${e.message}");
      rethrow;
    }
  }

  // Get user information from Firestore
  Future<Map<String, dynamic>?> getUserData(
    String uid,
  ) async {
    DocumentSnapshot document =
        await _firestore
            .collection('users')
            .doc(uid)
            .get();

    if (document.exists) {
      return document.data()
          as Map<String, dynamic>;
    }

    return null;
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}