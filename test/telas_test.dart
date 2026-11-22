import 'package:farol/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // O rootBundle guarda Futures entre testes; um Future criado no teste
  // anterior não completa no seguinte.
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('todo capítulo abre sem erro', (tester) async {
    await tester.pumpWidget(const FarolApp());
    await tester.pumpAndSettle();
    for (final titulo in ['Durante o apagão', 'Primeiros socorros', 'Antes de cair',
        'Contatos de emergência', 'Quando a energia voltar', 'Outros desastres']) {
      await tester.ensureVisible(find.text(titulo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(titulo));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget, reason: titulo);
      expect(find.textContaining('Erro ao abrir'), findsNothing, reason: titulo);
      expect(find.byType(CircularProgressIndicator), findsNothing, reason: titulo);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('item da checklist marca e continua marcado ao reabrir', (tester) async {
    // Tela alta: o Markdown só monta o que está visível.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FarolApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antes de cair'));
    await tester.pumpAndSettle();

    final caixa = find.byKey(const ValueKey('marcar-agua-beber'));
    expect(find.descendant(of: caixa, matching: find.byIcon(Icons.check_box_outline_blank)), findsOneWidget);
    await tester.ensureVisible(caixa);
    await tester.pumpAndSettle();
    await tester.tap(caixa);
    await tester.pumpAndSettle();
    expect(find.descendant(of: caixa, matching: find.byIcon(Icons.check_box)), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antes de cair'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const ValueKey('marcar-agua-beber')),
        matching: find.byIcon(Icons.check_box)), findsOneWidget);
  });
}
