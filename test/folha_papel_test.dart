import 'dart:io';

import 'package:farol/dados/ficha.dart';
import 'package:farol/dados/folha_papel.dart';
import 'package:farol/dados/locais.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

Future<String> _ler(String caminho) => File(caminho).readAsString();

void main() {
  test('tira os telefones do texto, sem marcação nem link de mapa', () {
    const md = '''
## Os principais

| Número | Para quê |
|---|---|
| [**192**](tel:192) | **SAMU**: emergência médica |

[fonte: anatel-sup-codigos]

### Onde ser atendido

- **João XXIII:** Av. Alfredo Balena, 400. [(31) 3239-9200](tel:3132399200) · [Abrir no mapa](mapa:Av.%20X) [fonte: fhemig-joao-xxiii]
- Sem telefone aqui.
''';
    final g = telefonesParaPapel(md);
    expect(g.map((e) => e.$1), ['Os principais', 'Onde ser atendido']);
    expect(g[0].$2.single, '192 — SAMU: emergência médica');
    expect(
      g[1].$2.single,
      'João XXIII: Av. Alfredo Balena, 400. (31) 3239-9200',
    );
  });

  test('folha de BH tem os números da cidade e vira um PDF', () async {
    final md = aplicarLocais(
      await _ler('conteudo/capitulos/contatos.md'),
      await blocosLocais('mg/belo-horizonte', ler: _ler),
    );
    final g = telefonesParaPapel(md);
    final tudo = g.expand((e) => e.$2).join('\n');
    expect(tudo, contains('192'));
    expect(tudo, contains('3239-9200'));
    expect(tudo, isNot(contains('[fonte')));
    expect(tudo, isNot(contains('mapa:')));
    expect(tudo, isNot(contains('**')));

    pw.Font fonte(String a) => pw.Font.ttf(
      File('assets/fontes/atkinson/$a').readAsBytesSync().buffer.asByteData(),
    );
    final ficha = Ficha(endereco: 'Rua A, 1')
      ..pessoas.add(Pessoa(nome: 'Ana', tipoSanguineo: 'O+'));
    final pdf = await gerarFolhaPapel(
      cidade: 'Belo Horizonte',
      telefones: g,
      regular: fonte('AtkinsonHyperlegible-Regular.ttf'),
      negrito: fonte('AtkinsonHyperlegible-Bold.ttf'),
      ficha: ficha,
    );
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(5000));
  });
}
