import 'dart:convert' show utf8;

import 'package:flutter/services.dart' show rootBundle;
import 'package:markdown/markdown.dart' as md;
import 'package:yaml/yaml.dart';

class Fonte {
  const Fonte({
    required this.id,
    required this.titulo,
    required this.orgao,
    required this.url,
    required this.acessado,
  });

  final String id;
  final String titulo;
  final String orgao;
  final String url;
  final String acessado;
}

Map<String, Fonte>? _cache;

Future<Map<String, Fonte>> carregarFontes() async {
  if (_cache != null) return _cache!;
  // loadString manda textos acima de 50 KB para outro isolate; o catálogo
  // passa disso, então a leitura e a decodificação são feitas aqui mesmo.
  final bytes = await rootBundle.load('fontes/fontes.yaml');
  final texto = utf8.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
  final yaml = loadYaml(texto) as YamlMap;
  return _cache = {
    for (final f in yaml['fontes'] as YamlList)
      f['id'] as String: Fonte(
        id: f['id'] as String,
        titulo: f['titulo'] as String,
        orgao: f['orgao'] as String,
        url: f['url'] as String,
        acessado: '${f['acessado']}',
      ),
  };
}

/// Reconhece `[fonte: id]` no Markdown e gera um elemento `<fonte>` com o id.
class SintaxeFonte extends md.InlineSyntax {
  SintaxeFonte() : super(r'\[fonte: ([a-z0-9-]+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('fonte', match.group(1)!));
    return true;
  }
}

/// Reconhece `[geral]`: orientação sem fonte oficial, escrita a partir de
/// conhecimento técnico comum. Aparece com um ícone diferente do de fonte.
class SintaxeGeral extends md.InlineSyntax {
  SintaxeGeral() : super(r'\[geral\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('geral', ''));
    return true;
  }
}
