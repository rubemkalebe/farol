import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Nome do site no fim do título da página ("Título | LOW←TECH MAGAZINE").
final sufixoSite = RegExp(r'\s+\|\s+LOW←TECH MAGAZINE$');

/// Esquema dos links entre artigos depois da limpeza.
const esquemaWiki = 'wiki:';

/// Esquema das imagens que ficam (pacotes com imagem): o caminho dentro do
/// arquivo ZIM, relativo ao artigo.
const esquemaImagem = 'zimimg:';

/// Desenhos vetoriais (SVG, fórmulas) o leitor não mostra. As fotos do
/// iFixit vêm sem extensão ("X.standard"), então o resto passa.
final _imagemVetorial = RegExp(r'\.svgz?$', caseSensitive: false);

/// Partes do site do iFixit fora do guia: comentários, autor, rodapé,
/// botões, ícones e fotos dos produtos da loja.
const _foraIfixit = [
  'footer',
  'svg',
  '.actionbar-portal',
  '#author-container',
  '.guide-author',
  '.stats-container',
  '.statuses',
  '.js-comments',
  '.comments-container',
  '.comments-button-container',
  '.step-comments',
  '.guide-comments-container',
  '.lang',
  '#mobile-wiki-toc',
  '#mobile-skeleton-toc',
  '.react-component',
  '.bullet',
  '.clearer',
  'img[src*="cart-products"]',
  '#tools-and-parts img',
  '.deviceToolsContainer img',
  'h1.guide-intro-title',
  'h1.banner-title',
];

/// Partes que só fazem sentido com imagem: saem dos pacotes sem imagem.
const _soComImagem = {'figure', 'img', '.thumb', '.gallery'};

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
  '#toc',
  '.template-databox',
  '.toc',
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

/// Tira da página só o texto do artigo, pronto para mostrar. Com
/// [imagens], as fotos e figuras ficam, apontando para dentro do arquivo.
ArtigoLimpo limparArtigo(
  String pagina, {
  String tituloPadrao = '',
  bool imagens = false,
}) {
  final doc = html.parse(pagina);
  final titulo =
      doc.querySelector('#firstHeading')?.text.trim() ??
      doc.querySelector('title')?.text.trim().replaceFirst(sufixoSite, '') ??
      tituloPadrao;
  final ifixit = doc.querySelector('#mainBody');
  if (ifixit != null) _prepararIfixit(ifixit);
  final raiz =
      doc.querySelector('#mw-content-text') ??
      ifixit ??
      _semMenus(
        doc.querySelector('main article') ?? doc.querySelector('main'),
      ) ??
      doc.querySelector('.mw-parser-output') ??
      doc.body ??
      doc.documentElement!;

  for (final seletor in _foraSeletores) {
    if (imagens && _soComImagem.contains(seletor)) continue;
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

  if (imagens) _prepararImagens(raiz);

  // Comentários do HTML ("<!-- MAIN BODY -->") não são texto do artigo.
  void semComentarios(Node n) {
    for (final f in n.nodes.toList()) {
      f is Comment ? f.remove() : semComentarios(f);
    }
  }

  semComentarios(raiz);

  // Imagem de fundo pelo estilo ("background-image: url(...)") o leitor
  // tentaria buscar na internet: sai o estilo inteiro.
  for (final e in raiz.querySelectorAll('[style*="url("]').toList()) {
    e.attributes.remove('style');
  }

  // Tabela com largura fixa ("width: 25%", flutuando à direita) fica
  // espremida na tela do celular: deixa ocupar a largura que precisar.
  for (final t in raiz.querySelectorAll('table, td, th').toList()) {
    t.attributes
      ..remove('style')
      ..remove('width');
  }

  for (final a in raiz.querySelectorAll('a').toList()) {
    final href = a.attributes['href'] ?? '';
    final interno =
        href.isNotEmpty &&
        !href.startsWith('#') &&
        !href.startsWith('//') &&
        !href.contains(':') &&
        !RegExp(r'(\.(epub|pdf)|_cover\.\d+\.html)$').hasMatch(href) &&
        // iFixit: loja e sites de fora viram página "indisponível".
        !href.contains('unavailable_offline') &&
        !href.contains('not_yet_available') &&
        !href.contains('external_content');
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

/// Sites comuns arquivados (Low-tech Magazine): o texto fica em
/// <main><article>; tira idiomas, comentários, relacionados e notas.
Element? _semMenus(Element? artigo) {
  if (artigo == null) return null;
  for (final e
      in artigo
          .querySelectorAll(
            'nav, svg, #languages, #comments, #related, #reference, '
            'header.entry-header h1, '
            '.comments, .imgindicator, .post-footer',
          )
          .toList()) {
    e.remove();
  }
  return artigo;
}

/// Guia do iFixit: tira o que é do site e deixa cada passo com as fotos
/// uma vez só (a foto grande repete a primeira miniatura) e os avisos
/// marcados.
void _prepararIfixit(Element raiz) {
  for (final seletor in _foraIfixit) {
    for (final e in raiz.querySelectorAll(seletor).toList()) {
      e.remove();
    }
  }
  for (final passo in raiz.querySelectorAll('.step').toList()) {
    if (passo.querySelector('.step-thumbnails img') != null) {
      for (final e in passo.querySelectorAll('.step-main-media').toList()) {
        e.remove();
      }
    }
  }
  for (final (classe, aviso) in [
    ('bullet-line-icon-caution', 'Cuidado: '),
    ('bullet-line-icon-note', 'Obs.: '),
  ]) {
    for (final li in raiz.querySelectorAll('li.$classe').toList()) {
      final p = li.querySelector('p') ?? li;
      p.nodes.insert(0, Element.tag('strong')..text = aviso);
    }
  }
}

/// Deixa só as imagens que o leitor mostra, com o caminho no arquivo, e
/// tira o link em volta delas (levaria à página do arquivo da imagem).
void _prepararImagens(Element raiz) {
  for (final img in raiz.querySelectorAll('img').toList()) {
    final src = img.attributes['src'] ?? '';
    final largura = int.tryParse(img.attributes['width'] ?? '') ?? 0;
    final interna =
        src.isNotEmpty && !src.contains(':') && !src.startsWith('//');
    // Ícones e bandeirinhas (menos de 40 px) só poluem a leitura.
    if (!interna ||
        _imagemVetorial.hasMatch(src) ||
        (largura > 0 && largura < 40)) {
      img.remove();
      continue;
    }
    var alt = img.attributes['alt'] ?? '';
    // O iFixit põe o código da foto no alt: não serve de descrição.
    if (RegExp(r'^[A-Za-z0-9]{16}$').hasMatch(alt)) alt = '';
    img.attributes
      ..clear()
      ..['src'] = '$esquemaImagem${_caminho(src)}'
      ..['alt'] = alt;
    final link = img.parent;
    if (link != null && link.localName == 'a') {
      if (link.text.trim().isEmpty) {
        link.replaceWith(img);
      } else {
        // Miniatura de uma lista de links (categorias, outros guias): fica
        // só o nome, senão a lista vira uma pilha de fotos grandes.
        img.remove();
      }
    }
  }
  // Figuras que ficaram sem imagem (SVG, ícones) saem inteiras.
  for (final f in raiz.querySelectorAll('figure, .thumb, .gallery').toList()) {
    if (f.querySelector('img') == null) f.remove();
  }
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
  // Pedaços em ordem: um bloco maior que uma parte (o guia inteiro dentro
  // de uma <div>, por exemplo) é aberto nos blocos de dentro.
  final pedacos = <String>[];
  void juntar(Node n) {
    if (n is Comment) return;
    if (n is Element) {
      final h = n.outerHtml;
      if (h.length > tamanho && n.children.isNotEmpty) {
        for (final f in n.nodes) {
          juntar(f);
        }
      } else {
        pedacos.add(h);
      }
    } else if ((n.text ?? '').trim().isNotEmpty) {
      pedacos.add(n.text!);
    }
  }

  for (final n in html.parseFragment(corpo).nodes) {
    juntar(n);
  }
  final partes = <String>[];
  final atual = StringBuffer();
  for (final pedaco in pedacos) {
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
