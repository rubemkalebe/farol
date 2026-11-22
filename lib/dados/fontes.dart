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
  final yaml = loadYaml(await rootBundle.loadString('fontes/fontes.yaml')) as YamlMap;
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
