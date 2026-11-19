import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';

class AuthService {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;

  Session? get currentSession => supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  Future<bool> isSignedIn() async {
    final session = supabase.auth.currentSession;
    return session != null && !session.isExpired;
  }
}
