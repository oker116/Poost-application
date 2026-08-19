import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poost_media_buying_os/main.dart' show LoginPage;

void main() {
  // Regression test for a real incident: the login screen used to ship with
  // TextEditingController(text: 'yosef aped') / TextEditingController(text:
  // '162007') as defaults, which meant real owner credentials were baked
  // into a public repo. This test fails loudly if that ever comes back.
  testWidgets('login fields start empty — no credentials baked into source', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, 2);
    for (final field in fields) {
      expect(field.controller?.text ?? '', isEmpty, reason: 'Login field must not be pre-filled with credentials');
    }
  });
}
