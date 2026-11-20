import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:huffaz_app/screens/auth/login_screen.dart';
import 'package:huffaz_app/services/auth_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthService extends Mock implements AuthService {}

/// Runs the real login screen on a device or simulator with a mocked auth
/// backend, so the flow is exercised end to end without network or accounts.
///
///   flutter test integration_test -d DEVICE_ID
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('teacher sees a clear error after a wrong password',
      (tester) async {
    final auth = MockAuthService();
    when(() => auth.signIn(
            email: any(named: 'email'), password: any(named: 'password')))
        .thenThrow(const AuthException('Invalid login credentials'));

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>.value(
        value: AppProvider(authService: auth),
        child: MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'), 'teacher@example.com');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'not-the-password');
    await tester.tap(find.text('Sign In'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Invalid email or password. Please try again.'),
        findsOneWidget);
  });
}
