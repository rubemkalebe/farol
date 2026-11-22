import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('todo capítulo do índice tem arquivo .md', () {
    final indice = loadYaml(File('conteudo/indice.yaml').readAsStringSync()) as YamlMap;
    final capitulos = indice['capitulos'] as YamlList;
    expect(capitulos, isNotEmpty);
    for (final c in capitulos) {
      expect(File('conteudo/capitulos/${c['id']}.md').existsSync(), isTrue,
          reason: 'falta conteudo/capitulos/${c['id']}.md');
    }
  });
}
