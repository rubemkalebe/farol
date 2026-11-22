import 'package:yaml/yaml.dart';

import 'secoes.dart';

/// Busca sem IA: palavras sem acento, raiz de até 5 letras ("engasgou" e
/// "engasgo" viram "engas") e sinônimos do jeito que a gente fala.

const _de = 'áàâãäéèêëíìîïóòôõöúùûüç';
const _para = 'aaaaaeeeeiiiiooooouuuuc';

String normalizar(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _de.indexOf(ch);
    b.write(i < 0 ? ch : _para[i]);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

const _vazias = {
  'a', 'o', 'as', 'os', 'e', 'de', 'da', 'do', 'das', 'dos', 'em', 'no', 'na', 'nos', 'nas', 'um',
  'uma', 'que', 'com', 'pra', 'para', 'por', 'meu', 'minha', 'ele', 'ela', 'esta', 'ta', 'to',
  'tem', 'foi', 'se', 'eu', 'me', 'mais', 'muito', 'ai', 'como', 'fazer', 'faco', 'oque', 'qual',
  'agora', 'socorro', 'ajuda', 'filho', 'filha', 'mae', 'pai', 'vo', 'avo', 'pessoa', 'alguem',
};

String raiz(String palavra) => palavra.length <= 5 ? palavra : palavra.substring(0, 5);

Iterable<String> _palavras(String texto) =>
    normalizar(texto).split(' ').where((p) => p.length >= 2 && !_vazias.contains(p));

/// Texto sem marcações, para mostrar um trecho no resultado.
String textoLimpo(String markdown) => markdown
    .replaceAll(RegExp(r'\[(fonte|marcar): [a-z0-9-]+\]'), '')
    .replaceAll('[geral]', '')
    .replaceAllMapped(RegExp(r'\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1)!)
    .replaceAll(RegExp(r'[*>#|_]'), '')
    .replaceAll(RegExp(r'[ \t]+'), ' ');

Map<String, List<String>> lerSinonimos(String yamlTexto) {
  final y = loadYaml(yamlTexto) as YamlMap;
  return {
    for (final MapEntry(:key, :value) in (y['sinonimos'] as YamlMap).entries)
      raiz(normalizar(key as String)): [for (final v in value as YamlList) raiz(normalizar(v as String))],
  };
}

class Resultado {
  const Resultado(this.secao, this.pontos, this.trecho);

  final Secao secao;
  final double pontos;
  final String trecho;
}

class Busca {
  Busca(this.secoes, this.sinonimos)
      : _titulos = [for (final s in secoes) {for (final p in _palavras(s.titulo)) raiz(p)}],
        _corpos = [for (final s in secoes) [for (final p in _palavras(textoLimpo(s.markdown))) raiz(p)]];

  final List<Secao> secoes;
  final Map<String, List<String>> sinonimos;
  final List<Set<String>> _titulos;
  final List<List<String>> _corpos;

  List<Resultado> buscar(String consulta, {int limite = 12}) {
    final termos = <String, double>{};
    for (final p in _palavras(consulta)) {
      final r = raiz(p);
      termos[r] = 1;
      for (final s in sinonimos[r] ?? const <String>[]) {
        termos.putIfAbsent(s, () => 0.8);
      }
    }
    if (termos.isEmpty) return const [];

    final resultados = <Resultado>[];
    for (var i = 0; i < secoes.length; i++) {
      var pontos = 0.0;
      for (final MapEntry(key: t, value: peso) in termos.entries) {
        if (_titulos[i].contains(t)) pontos += 6 * peso;
        final vezes = _corpos[i].where((p) => p == t).length;
        pontos += (vezes > 3 ? 3 : vezes) * peso;
      }
      if (pontos > 0) resultados.add(Resultado(secoes[i], pontos, _trecho(secoes[i], termos.keys.toSet())));
    }
    resultados.sort((a, b) => b.pontos.compareTo(a.pontos));
    return resultados.take(limite).toList();
  }

  String _trecho(Secao s, Set<String> termos) {
    String curto(String l) => l.length > 140 ? '${l.substring(0, 140)}…' : l;
    final linhas = [
      for (final l in textoLimpo(s.markdown).split('\n'))
        if (l.trim().isNotEmpty && !RegExp(r'^[-: ]+$').hasMatch(l.trim())) l.trim(),
    ];
    for (final l in linhas) {
      if (_palavras(l).any((p) => termos.contains(raiz(p)))) return curto(l);
    }
    // Achou só pelo título: mostra o começo da seção.
    return linhas.isEmpty ? '' : curto(linhas.first);
  }
}
