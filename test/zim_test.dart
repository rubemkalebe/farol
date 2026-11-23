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
    expect(r.map((l) => l.length), [2, 2, 2, 1, 1]);
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
