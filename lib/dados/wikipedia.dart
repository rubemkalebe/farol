import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'zim.dart';

/// Um recorte da Wikipédia em português, empacotado pelo Kiwix.
class PacoteWiki {
  const PacoteWiki({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.tamanho,
    required this.versao,
    this.sugerido = false,
  });

  /// Nome do arquivo no Kiwix, sem a data (ex.: wikipedia_pt_medicine_nopic).
  final String id;
  final String titulo;
  final String descricao;

  /// Tamanho aproximado, só para mostrar antes de baixar.
  final String tamanho;

  /// Versão conhecida, usada se a lista do servidor não abrir.
  final String versao;
  final bool sugerido;
}

const pacotesWiki = [
  PacoteWiki(
    id: 'wikipedia_pt_medicine_nopic',
    titulo: 'Medicina',
    descricao: 'Doenças, sintomas, remédios e primeiros socorros, sem imagens.',
    tamanho: '116 MB',
    versao: '2026-10',
    sugerido: true,
  ),
  PacoteWiki(
    id: 'wikipedia_pt_top_mini',
    titulo: 'Artigos principais (resumo)',
    descricao: 'Os artigos mais lidos, só com o começo de cada um.',
    tamanho: '146 MB',
    versao: '2026-10',
    sugerido: true,
  ),
  PacoteWiki(
    id: 'wikipedia_pt_top_nopic',
    titulo: 'Artigos principais (completos)',
    descricao: 'Os artigos mais lidos, inteiros, sem imagens.',
    tamanho: '1,0 GB',
    versao: '2026-10',
  ),
  PacoteWiki(
    id: 'wikipedia_pt_all_mini',
    titulo: 'Wikipédia inteira (resumo)',
    descricao: 'Todos os artigos, só com o começo de cada um.',
    tamanho: '1,6 GB',
    versao: '2026-05',
  ),
  PacoteWiki(
    id: 'wikipedia_pt_all_nopic',
    titulo: 'Wikipédia inteira (completa)',
    descricao:
        'Todos os artigos, inteiros, sem imagens. Precisa de bastante espaço.',
    tamanho: '6,6 GB',
    versao: '2026-05',
  ),
];

const servidorKiwix = 'https://download.kiwix.org/zim/wikipedia/';

/// Versão mais nova de cada pacote na lista do servidor (AAAA-MM).
@visibleForTesting
String? versaoMaisNova(String listagem, String id) {
  final datas = RegExp(
    '${RegExp.escape(id)}_(\\d{4}-\\d{2})\\.zim"',
  ).allMatches(listagem).map((m) => m[1]!).toList()..sort();
  return datas.isEmpty ? null : datas.last;
}

enum EstadoDownload { baixando, conferindo, erro }

class Download {
  Download(this.pacote);

  final PacoteWiki pacote;
  EstadoDownload estado = EstadoDownload.baixando;
  int recebido = 0;
  int? total;
  String? erro;
  bool _cancelado = false;
  HttpClient? _cliente;

  double? get progresso =>
      total == null || total == 0 ? null : recebido / total!;
}

/// Pacotes baixados, downloads em andamento e arquivos abertos.
class Wikipedia extends ChangeNotifier {
  Wikipedia._();

  static final instancia = Wikipedia._();

  Directory? _pasta;

  /// Endereço da pasta de arquivos do Kiwix (trocado nos testes).
  @visibleForTesting
  String servidor = servidorKiwix;
  final downloads = <String, Download>{};
  final _abertos = <String, Future<Zim>>{};

  /// Para testes: usa outra pasta no lugar da pasta de dados do app.
  @visibleForTesting
  void usarPasta(Directory d) {
    _pasta = d;
    _abertos.clear();
  }

  Future<Directory> pasta() async {
    if (_pasta != null) return _pasta!;
    final base = await getApplicationSupportDirectory();
    return _pasta = await Directory('${base.path}/wikipedia')
        .create(recursive: true);
  }

  Future<File> _arquivo(PacoteWiki p) async =>
      File('${(await pasta()).path}/${p.id}.zim');

  /// Pacotes já baixados e conferidos, na ordem da lista.
  Future<List<PacoteWiki>> instalados() async {
    try {
      return [
        for (final p in pacotesWiki)
          if (await (await _arquivo(p)).exists()) p,
      ];
    } catch (_) {
      // Sem pasta de dados (ex.: plataforma sem suporte): nada baixado.
      return const [];
    }
  }

  Future<Zim> abrir(PacoteWiki p) =>
      _abertos[p.id] ??= _arquivo(p).then((f) => Zim.abrir(f.path));

  /// Busca pelo título em todos os pacotes baixados, sem repetir título.
  Future<List<(PacoteWiki, EntradaZim)>> buscar(
    String termo, {
    int limite = 8,
  }) async {
    final achados = <(PacoteWiki, EntradaZim)>[];
    final vistos = <String>{};
    for (final p in await instalados()) {
      try {
        final zim = await abrir(p);
        for (final e in await zim.buscarTitulo(termo, limite: limite)) {
          if (vistos.add(e.titulo)) achados.add((p, e));
        }
      } catch (_) {
        // Arquivo estragado não derruba a busca dos guias.
      }
    }
    return achados.take(limite).toList();
  }

  Future<void> baixar(PacoteWiki p) async {
    if (downloads.containsKey(p.id)) return;
    final d = downloads[p.id] = Download(p);
    notifyListeners();
    final destino = await _arquivo(p);
    final parcial = File('${destino.path}.part');
    final cliente = d._cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final versao = await _versao(cliente, p);
      final url = Uri.parse('$servidor${p.id}_$versao.zim');
      final esperado = await _sha256(cliente, url);

      // Continua de onde parou, se já houver parte baixada.
      var ja = await parcial.exists() ? await parcial.length() : 0;
      final req = await cliente.getUrl(url);
      if (ja > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$ja-');
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        ja = 0; // O servidor ignorou o pedido de continuar.
      } else if (resp.statusCode != HttpStatus.partialContent) {
        throw HttpException('o servidor respondeu ${resp.statusCode}');
      }
      d.recebido = ja;
      d.total = resp.contentLength < 0 ? null : ja + resp.contentLength;
      final saida = parcial.openWrite(
        mode: ja > 0 ? FileMode.append : FileMode.write,
      );
      var ultimo = DateTime.now();
      try {
        await for (final pedaco in resp) {
          if (d._cancelado) break;
          saida.add(pedaco);
          d.recebido += pedaco.length;
          if (DateTime.now().difference(ultimo).inMilliseconds > 250) {
            ultimo = DateTime.now();
            notifyListeners();
          }
        }
      } finally {
        await saida.close();
      }
      if (d._cancelado) {
        downloads.remove(p.id);
        notifyListeners();
        return;
      }

      d.estado = EstadoDownload.conferindo;
      notifyListeners();
      if (esperado != null) {
        final caminho = parcial.path;
        final obtido = await Isolate.run(() => _hashArquivo(caminho));
        if (obtido != esperado) {
          await parcial.delete();
          throw const FormatException(
            'o arquivo chegou com defeito; tente de novo',
          );
        }
      }
      await parcial.rename(destino.path);
      downloads.remove(p.id);
      notifyListeners();
    } catch (e) {
      if (d._cancelado) {
        downloads.remove(p.id);
        notifyListeners();
        return;
      }
      d
        ..estado = EstadoDownload.erro
        ..erro = _mensagem(e);
      notifyListeners();
    } finally {
      cliente.close(force: true);
    }
  }

  /// Para o download; a parte baixada fica guardada para continuar depois.
  void cancelar(PacoteWiki p) {
    final d = downloads[p.id];
    if (d == null) return;
    if (d.estado == EstadoDownload.erro) {
      downloads.remove(p.id);
      notifyListeners();
      return;
    }
    d._cancelado = true;
    d._cliente?.close(force: true);
  }

  Future<void> apagar(PacoteWiki p) async {
    final zim = _abertos.remove(p.id);
    if (zim != null) await (await zim).fechar();
    final f = await _arquivo(p);
    if (await f.exists()) await f.delete();
    final parcial = File('${f.path}.part');
    if (await parcial.exists()) await parcial.delete();
    notifyListeners();
  }

  Future<String> _versao(HttpClient c, PacoteWiki p) async {
    try {
      final req = await c.getUrl(Uri.parse(servidor));
      final resp = await req.close();
      final texto = await resp.transform(utf8.decoder).join();
      return versaoMaisNova(texto, p.id) ?? p.versao;
    } catch (_) {
      return p.versao;
    }
  }

  Future<String?> _sha256(HttpClient c, Uri url) async {
    try {
      final req = await c.getUrl(Uri.parse('$url.sha256'));
      final resp = await req.close();
      if (resp.statusCode != HttpStatus.ok) return null;
      final texto = await resp.transform(utf8.decoder).join();
      return RegExp(r'^[0-9a-f]{64}').firstMatch(texto.trim())?[0];
    } catch (_) {
      return null;
    }
  }
}

Future<String> _hashArquivo(String caminho) async =>
    (await sha256.bind(File(caminho).openRead()).first).toString();

String _mensagem(Object e) {
  if (e is SocketException || e is HttpException || e is TimeoutException) {
    return 'Sem conexão com o servidor. Toque para continuar de onde parou.';
  }
  if (e is FileSystemException) {
    return 'Não deu para gravar. Confira se o celular tem espaço livre.';
  }
  if (e is FormatException) return 'Erro: ${e.message}.';
  return 'Erro: $e';
}
