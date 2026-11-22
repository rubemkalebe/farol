import 'conteudo.dart';
import 'locais.dart';

/// Um trecho de guia: o que vem depois de um título "## ".
class Secao {
  const Secao(this.capitulo, this.titulo, this.markdown);

  final Capitulo capitulo;
  final String titulo;
  final String markdown;

  /// "id-do-capitulo/Título", a forma usada no roteiro de emergência.
  String get chave => '${capitulo.id}/$titulo';
}

/// Divide o capítulo pelos títulos "## ". O texto antes do primeiro título
/// vira uma seção com o nome do capítulo.
List<Secao> dividirEmSecoes(Capitulo c, String markdown) {
  final secoes = <Secao>[];
  var titulo = c.titulo;
  var corpo = <String>[];
  void fechar() {
    // Tira o separador "---" que fica no fim de cada seção.
    final texto = corpo
        .join('\n')
        .trim()
        .replaceFirst(RegExp(r'(\n\s*---\s*)+$'), '')
        .trim();
    // Separadores "---" sozinhos não contam como conteúdo.
    if (texto.replaceAll('---', '').trim().isNotEmpty) {
      secoes.add(Secao(c, titulo, texto));
    }
  }

  for (final linha in markdown.split('\n')) {
    if (linha.startsWith('## ')) {
      fechar();
      titulo = linha.substring(3).trim();
      corpo = [];
    } else if (!linha.startsWith('# ')) {
      corpo.add(linha);
    }
  }
  fechar();
  return secoes;
}

/// Todas as seções de todos os guias, já com os dados da cidade.
Future<List<Secao>> carregarSecoes({
  Map<String, String>? blocos,
  Future<String> Function(String)? ler,
}) async {
  final indice = ler == null
      ? await carregarIndice()
      : await carregarIndice(ler: ler);
  final locais = blocos ?? await blocosDaCidadeEscolhida();
  return [
    for (final c in indice)
      ...dividirEmSecoes(
        c,
        aplicarLocais(
          ler == null
              ? await carregarCapitulo(c)
              : await carregarCapitulo(c, ler: ler),
          locais,
        ),
      ),
  ];
}

String? _cacheCidade;
List<Secao>? _cache;

/// Seções da cidade escolhida, guardadas até a cidade mudar.
Future<List<Secao>> secoesDaCidadeEscolhida() async {
  final cidade = await lerCidade();
  if (_cache == null || cidade != _cacheCidade) {
    _cache = await carregarSecoes();
    _cacheCidade = cidade;
  }
  return _cache!;
}
