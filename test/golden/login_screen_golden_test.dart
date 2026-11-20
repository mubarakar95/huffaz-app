import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:huffaz_app/providers/app_provider.dart';
import 'package:huffaz_app/screens/auth/login_screen.dart';
import 'package:huffaz_app/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'golden_config.dart';

class MockAuthService extends Mock implements AuthService {}

final boundaryKey = GlobalKey();

void main() {
  useTolerantGoldens('test/golden/login_screen_golden_test.dart');

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('LoginScreen matches the ${brightness.name} golden',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: ChangeNotifierProvider<AppProvider>.value(
            value: AppProvider(authService: MockAuthService()),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(brightness: brightness, useMaterial3: true),
              home: const LoginScreen(),
            ),
          ),
        ),
      );
      // The screen has repeating ambient animations, so settle by time.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));

      await expectLater(
        find.byKey(boundaryKey),
        matchesGoldenFile('goldens/login_screen_${brightness.name}.png'),
      );
    });
  }
}
