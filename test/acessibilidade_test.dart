import 'package:farol/dados/preferencias.dart';
import 'package:farol/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Celular comum (390 x 844) com letra grande no sistema e "Muito grande"
/// no app. Texto estourando a tela vira erro e derruba o teste.
Future<void> abrirComLetraGrande(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  escalaTexto.value = 1.5;
  addTearDown(() => escalaTexto.value = 1.0);
  await tester.pumpWidget(const FarolApp());
  await tester.pumpAndSettle();
}

/// Rola a tela de cima até o alvo aparecer inteiro e toca nele.
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(
    alvo,
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.ensureVisible(alvo.first);
  await tester.pumpAndSettle();
  await tester.tap(alvo.first);
  await tester.pumpAndSettle();
}

Future<void> voltar(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    rootBundle.clear();
    SharedPreferences.setMockInitialValues({'cidade': 'rn/natal'});
  });

  testWidgets('telas principais não estouram com letra grande', (tester) async {
    await abrirComLetraGrande(tester);
    expect(find.text('FAROL'), findsOneWidget);

    // Emergência → engasgo (seção + botões de ligar)
    await tocar(tester, find.byKey(const ValueKey('botao-emergencia')));
    await tocar(
      tester,
      find.ancestor(
        of: find.textContaining('Engasgo'),
        matching: find.byType(InkWell),
      ),
    );
    expect(find.byKey(const ValueKey('ligar-192')), findsOneWidget);
    await voltar(tester);
    await voltar(tester);

    // Um guia com checklist e progresso
    await tocar(
      tester,
      find.ancestor(
        of: find.text('Antes de cair'),
        matching: find.byType(InkWell),
      ),
    );
    expect(find.byKey(const ValueKey('progresso')), findsOneWidget);
    await voltar(tester);

    // Ficha da família
    await tocar(
      tester,
      find.ancestor(
        of: find.text('Ficha da família'),
        matching: find.byType(InkWell),
      ),
    );
    expect(find.text('Casa'), findsOneWidget);
    await voltar(tester);

    // Busca
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 20000));
    await tester.pumpAndSettle();
    await tocar(tester, find.byKey(const ValueKey('botao-busca')));
    await tester.enterText(find.byType(TextField), 'escorpião');
    await tester.pumpAndSettle();
    expect(find.textContaining('Escorpião'), findsWidgets);
  });

  testWidgets('tamanho da letra muda no app e fica salvo', (tester) async {
    await tester.pumpWidget(const FarolApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tamanho-texto')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Muito grande'));
    await tester.pumpAndSettle();
    expect(escalaTexto.value, 1.5);
    expect(
      (await SharedPreferences.getInstance()).getString('tamanho_texto'),
      'enorme',
    );
    escalaTexto.value = 1.0;
  });

  testWidgets('botões importantes têm nome para o leitor de tela', (
    tester,
  ) async {
    final semantica = tester.ensureSemantics();
    await tester.pumpWidget(const FarolApp());
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('Emergência: o que está acontecendo')),
      findsOneWidget,
    );
    // IconButton com tooltip: o leitor de tela anuncia a dica.
    expect(find.byTooltip('Tamanho da letra'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('botao-emergencia')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Ligar para 192, SAMU'), findsOneWidget);
    semantica.dispose();
  });

  testWidgets('tablet deitado: conteúdo centralizado e sem estourar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FarolApp());
    await tester.pumpAndSettle();
    // O botão de emergência respeita a largura de leitura.
    expect(
      tester.getSize(find.byKey(const ValueKey('botao-emergencia'))).width,
      lessThanOrEqualTo(720),
    );

    await tocar(tester, find.byKey(const ValueKey('botao-emergencia')));
    await tocar(
      tester,
      find.ancestor(
        of: find.textContaining('Sangrando'),
        matching: find.byType(InkWell),
      ),
    );
    expect(find.textContaining('Sangramento forte'), findsWidgets);
  });
}
