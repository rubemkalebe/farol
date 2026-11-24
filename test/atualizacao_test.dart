import 'package:farol/dados/atualizacao.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('compara versões número a número', () {
    expect(compararVersoes('1.10.0', '1.9.2'), 1);
    expect(compararVersoes('v1.2.0', '1.2.0'), 0);
    expect(compararVersoes('1.2', '1.2.1'), -1);
    expect(compararVersoes('1.2.0+5', '1.2.0'), 0);
  });

  group('aviso de versão nova', () {
    late SharedPreferences prefs;
    var perguntas = 0;
    String? publicada;
    final hoje = DateTime(2026, 11, 24);

    Atualizacao abrir() => Atualizacao(
      prefs,
      publicada: () async {
        perguntas++;
        return publicada;
      },
      instalada: () async => '1.1.0',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      perguntas = 0;
      publicada = '1.2.0';
    });

    test(
      'mostra a versão mais nova e pergunta só uma vez por semana',
      () async {
        expect(await abrir().versaoNova(hoje), '1.2.0');
        expect(
          await abrir().versaoNova(hoje.add(const Duration(days: 3))),
          '1.2.0',
        );
        expect(perguntas, 1);
        publicada = '1.3.0';
        expect(
          await abrir().versaoNova(hoje.add(const Duration(days: 8))),
          '1.3.0',
        );
        expect(perguntas, 2);
      },
    );

    test('sem internet, fica quieto e tenta de novo depois', () async {
      publicada = null;
      expect(await abrir().versaoNova(hoje), isNull);
      publicada = '1.2.0';
      expect(await abrir().versaoNova(hoje), '1.2.0');
    });

    test('não avisa de versão igual ou mais velha', () async {
      publicada = '1.1.0';
      expect(await abrir().versaoNova(hoje), isNull);
    });

    test('"Agora não" esconde até sair outra versão', () async {
      final a = abrir();
      await a.dispensar((await a.versaoNova(hoje))!);
      expect(await abrir().versaoNova(hoje), isNull);
      publicada = '1.2.1';
      expect(
        await abrir().versaoNova(hoje.add(const Duration(days: 7))),
        '1.2.1',
      );
    });
  });
}
