import 'package:yaml/yaml.dart';

class Opcao {
  const Opcao({required this.texto, this.vai, this.secoes = const [], this.ligar = const []});

  final String texto;
  final String? vai;
  final List<String> secoes;
  final List<String> ligar;
}

class Pergunta {
  const Pergunta(this.id, this.texto, this.opcoes);

  final String id;
  final String texto;
  final List<Opcao> opcoes;
}

Map<String, Pergunta> lerRoteiro(String yamlTexto) {
  final y = loadYaml(yamlTexto) as YamlMap;
  return {
    for (final MapEntry(:key, :value) in y.entries)
      key as String: Pergunta(
        key,
        value['pergunta'] as String,
        [
          for (final o in value['opcoes'] as YamlList)
            Opcao(
              texto: o['texto'] as String,
              vai: o['vai'] as String?,
              secoes: [for (final s in (o['secoes'] as YamlList?) ?? YamlList()) s as String],
              ligar: [for (final t in (o['ligar'] as YamlList?) ?? YamlList()) '$t'],
            ),
        ],
      ),
  };
}
