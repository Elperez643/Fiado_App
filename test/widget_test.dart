import 'package:fiado_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login screen renders without session provider errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(find.text('Fiado App'), findsWidgets);
    expect(find.text('Negocios'), findsWidgets);
    expect(find.text('Entrar al negocio'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
  });
}
