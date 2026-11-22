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
    Navigator.of(tester.element(find.textContaining('Consultado em'))).pop();
    await tester.pumpAndSettle();

    // Orientação sem fonte oficial abre o aviso de orientação geral.
    for (var i = 0; i < 60 && find.byIcon(Icons.help_outline).evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byIcon(Icons.help_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.help_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Orientação geral'), findsOneWidget);
  });
}
