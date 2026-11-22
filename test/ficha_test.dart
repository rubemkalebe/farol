import 'package:farol/dados/ficha.dart';
import 'package:farol/telas/ficha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('salva e lê de volta', () async {
    final f = Ficha(endereco: 'Rua A, 10', pontoEncontro: 'Praça')
      ..pessoas.add(
        Pessoa(nome: 'Ana', tipoSanguineo: 'O+', alergias: 'dipirona'),
      )
      ..contatos.add(
        Contato(nome: 'Bia', relacao: 'irmã', telefone: '31 99999-0000'),
      );
    await f.salvar();

    final lida = await Ficha.abrir();
    expect(lida.endereco, 'Rua A, 10');
    expect(lida.pessoas.single.alergias, 'dipirona');
    expect(lida.contatos.single.telefone, '31 99999-0000');
  });

  test('texto omite campos vazios', () {
    final f = Ficha(endereco: 'Rua A, 10')
      ..pessoas.add(Pessoa(nome: 'Ana', tipoSanguineo: 'O+'));
    final t = f.comoTexto();
    expect(t, contains('Endereço: Rua A, 10'));
    expect(t, contains('ANA'));
    expect(t, contains('Tipo sanguíneo: O+'));
    expect(t, isNot(contains('Alergias')));
    expect(t, isNot(contains('Ponto de encontro')));
  });

  testWidgets('adiciona contato pela tela', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: TelaFicha()));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Adicionar').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Bia');
    await tester.enterText(
      find.widgetWithText(TextField, 'Telefone com DDD'),
      '31 99999-0000',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Bia'), findsOneWidget);
    expect((await Ficha.abrir()).contatos.single.nome, 'Bia');
  });
}
