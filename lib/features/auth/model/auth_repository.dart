import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return true;
  }

  Future<bool> register(String name, String email, String password) async {
    UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    
    await credential.user?.updateDisplayName(name.trim());
    
    if (credential.user != null) {
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'uid': credential.user!.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    
    return true;
  }

  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }

  Future<UserModel?> getActiveUser() async {
    User? user = _auth.currentUser;
    if (user == null) return null;
    
    return UserModel(
      name: user.displayName ?? user.email?.split('@').first ?? 'User',
      email: user.email ?? '',
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
