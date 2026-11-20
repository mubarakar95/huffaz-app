import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:huffaz_app/screens/auth/login_screen.dart';
import 'package:huffaz_app/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthService extends Mock implements AuthService {}

Widget buildLogin(AppProvider provider) => ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const LoginScreen(),
      ),
    );

void main() {
  late MockAuthService auth;

  setUp(() {
    auth = MockAuthService();
  });

  testWidgets('shows validation messages for empty fields', (tester) async {
    await tester.pumpWidget(buildLogin(AppProvider(authService: auth)));
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    verifyNever(() => auth.signIn(
        email: any(named: 'email'), password: any(named: 'password')));
  });

  testWidgets('shows the error banner when credentials are rejected',
      (tester) async {
    when(() => auth.signIn(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const AuthException('Invalid login credentials'));
    await tester.pumpWidget(buildLogin(AppProvider(authService: auth)));
    await tester.pump(const Duration(seconds: 1));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'), 'a@b.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'wrong-password');
    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Invalid email or password. Please try again.'),
        findsOneWidget);
    verify(() => auth.signIn(email: 'a@b.com', password: 'wrong-password'))
        .called(1);
  });
}
