import 'dart:io';

import 'package:farol/dados/regiao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const texto = '''
Nacional
:::regiao bh
Cemig
:::
:::regiao natal,mossoro
Cosern
:::
Fim
''';

  test('mostra só o bloco da região', () {
    expect(filtrarRegiao(texto, 'bh'), allOf(contains('Cemig'), isNot(contains('Cosern'))));
    expect(filtrarRegiao(texto, 'mossoro'), allOf(contains('Cosern'), isNot(contains('Cemig'))));
    final outra = filtrarRegiao(texto, 'outra');
    expect(outra, allOf(contains('Nacional'), contains('Fim'), isNot(contains('Cemig')), isNot(contains('Cosern'))));
  });

  test('aponta blocos malformados', () {
    expect(errosDeRegiao(':::regiao xyz\na\n:::'), isNotEmpty);
    expect(errosDeRegiao(':::regiao bh\na'), isNotEmpty);
    expect(errosDeRegiao('a\n:::'), isNotEmpty);
    expect(errosDeRegiao(texto), isEmpty);
  });

  test('blocos de região dos capítulos estão bem formados', () {
    for (final arq in Directory('conteudo/capitulos').listSync().whereType<File>()) {
      expect(errosDeRegiao(arq.readAsStringSync()), isEmpty, reason: arq.path);
    }
  });

  test('cada cidade só vê os serviços locais dela', () {
    // Nomes que só podem aparecer para quem escolheu a região certa.
    // Citações [fonte: ...] ficam de fora: o id pode conter "cemig" etc.
    const proibidos = {
      'natal': ['Cemig', 'Copasa', 'Gasmig', '(31)', 'João XXIII', 'Mossoró'],
      'mossoro': ['Cemig', 'Copasa', 'Gasmig', '(31)', 'João XXIII', 'Estela'],
      'bh': ['Cosern', 'Caern', 'Potigás', '(84)', 'Natal', 'Mossoró'],
      'outra': ['Cemig', 'Copasa', 'Cosern', 'Caern', '(31)', '(84)'],
    };
    final citacao = RegExp(r'\[fonte: [a-z0-9-]+\]');
    for (final arq in Directory('conteudo/capitulos').listSync().whereType<File>()) {
      final bruto = arq.readAsStringSync();
      for (final MapEntry(key: regiao, value: nomes) in proibidos.entries) {
        final texto = filtrarRegiao(bruto, regiao).replaceAll(citacao, '');
        for (final nome in nomes) {
          expect(texto.contains(nome), isFalse, reason: '${arq.path} mostra "$nome" para $regiao');
        }
      }
    }
  });
}
