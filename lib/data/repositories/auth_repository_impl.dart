import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../services/auth_service.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl([AuthService? authService]) : _authService = authService ?? AuthService();

  final AuthService _authService;

  @override
  Stream<User?> authStateChanges() => _authService.authStateChanges;

  @override
  User? currentUser() => _authService.currentUser;

  @override
  Future<UserCredential> signIn(String email, String password) => _authService.signIn(email, password);

  @override
  Future<UserCredential> signUp(String email, String password, String displayName) =>
      _authService.signUp(email, password, displayName);

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) => _authService.sendPasswordResetEmail(email);
}
