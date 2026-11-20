import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:huffaz_app/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService auth;
  late AppProvider provider;

  setUp(() {
    auth = MockAuthService();
    provider = AppProvider(authService: auth);
  });

  Future<String?> signIn() =>
      provider.signIn(email: 'teacher@example.com', password: 'secret');

  group('AppProvider.signIn', () {
    test('maps invalid credentials to a friendly message', () async {
      when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const AuthException('Invalid login credentials'));

      final error = await signIn();

      expect(error, isNotNull);
      expect(error!.toLowerCase(), contains('invalid email or password'));
      expect(provider.isLoggedIn, isFalse);
    });

    test('maps unverified emails to a clear message', () async {
      when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const AuthException('Email not confirmed'));

      final error = await signIn();

      expect(error, contains('not verified'));
    });

    test('reports a failed sign in when no user is returned', () async {
      when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => AuthResponse());

      final error = await signIn();

      expect(error, 'Sign in failed');
      expect(provider.isLoggedIn, isFalse);
    });

    test('maps network failures to an offline message', () async {
      when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const SocketException('Failed host lookup'));

      final error = await signIn();

      expect(error, contains('No internet connection'));
    });

    test('clears the loading flag and notifies listeners around the call',
        () async {
      when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow(const AuthException('Invalid login credentials'));
      var notifications = 0;
      provider.addListener(() => notifications++);

      await signIn();

      expect(provider.isLoading, isFalse);
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('passes the entered credentials to the auth service', () async {
      when(() => auth.signIn(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => AuthResponse());

      await signIn();

      verify(() => auth.signIn(email: 'teacher@example.com', password: 'secret'))
          .called(1);
    });
  });
}
