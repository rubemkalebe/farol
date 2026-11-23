import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Leitor de arquivos ZIM (o formato do Kiwix), em Dart puro.
/// Especificação: https://wiki.openzim.org/wiki/ZIM_file_format
///
/// Lê só o necessário: a busca é pelo título (binária na lista de títulos)
/// e o artigo é tirado do bloco ("cluster") comprimido onde ele está.
class Zim {
  Zim._(this._f, this._h);

  final RandomAccessFile _f;
  final _Cabecalho _h;
  final _clusters = <int, Future<(Uint8List, bool)>>{};
  Future<List<int>>? _titulos;

  // Um RandomAccessFile não aceita duas leituras ao mesmo tempo: a busca
  // dispara várias enquanto a pessoa digita, então as leituras entram numa
  // fila.
  Future<void> _fila = Future.value();

  int get totalEntradas => _h.entryCount;

  static Future<Zim> abrir(String caminho) async {
    final f = await File(caminho).open();
    try {
      await f.setPosition(0);
      final b = ByteData.sublistView(await f.read(80));
      if (b.lengthInBytes < 80 || b.getUint32(0, Endian.little) != 72173914) {
        throw const FormatException('não é um arquivo ZIM');
      }
      return Zim._(
        f,
        _Cabecalho(
          entryCount: b.getUint32(24, Endian.little),
          clusterCount: b.getUint32(28, Endian.little),
          urlPtrPos: b.getUint64(32, Endian.little),
          titlePtrPos: b.getUint64(40, Endian.little),
          clusterPtrPos: b.getUint64(48, Endian.little),
          mainPage: b.getUint32(64, Endian.little),
          checksumPos: b.getUint64(72, Endian.little),
        ),
      );
    } catch (_) {
      await f.close();
      rethrow;
    }
  }

  Future<Uint8List> _ler(int pos, int n) {
    final pronto = Completer<Uint8List>();
    _fila = _fila.then((_) async {
      try {
        await _f.setPosition(pos);
        pronto.complete(await _f.read(n));
      } catch (e, s) {
        pronto.completeError(e, s);
      }
    });
    return pronto.future;
  }

  Future<int> _u64(int pos) async =>
      ByteData.sublistView(await _ler(pos, 8)).getUint64(0, Endian.little);

  Future<EntradaZim> entrada(int indice) async {
    final pos = await _u64(_h.urlPtrPos + 8 * indice);
    // Uma entrada tem 16 bytes fixos e dois textos; 1 KB cobre quase todas.
    var d = await _ler(pos, 1024);
    if (_textosIncompletos(d)) d = await _ler(pos, 16384);
    return EntradaZim._de(indice, d);
  }

  static bool _textosIncompletos(Uint8List d) {
    final redir = d.length > 1 && d[0] == 0xff && d[1] == 0xff;
    final p = redir ? 12 : 16;
    final a = d.indexOf(0, p);
    return a < 0 || d.indexOf(0, a + 1) < 0;
  }

  /// Busca exata pela URL dentro de um namespace ("C" para artigos nos
  /// arquivos novos, "A" nos antigos).
  Future<EntradaZim?> porUrl(String namespace, String url) async {
    final alvo = '$namespace/$url';
    var lo = 0, hi = _h.entryCount - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final e = await entrada(mid);
      final c = e.chave.compareTo(alvo);
      if (c == 0) return e;
      if (c < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return null;
  }

  /// Artigo pelo caminho de um link do próprio arquivo, nos dois esquemas
  /// de namespace.
  Future<EntradaZim?> artigo(String url) async =>
      await porUrl('C', url) ?? await porUrl('A', url);

  /// Índices em ordem de título. Nos arquivos novos, a lista
  /// X/listing/titleOrdered/v1 tem só os artigos; nos antigos, vale a lista
  /// de títulos do cabeçalho (com tudo, filtrada na busca).
  Future<List<int>> _ordemTitulos() => _titulos ??= () async {
    final lista = await porUrl('X', 'listing/titleOrdered/v1');
    final bytes = lista != null
        ? await conteudo(lista)
        : await _ler(_h.titlePtrPos, 4 * _h.entryCount);
    final b = ByteData.sublistView(bytes);
    return [
      for (var i = 0; i + 4 <= bytes.length; i += 4)
        b.getUint32(i, Endian.little),
    ];
  }();

  /// Artigos cujo título começa com [prefixo]. A ordem dos títulos no
  /// arquivo diferencia maiúsculas, então a busca tenta o jeito digitado,
  /// a primeira letra maiúscula, Cada Palavra Maiúscula e tudo minúsculo
  /// (Wikcionário usa minúsculas; livros usam maiúscula em cada palavra).
  Future<List<EntradaZim>> buscarTitulo(
    String prefixo, {
    int limite = 10,
  }) async {
    final termo = prefixo.trim();
    if (termo.isEmpty) return const [];
    String maiuscula(String p) =>
        p.isEmpty ? p : p[0].toUpperCase() + p.substring(1);
    final variantes = <String>{
      maiuscula(termo),
      termo,
      termo.split(' ').map(maiuscula).join(' '),
      termo.toLowerCase(),
    };
    final achados = <EntradaZim>[];
    // Títulos diferentes que levam ao mesmo artigo ("Dengue (doença)" →
    // "Dengue") aparecem uma vez só.
    final destinos = <int>{};
    for (final v in variantes) {
      for (final e in await _buscarExato(v, limite)) {
        final destino = e.ehRedirecionamento
            ? (await resolver(e)).indice
            : e.indice;
        if (destinos.add(destino)) achados.add(e);
      }
    }
    achados.sort(
      (a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()),
    );
    return achados.take(limite).toList();
  }

  Future<List<EntradaZim>> _buscarExato(String alvo, int limite) async {
    final ordem = await _ordemTitulos();
    var lo = 0, hi = ordem.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final e = await entrada(ordem[mid]);
      if (e.titulo.compareTo(alvo) < 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final achados = <EntradaZim>[];
    for (var i = lo; i < ordem.length && achados.length < limite; i++) {
      final e = await entrada(ordem[i]);
      if (!e.titulo.startsWith(alvo)) break;
      if (e.ehArtigo && e.ehLegivel) achados.add(e);
    }
    return achados;
  }

  /// Todas as páginas legíveis em ordem de título (para listar os livros).
  Future<List<EntradaZim>> todosTitulos() async {
    final lista = <EntradaZim>[];
    for (final i in await _ordemTitulos()) {
      final e = await entrada(i);
      if (e.ehArtigo && e.ehLegivel && !e.ehRedirecionamento) lista.add(e);
    }
    return lista;
  }

  Future<EntradaZim> resolver(EntradaZim e) async {
    var atual = e;
    for (var i = 0; i < 10 && atual.ehRedirecionamento; i++) {
      atual = await entrada(atual.redireciona!);
    }
    return atual;
  }

  Future<EntradaZim> paginaInicial() async =>
      resolver(await entrada(_h.mainPage));

  Future<Uint8List> conteudo(EntradaZim e) async {
    final real = await resolver(e);
    final (dados, estendido) = await _cluster(real.cluster!);
    final b = ByteData.sublistView(dados);
    int off(int i) => estendido
        ? b.getUint64(i * 8, Endian.little)
        : b.getUint32(i * 4, Endian.little);
    return Uint8List.sublistView(dados, off(real.blob!), off(real.blob! + 1));
  }

  Future<(Uint8List, bool)> _cluster(int n) {
    if (_clusters.length > 6) _clusters.clear();
    return _clusters[n] ??= () async {
      final ini = await _u64(_h.clusterPtrPos + 8 * n);
      final fim = n + 1 < _h.clusterCount
          ? await _u64(_h.clusterPtrPos + 8 * (n + 1))
          : _h.checksumPos;
      final bruto = await _ler(ini, fim - ini);
      final info = bruto[0];
      final compressao = info & 0x0f;
      final dados = Uint8List.sublistView(bruto, 1);
      // Descomprimir um bloco leva centenas de milissegundos: fora da tela.
      final claro = compressao <= 1
          ? dados
          : await _emOutroIsolate(compressao, dados);
      return (claro, info & 0x10 != 0);
    }();
  }

  Future<void> fechar() async {
    await _fila;
    await _f.close();
  }
}

// Função solta: o fechamento só leva os dados, não o leitor (que tem o
// arquivo aberto e não pode ir para outro isolate).
Future<Uint8List> _emOutroIsolate(int compressao, Uint8List dados) =>
    Isolate.run(() => descomprimirCluster(compressao, dados));

Uint8List descomprimirCluster(int compressao, Uint8List dados) =>
    switch (compressao) {
      4 => Uint8List.fromList(XZDecoder().decodeBytes(dados)),
      5 => Uint8List.fromList(ZstdDecoder().decodeBytes(dados)),
      _ => throw FormatException('compressão $compressao não suportada'),
    };

class EntradaZim {
  EntradaZim._({
    required this.indice,
    required this.mime,
    required this.namespace,
    required this.url,
    required this.titulo,
    this.cluster,
    this.blob,
    this.redireciona,
  });

  factory EntradaZim._de(int indice, Uint8List d) {
    final b = ByteData.sublistView(d);
    final mime = b.getUint16(0, Endian.little);
    final redir = mime == 0xffff;
    var p = redir ? 12 : 16;
    String texto() {
      final fim = d.indexOf(0, p);
      final s = utf8.decode(d.sublist(p, fim), allowMalformed: true);
      p = fim + 1;
      return s;
    }

    final url = texto();
    final titulo = texto();
    return EntradaZim._(
      indice: indice,
      mime: mime,
      namespace: String.fromCharCode(d[3]),
      url: url,
      titulo: titulo.isEmpty ? url : titulo,
      cluster: redir ? null : b.getUint32(8, Endian.little),
      blob: redir ? null : b.getUint32(12, Endian.little),
      redireciona: redir ? b.getUint32(8, Endian.little) : null,
    );
  }

  final int indice;
  final int mime;
  final String namespace;
  final String url;
  final String titulo;
  final int? cluster;
  final int? blob;
  final int? redireciona;

  bool get ehRedirecionamento => mime == 0xffff;
  bool get ehArtigo => namespace == 'C' || namespace == 'A';

  /// Fora da busca: capas e arquivos para baixar dos livros (Gutenberg).
  bool get ehLegivel =>
      !_capaOuArquivo.hasMatch(url) && !url.startsWith('_') && url != 'favicon';

  /// Título para mostrar: sem o número e o ".html" dos livros
  /// ("Dom Casmurro.55752.html" → "Dom Casmurro").
  String get tituloLegivel => titulo.replaceFirst(_sufixoLivro, '');
  String get chave => '$namespace/$url';
}

final _capaOuArquivo = RegExp(
  r'(_cover\.\d+\.html|\.(epub|pdf|css|js|png|jpe?g|svg|webp|ico))$',
);
final _sufixoLivro = RegExp(r'\.\d+\.html$');

class _Cabecalho {
  const _Cabecalho({
    required this.entryCount,
    required this.clusterCount,
    required this.urlPtrPos,
    required this.titlePtrPos,
    required this.clusterPtrPos,
    required this.mainPage,
    required this.checksumPos,
  });

  final int entryCount, clusterCount;
  final int urlPtrPos, titlePtrPos, clusterPtrPos, mainPage, checksumPos;
}
