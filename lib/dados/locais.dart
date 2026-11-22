import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

/// Dados locais em camadas:
///
/// ```
/// locais/padrao.yaml            → "Outra cidade"; define todos os blocos
/// locais/estados/UF.yaml        → CIATox, Defesa Civil estadual...
/// locais/empresas/ID.yaml       → energia, água, gás
/// locais/cidades/UF/ID.yaml     → Defesa Civil municipal, hospitais...
/// ```
///
/// Os capítulos têm linhas `{{bloco}}`. Vale o bloco da camada mais
/// específica: cidade > empresas > estado > padrão.

class Cidade {
  const Cidade(this.id, this.nome, this.uf);

  final String id;
  final String nome;
  final String uf;

  String get rotulo => '$nome ($uf)';
}

/// Lê um arquivo de texto. No app é o rootBundle; nos testes, o disco.
typedef LerTexto = Future<String> Function(String caminho);

Future<String> _lerAsset(String caminho) => rootBundle.loadString(caminho);

Future<List<Cidade>> carregarCidades({LerTexto ler = _lerAsset}) async {
  final yaml = loadYaml(await ler('locais/indice.yaml')) as YamlMap;
  final lista = [
    for (final c in yaml['cidades'] as YamlList)
      Cidade(c['id'] as String, c['nome'] as String, c['uf'] as String),
  ];
  lista.sort((a, b) => a.nome.compareTo(b.nome));
  return lista;
}

Future<YamlMap> _abrir(LerTexto ler, String caminho) async =>
    loadYaml(await ler(caminho)) as YamlMap;

Map<String, String> _blocos(YamlMap arquivo) => {
  for (final MapEntry(:key, :value)
      in ((arquivo['blocos'] as YamlMap?) ?? YamlMap()).entries)
    key as String: ((value ?? '') as String).trimRight(),
};

/// Junta os blocos das camadas para a cidade escolhida (null = outra).
Future<Map<String, String>> blocosLocais(
  String? cidadeId, {
  LerTexto ler = _lerAsset,
}) async {
  final blocos = _blocos(await _abrir(ler, 'locais/padrao.yaml'));
  if (cidadeId == null) return blocos;

  final cidade = await _abrir(ler, 'locais/cidades/$cidadeId.yaml');
  final uf = cidade['uf'] as String;
  blocos.addAll(_blocos(await _abrir(ler, 'locais/estados/$uf.yaml')));
  for (final tipo in ['energia', 'agua', 'gas']) {
    final empresa = cidade[tipo] as String?;
    if (empresa != null) {
      blocos.addAll(
        _blocos(await _abrir(ler, 'locais/empresas/$empresa.yaml')),
      );
    }
  }
  blocos.addAll(_blocos(cidade));
  return blocos;
}

final _marca = RegExp(r'^\{\{([a-z0-9-]+)\}\}\s*$');

/// Troca cada linha `{{bloco}}` pelo texto local. Bloco vazio some.
/// Linha de tabela (começa com "|") entra colada; o resto ganha linha em
/// branco depois, para não grudar no parágrafo seguinte.
String aplicarLocais(String markdown, Map<String, String> blocos) {
  final saida = <String>[];
  for (final linha in markdown.split('\n')) {
    final m = _marca.firstMatch(linha);
    if (m == null) {
      saida.add(linha);
      continue;
    }
    final texto = blocos[m.group(1)] ?? '';
    if (texto.isEmpty) continue;
    saida.add(texto);
    if (!texto.startsWith('|')) saida.add('');
  }
  return saida.join('\n');
}

Iterable<String> marcasLocais(String markdown) sync* {
  for (final linha in markdown.split('\n')) {
    final m = _marca.firstMatch(linha);
    if (m != null) yield m.group(1)!;
  }
}

// ── cidade escolhida ──

const _chave = 'cidade';
const outraCidade = 'outra';

/// Ids da primeira versão, que tinha só três cidades fixas.
const _antigos = {
  'bh': 'mg/belo-horizonte',
  'natal': 'rn/natal',
  'mossoro': 'rn/mossoro',
  'outra': outraCidade,
};

Future<String?> lerCidade() async {
  final prefs = await SharedPreferences.getInstance();
  final atual = prefs.getString(_chave);
  if (atual != null) return atual;
  final antigo = prefs.getString('regiao');
  if (antigo == null) return null;
  final migrado = _antigos[antigo] ?? outraCidade;
  await prefs.setString(_chave, migrado);
  await prefs.remove('regiao');
  return migrado;
}

/// Blocos locais da cidade salva no aparelho (ou do padrão).
Future<Map<String, String>> blocosDaCidadeEscolhida() async {
  final cidade = await lerCidade();
  return blocosLocais(cidade == null || cidade == outraCidade ? null : cidade);
}

Future<void> salvarCidade(String id) async =>
    (await SharedPreferences.getInstance()).setString(_chave, id);
