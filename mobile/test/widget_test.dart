import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sbd_tracker/main.dart';
import 'package:sbd_tracker/services/auth_service.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: const SBDApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
