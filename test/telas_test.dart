import 'package:farol/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('início lista os capítulos e abre um', (tester) async {
    await tester.pumpWidget(const FarolApp());
    await tester.pumpAndSettle();
    expect(find.text('FAROL'), findsOneWidget);
    expect(find.text('Durante o apagão'), findsOneWidget);

    await tester.tap(find.text('Durante o apagão'));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.textContaining('O que pode matar'), findsWidgets);

    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Consultado em'), findsOneWidget);
  });
}
