import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> authStateChanges();
  User? currentUser();
  Future<UserCredential> signIn(String email, String password);
  Future<UserCredential> signUp(String email, String password, String displayName);
  Future<void> signOut();
  Future<void> sendPasswordResetEmail(String email);
}
