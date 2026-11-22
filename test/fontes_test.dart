import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final fontes =
      (loadYaml(File('fontes/fontes.yaml').readAsStringSync()) as YamlMap)['fontes'] as YamlList;
  final capitulos = {
    for (final c in (loadYaml(File('conteudo/indice.yaml').readAsStringSync())
        as YamlMap)['capitulos'] as YamlList)
      c['id'] as String,
  };

  test('ids de fontes são únicos', () {
    final ids = [for (final f in fontes) f['id']];
    expect(ids.toSet().length, ids.length);
  });

  test('toda fonte tem os campos obrigatórios e valores válidos', () {
    for (final f in fontes) {
      for (final campo in ['id', 'tema', 'titulo', 'orgao', 'url', 'acessado', 'licenca', 'redistribuir', 'usado_em', 'notas']) {
        expect(f[campo], isNotNull, reason: '${f['id']} sem $campo');
      }
      expect(['sim', 'nao', 'verificar'], contains(f['redistribuir']), reason: f['id']);
      expect((f['url'] as String).startsWith('https://'), isTrue, reason: f['id']);
      for (final c in f['usado_em'] as YamlList) {
        expect(capitulos, contains(c), reason: '${f['id']} cita capítulo inexistente $c');
      }
    }
  });

  test('capítulos só citam fontes que existem', () {
    final ids = {for (final f in fontes) f['id'] as String};
    final citacao = RegExp(r'\[fonte: ([a-z0-9-]+)\]');
    for (final arq in Directory('conteudo/capitulos').listSync().whereType<File>()) {
      for (final m in citacao.allMatches(arq.readAsStringSync())) {
        expect(ids, contains(m.group(1)), reason: '${arq.path} cita fonte inexistente ${m.group(1)}');
      }
    }
  });
}
