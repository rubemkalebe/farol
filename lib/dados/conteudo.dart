import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';

class Capitulo {
  const Capitulo({
    required this.id,
    required this.titulo,
    required this.resumo,
    required this.icone,
  });

  final String id;
  final String titulo;
  final String resumo;
  final String icone;

  String get caminho => 'conteudo/capitulos/$id.md';
}

Future<List<Capitulo>> carregarIndice() async {
  final texto = await rootBundle.loadString('conteudo/indice.yaml');
  final yaml = loadYaml(texto) as YamlMap;
  return [
    for (final c in yaml['capitulos'] as YamlList)
      Capitulo(
        id: c['id'] as String,
        titulo: c['titulo'] as String,
        resumo: (c['resumo'] ?? '') as String,
        icone: (c['icone'] ?? '') as String,
      ),
  ];
}

Future<String> carregarCapitulo(Capitulo c) => rootBundle.loadString(c.caminho);
