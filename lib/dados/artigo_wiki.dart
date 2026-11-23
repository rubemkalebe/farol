import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Esquema dos links entre artigos depois da limpeza.
const esquemaWiki = 'wiki:';

/// Seções que não ajudam a ler no celular sem internet.
const _secoesFora = {
  'Referências',
  'Notas',
  'Notas e referências',
  'Ligações externas',
  'Bibliografia',
  'Ver também',
  'Leitura adicional',
  'Fontes',
};

/// Partes da página da Wikipédia que ficam de fora: caixas técnicas,
/// navegação, números de referência, imagens (os pacotes são sem imagem)
/// e estilos.
const _foraSeletores = [
  'style',
  'script',
  'link',
  'meta',
  '.infobox',
  '.navbox',
  '.vertical-navbox',
  '.hatnote',
  '.ambox',
  '.metadata',
  '.noprint',
  '.mw-editsection',
  '.mw-ref',
  'sup.reference',
  '.reflist',
  '.mw-references',
  '.references',
  'figure',
  'img',
  '.thumb',
  '.gallery',
  '.mw-empty-elt',
  '.catlinks',
  '.zim-footer',
  '.scribunto-error',
  'strong.error',
];

class ArtigoLimpo {
  const ArtigoLimpo(this.titulo, this.corpo);

  final String titulo;
  final String corpo;
}

/// Tira da página só o texto do artigo, pronto para mostrar.
ArtigoLimpo limparArtigo(String pagina, {String tituloPadrao = ''}) {
  final doc = html.parse(pagina);
  final titulo =
      doc.querySelector('#firstHeading')?.text.trim() ??
      doc.querySelector('title')?.text.trim() ??
      tituloPadrao;
  final raiz =
      doc.querySelector('#mw-content-text') ??
      doc.querySelector('.mw-parser-output') ??
      doc.body ??
      doc.documentElement!;

  for (final seletor in _foraSeletores) {
    for (final e in raiz.querySelectorAll(seletor).toList()) {
      e.remove();
    }
  }

  for (final h2 in raiz.querySelectorAll('h2').toList()) {
    if (!_secoesFora.contains(h2.text.trim())) continue;
    final secao = _subirAte(h2, 'section');
    if (secao != null) {
      secao.remove();
    } else {
      // Sem <section>: tira o título e tudo até o próximo título.
      var irmao = h2.nextElementSibling;
      while (irmao != null && irmao.localName != 'h2') {
        final proximo = irmao.nextElementSibling;
        irmao.remove();
        irmao = proximo;
      }
      h2.remove();
    }
  }

  for (final a in raiz.querySelectorAll('a').toList()) {
    final href = a.attributes['href'] ?? '';
    final interno =
        href.isNotEmpty &&
        !href.startsWith('#') &&
        !href.startsWith('//') &&
        !href.contains(':') &&
        !RegExp(r'(\.(epub|pdf)|_cover\.\d+\.html)$').hasMatch(href);
    if (interno) {
      a.attributes
        ..clear()
        ..['href'] = '$esquemaWiki${_caminho(href)}';
    } else {
      // Link externo ou âncora: vira texto comum.
      a.replaceWith(Text(a.text));
    }
  }

  return ArtigoLimpo(titulo, raiz.innerHtml.trim());
}

/// "./Febre#Sintomas" → "Febre". "Doen%C3%A7a" → "Doença".
String _caminho(String href) {
  var c = href;
  final ancora = c.indexOf('#');
  if (ancora >= 0) c = c.substring(0, ancora);
  if (c.startsWith('./')) c = c.substring(2);
  try {
    return Uri.decodeComponent(c);
  } catch (_) {
    return c;
  }
}

/// Divide um texto muito longo (um livro inteiro) em partes de uns
/// [tamanho] caracteres, sem cortar parágrafo, para o celular não travar.
List<String> dividirEmPartes(String corpo, {int tamanho = 60000}) {
  if (corpo.length <= tamanho * 1.3) return [corpo];
  var nos = html.parseFragment(corpo).nodes.toList();
  while (nos.length == 1 &&
      nos.first is Element &&
      nos.first.nodes.isNotEmpty) {
    nos = nos.first.nodes.toList();
  }
  final partes = <String>[];
  final atual = StringBuffer();
  for (final n in nos) {
    final pedaco = n is Element ? n.outerHtml : (n.text ?? '');
    if (atual.length > 0 && atual.length + pedaco.length > tamanho) {
      partes.add(atual.toString());
      atual.clear();
    }
    atual.write(pedaco);
  }
  if (atual.isNotEmpty) partes.add(atual.toString());
  return partes;
}

/// Caminho de um link relativo ao artigo atual, como o navegador faria:
/// em "Curso/Aula_1", "../Outro" vira "Outro" e "Aula_2" vira "Curso/Aula_2".
String resolverCaminho(String atual, String link) {
  final partes = atual.split('/')..removeLast();
  for (final p in link.split('/')) {
    if (p == '..') {
      if (partes.isNotEmpty) partes.removeLast();
    } else if (p != '.' && p.isNotEmpty) {
      partes.add(p);
    }
  }
  return partes.join('/');
}

Element? _subirAte(Element e, String tag) {
  Element? atual = e.parent;
  while (atual != null) {
    if (atual.localName == tag) return atual;
    atual = atual.parent;
  }
  return null;
}
