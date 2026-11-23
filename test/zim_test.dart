import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:farol/dados/artigo_wiki.dart';
import 'package:farol/dados/wikipedia.dart';
import 'package:farol/dados/zim.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta um ZIM pequeno, sem compressão, no formato da especificação.
Uint8List zimDeTeste(
  List<(String ns, String url, String titulo, String html)> artigos, {
  Map<String, String> redirecionamentos = const {}, // url → url de destino
}) {
  final entradas = [
    for (final a in artigos) (a.$1, a.$2, a.$3, a.$4, null as String?),
    for (final r in redirecionamentos.entries) ('C', r.key, r.key, '', r.value),
  ]..sort((a, b) => '${a.$1}/${a.$2}'.compareTo('${b.$1}/${b.$2}'));
  final indice = {for (final (i, e) in entradas.indexed) '${e.$1}/${e.$2}': i};
  final conteudos = [
    for (final e in entradas)
      if (e.$5 == null) utf8.encode(e.$4),
  ];

  final dirents = BytesBuilder();
  final posDirent = <int>[];
  var blob = 0;
  for (final e in entradas) {
    posDirent.add(dirents.length);
    final b = ByteData(e.$5 == null ? 16 : 12);
    b.setUint16(0, e.$5 == null ? 0 : 0xffff, Endian.little);
    b.setUint8(3, e.$1.codeUnitAt(0));
    if (e.$5 == null) {
      b.setUint32(8, 0, Endian.little);
      b.setUint32(12, blob++, Endian.little);
    } else {
      b.setUint32(8, indice['C/${e.$5}']!, Endian.little);
    }
    dirents
      ..add(b.buffer.asUint8List())
      ..add(utf8.encode(e.$2))
      ..addByte(0)
      ..add(utf8.encode(e.$3))
      ..addByte(0);
  }

  final cluster = BytesBuilder()..addByte(1); // sem compressão
  final offsets = ByteData(4 * (conteudos.length + 1));
  var off = offsets.lengthInBytes;
  for (var i = 0; i <= conteudos.length; i++) {
    offsets.setUint32(4 * i, off, Endian.little);
    if (i < conteudos.length) off += conteudos[i].length;
  }
  cluster.add(offsets.buffer.asUint8List());
  for (final c in conteudos) {
    cluster.add(c);
  }

  final mimes = utf8.encode('text/html\u0000\u0000');
  final n = entradas.length;
  const mimePos = 80;
  final urlPtrPos = mimePos + mimes.length;
  final titlePtrPos = urlPtrPos + 8 * n;
  final direntPos = titlePtrPos + 4 * n;
  final clusterPtrPos = direntPos + dirents.length;
  final clusterPos = clusterPtrPos + 8;
  final checksumPos = clusterPos + cluster.length;

  final h = ByteData(80)
    ..setUint32(0, 72173914, Endian.little)
    ..setUint16(4, 6, Endian.little)
    ..setUint16(6, 1, Endian.little)
    ..setUint32(24, n, Endian.little)
    ..setUint32(28, 1, Endian.little)
    ..setUint64(32, urlPtrPos, Endian.little)
    ..setUint64(40, titlePtrPos, Endian.little)
    ..setUint64(48, clusterPtrPos, Endian.little)
    ..setUint64(56, mimePos, Endian.little)
    ..setUint32(64, 0, Endian.little)
    ..setUint32(68, 0xffffffff, Endian.little)
    ..setUint64(72, checksumPos, Endian.little);

  final ptrs = ByteData(8 * n);
  for (var i = 0; i < n; i++) {
    ptrs.setUint64(8 * i, direntPos + posDirent[i], Endian.little);
  }
  final porTitulo = List.generate(n, (i) => i)
    ..sort((a, b) => entradas[a].$3.compareTo(entradas[b].$3));
  final titulos = ByteData(4 * n);
  for (var i = 0; i < n; i++) {
    titulos.setUint32(4 * i, porTitulo[i], Endian.little);
  }
  final cptr = ByteData(8)..setUint64(0, clusterPos, Endian.little);

  return (BytesBuilder()
        ..add(h.buffer.asUint8List())
        ..add(mimes)
        ..add(ptrs.buffer.asUint8List())
        ..add(titulos.buffer.asUint8List())
        ..add(dirents.toBytes())
        ..add(cptr.buffer.asUint8List())
        ..add(cluster.toBytes())
        ..add(Uint8List(16)))
      .toBytes();
}

void main() {
  late Directory pasta;
  late Zim zim;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('farol_zim');
    final f = File('${pasta.path}/t.zim')
      ..writeAsBytesSync(
        zimDeTeste(
          [
            ('C', 'Dengue', 'Dengue', '<p>Doença transmitida pelo Aedes.</p>'),
            (
              'C',
              'Dengue_hemorrágica',
              'Dengue hemorrágica',
              '<p>Forma grave.</p>',
            ),
            ('C', 'Febre', 'Febre', '<p>Temperatura alta.</p>'),
            ('C', '_mw_/estilo.css', '_mw_/estilo.css', 'body{}'),
            ('C', 'água', 'água', '<p>Líquido.</p>'),
            (
              'C',
              'Dom_Casmurro.55752.html',
              'Dom Casmurro.55752.html',
              '<p>Livro.</p>',
            ),
            (
              'C',
              'Dom_Casmurro_cover.55752.html',
              'Dom Casmurro_cover.55752.html',
              '<img>',
            ),
          ],
          redirecionamentos: {'Febre_alta': 'Febre'},
        ),
      );
    zim = await Zim.abrir(f.path);
  });

  tearDown(() async {
    await zim.fechar();
    await pasta.delete(recursive: true);
  });

  test(
    'busca pelo começo do título, sem ligar para a primeira maiúscula',
    () async {
      final r = await zim.buscarTitulo('deng');
      expect(r.map((e) => e.titulo), ['Dengue', 'Dengue hemorrágica']);
      // "Febre_alta" redireciona para "Febre": aparece uma vez só.
      expect((await zim.buscarTitulo('feb')).map((e) => e.titulo), ['Febre']);
      expect(await zim.buscarTitulo('xyz'), isEmpty);
      expect(await zim.buscarTitulo('  '), isEmpty);
    },
  );

  test('acha minúsculas, cada palavra maiúscula e esconde capas', () async {
    expect((await zim.buscarTitulo('água')).map((e) => e.titulo), ['água']);
    final livro = await zim.buscarTitulo('dom casmurro');
    expect(livro.map((e) => e.tituloLegivel), ['Dom Casmurro']);
    expect(
      (await zim.todosTitulos()).map((e) => e.url),
      isNot(contains('Dom_Casmurro_cover.55752.html')),
    );
  });

  test('links relativos e livro longo em partes', () {
    expect(resolverCaminho('Curso/Aula_1', '../Outro'), 'Outro');
    expect(resolverCaminho('Curso/Aula_1', 'Aula_2'), 'Curso/Aula_2');
    expect(resolverCaminho('Febre', 'Dengue'), 'Dengue');
    final livro =
        '<div>${List.filled(300, '<p>${'x' * 1000}</p>').join()}</div>';
    final partes = dividirEmPartes(livro, tamanho: 60000);
    expect(partes.length, greaterThan(4));
    expect(partes.every((p) => p.startsWith('<p>')), isTrue);
    expect(partes.join().length, 300 * '<p></p>'.length + 300000);
    expect(dividirEmPartes('<p>curto</p>'), ['<p>curto</p>']);
  });

  test('abre o conteúdo e segue redirecionamento', () async {
    final dengue = (await zim.buscarTitulo('Dengue', limite: 1)).single;
    expect(utf8.decode(await zim.conteudo(dengue)), contains('Aedes'));
    final redir = await zim.artigo('Febre_alta');
    expect(redir!.ehRedirecionamento, isTrue);
    expect(utf8.decode(await zim.conteudo(redir)), contains('Temperatura'));
  });

  test('várias buscas ao mesmo tempo não brigam pelo arquivo', () async {
    final r = await Future.wait([
      for (final t in ['D', 'De', 'Den', 'F', 'Fe']) zim.buscarTitulo(t),
    ]);
    expect(r.map((l) => l.length), [3, 2, 2, 1, 1]);
  });

  test('recusa arquivo que não é ZIM', () async {
    final f = File('${pasta.path}/x.zim')
      ..writeAsBytesSync(List.filled(100, 0));
    expect(() => Zim.abrir(f.path), throwsFormatException);
  });

  test('acha a versão mais nova na lista do servidor', () {
    const lista =
        '<a href="wikipedia_pt_medicine_nopic_2026-05.zim">x</a>'
        '<a href="wikipedia_pt_medicine_nopic_2026-10.zim">x</a>'
        '<a href="wikipedia_pt_medicine_maxi_2026-11.zim">x</a>';
    expect(versaoMaisNova(lista, 'wikipedia_pt_medicine_nopic'), '2026-10');
    expect(versaoMaisNova(lista, 'wikipedia_pt_top_mini'), isNull);
  });

  test('limpa o artigo: sem caixa técnica, referências e links externos', () {
    const pagina = '''
<html><head><title>Dengue — Wikipédia</title><style>x{}</style></head><body>
<h1 id="firstHeading">Dengue</h1>
<div id="mw-content-text">
<table class="infobox"><tr><td>CID A97</td></tr></table>
<section><p>Causada por <a href="V%C3%ADrus_da_dengue">vírus</a>
<sup class="mw-ref reference"><a href="#cite_note-1">[1]</a></sup>
e vista em <a href="https://who.int">OMS</a>.</p><figure><img src="a.png"></figure></section>
<section><div class="mw-heading"><h2 id="Tratamento">Tratamento</h2></div><p>Hidratação.</p></section>
<section><div class="mw-heading"><h2 id="Referências">Referências</h2></div><ol class="references"><li>x</li></ol></section>
</div></body></html>''';
    final a = limparArtigo(pagina);
    expect(a.titulo, 'Dengue');
    expect(a.corpo, contains('href="wiki:Vírus_da_dengue"'));
    expect(a.corpo, contains('OMS'));
    expect(a.corpo, isNot(contains('who.int')));
    expect(a.corpo, isNot(contains('CID A97')));
    expect(a.corpo, isNot(contains('[1]')));
    expect(a.corpo, isNot(contains('<img')));
    expect(a.corpo, contains('Hidratação'));
    expect(a.corpo, isNot(contains('Referências')));
  });

  test('guia do iFixit: passos com fotos, avisos, sem site em volta', () {
    const pagina = '''
<html><head><title>Troca da bateria</title></head><body><div id="mainBody">
<!-- MAIN BODY -->
<h1 class="guide-intro-title">Troca da bateria</h1>
<div class="stats-container">12 visualizações</div>
<div id="tools-and-parts"><a href="../../home/unavailable_offline?url=/products/x"><img src="../../images/a.standard" width="80"></a> Chave P2</div>
<li class="step"><h2>Passo 1</h2>
<div class="step-main-media"><img src="../../images/foto1.standard" width="575"></div>
<div class="step-thumbnails"><img src="../../images/foto1.standard" width="110" alt="T2yIKTYtWTOpeGir"><img src="../../images/foto2.standard" width="110"></div>
<ul><li class="level-0 bullet-line-icon-caution"><div class="bullet"></div><p>Descarregue a bateria.</p></li>
<li class="level-0"><p>Tire os <a href="../../Device/Parafuso">parafusos</a>.</p></li></ul>
<div class="js-comments">Comentário de alguém</div></li>
<div class="guide-comments-container"><h3>29 comentários</h3></div>
<footer>© iFixit</footer>
</div></body></html>''';
    final a = limparArtigo(pagina, imagens: true);
    expect(a.titulo, 'Troca da bateria');
    expect(a.corpo, isNot(contains('MAIN BODY')));
    expect(a.corpo, isNot(contains('<h1')));
    expect(a.corpo, isNot(contains('visualizações')));
    expect(a.corpo, isNot(contains('comentários')));
    expect(a.corpo, isNot(contains('Comentário de alguém')));
    expect(a.corpo, isNot(contains('© iFixit')));
    expect(a.corpo, contains('Chave P2'));
    expect(a.corpo, isNot(contains('unavailable_offline')));
    expect(a.corpo, contains('<strong>Cuidado: </strong>Descarregue'));
    expect(a.corpo, contains('href="wiki:../../Device/Parafuso"'));
    // A foto grande repete a primeira miniatura: cada foto aparece uma vez.
    expect('<img'.allMatches(a.corpo).length, 2);
    expect(a.corpo, contains('$esquemaImagem../../images/foto2.standard'));
    expect(a.corpo, isNot(contains('T2yIKTYtWTOpeGir')));
  });

  test('site arquivado: só o artigo, sem menus e sem imagem de fundo', () {
    const pagina = '''
<html><head><title>Chuveiro neblina | LOW←TECH MAGAZINE</title></head><body>
<header class="site-header"><nav id="menu">Sobre · Doe</nav></header>
<main class="article"><article>
<header class="entry-header"><h1>Chuveiro neblina</h1><nav id="languages">English</nav></header>
<section id="content"><p>Usa pouca água.</p>
<div class="featured" style="background-image: url(&quot;foto.png&quot;);">x</div>
<figure><img src="images/dithers/kit.png" alt="Kit"><div class="imgindicator">View original image</div></figure>
<div class="post-footer"><a href="https://paypal.me/x">Doe</a></div></section>
<section id="comments">Comentário</section><section id="related">Leia também</section>
</article></main>
<footer class="site-footer">© Autor</footer></body></html>''';
    final a = limparArtigo(pagina, imagens: true);
    expect(a.titulo, 'Chuveiro neblina');
    expect(a.corpo, contains('Usa pouca água.'));
    for (final fora in [
      'Sobre',
      'English',
      '<h1',
      'background-image',
      'View original',
      'Doe',
      'Comentário',
      'Leia também',
      '© Autor',
    ]) {
      expect(a.corpo, isNot(contains(fora)), reason: fora);
    }
    expect(a.corpo, contains('${esquemaImagem}images/dithers/kit.png'));
  });

  test('pacote com imagens: mantém fotos, tira ícones, SVG e o link', () {
    const pagina = '''
<html><body><div id="mw-content-text">
<figure><a href="./File:Filtro.jpg"><img src="./_assets_/ab/Filtro%20de%20areia.JPG" width="300" alt="Filtro"></a><figcaption>Filtro de areia</figcaption></figure>
<p>Texto <img src="./_assets_/cd/icone.png" width="16"> aqui.</p>
<figure><img src="../_assets_/ef/esquema.svg"></figure>
<p><img src="https://exemplo.org/x.jpg"></p>
</div></body></html>''';
    final semImagem = limparArtigo(pagina);
    expect(semImagem.corpo, isNot(contains('<img')));

    final a = limparArtigo(pagina, imagens: true);
    expect(
      a.corpo,
      contains('src="${esquemaImagem}_assets_/ab/Filtro de areia.JPG"'),
    );
    expect(a.corpo, contains('Filtro de areia</figcaption>'));
    expect(a.corpo, isNot(contains('File:')));
    expect(a.corpo, isNot(contains('icone.png')));
    expect(a.corpo, isNot(contains('esquema.svg')));
    expect(a.corpo, isNot(contains('exemplo.org')));
    expect('<img'.allMatches(a.corpo).length, 1);
  });

  // Com um arquivo de verdade: FAROL_ZIM=/caminho/medicina.zim flutter test
  final real = Platform.environment['FAROL_ZIM'];
  test(
    'arquivo real do Kiwix: acha e limpa "Dengue"',
    () async {
      final z = await Zim.abrir(real!);
      final r = await z.buscarTitulo('dengue', limite: 3);
      expect(r.first.titulo, 'Dengue');
      final a = limparArtigo(utf8.decode(await z.conteudo(r.first)));
      expect(a.corpo, contains('Aedes'));
      expect(a.corpo, isNot(contains('<script')));
      final link = RegExp('href="wiki:([^"]+)"').firstMatch(a.corpo)![1]!;
      expect(await z.artigo(link), isNotNull, reason: link);
      await z.fechar();
    },
    skip: real == null
        ? 'defina FAROL_ZIM para testar com um arquivo real'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
