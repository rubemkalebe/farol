import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

/// Manuais em PDF para recomeçar depois de um desastre longo: plantar,
/// criar animais, água, saneamento, saúde sem médico. O Farol não guarda
/// os arquivos: cada um é baixado direto do site de quem publicou.
class ManualPdf {
  const ManualPdf({
    required this.id,
    required this.tema,
    required this.titulo,
    required this.orgao,
    required this.descricao,
    required this.url,
    required this.pagina,
    required this.tamanho,
    required this.licenca,
    this.ano,
  });

  factory ManualPdf.deYaml(String tema, YamlMap m) => ManualPdf(
    id: m['id'] as String,
    tema: tema,
    titulo: m['titulo'] as String,
    orgao: m['orgao'] as String,
    descricao: m['descricao'] as String,
    url: m['url'] as String,
    pagina: m['pagina'] as String,
    tamanho: m['tamanho'] as String,
    licenca: m['licenca'] as String,
    ano: m['ano'] as int?,
  );

  final String id;
  final String tema;
  final String titulo;

  /// Quem publicou (Embrapa, Ministério da Saúde...).
  final String orgao;
  final String descricao;

  /// Endereço do PDF no site de quem publicou.
  final String url;

  /// Página do manual no site, para conferir a origem.
  final String pagina;

  /// Tamanho aproximado, só para mostrar antes de baixar.
  final String tamanho;

  /// Licença ou aviso de reprodução, como está no próprio manual.
  final String licenca;
  final int? ano;
}

/// Lê a lista de manuais, agrupada por tema, na ordem do arquivo.
List<(String, List<ManualPdf>)> lerEstante(String texto) {
  final yaml = loadYaml(texto) as YamlMap;
  return [
    for (final t in yaml['temas'] as YamlList)
      (
        (t as YamlMap)['tema'] as String,
        [
          for (final m in t['manuais'] as YamlList)
            ManualPdf.deYaml(t['tema'] as String, m as YamlMap),
        ],
      ),
  ];
}

Future<List<(String, List<ManualPdf>)>> carregarEstante() async =>
    lerEstante(await rootBundle.loadString('conteudo/estante.yaml'));

enum EstadoPdf { baixando, erro }

class DownloadPdf {
  DownloadPdf(this.manual);

  final ManualPdf manual;
  EstadoPdf estado = EstadoPdf.baixando;
  int recebido = 0;
  int? total;
  String? erro;
  bool _cancelado = false;
  HttpClient? _cliente;

  double? get progresso =>
      total == null || total == 0 ? null : recebido / total!;
}

/// Manuais baixados e downloads em andamento.
class Estante extends ChangeNotifier {
  Estante._();

  static final instancia = Estante._();

  Directory? _pasta;
  final downloads = <String, DownloadPdf>{};

  /// Para testes: usa outra pasta no lugar da pasta de dados do app.
  @visibleForTesting
  void usarPasta(Directory d) => _pasta = d;

  Future<Directory> pasta() async {
    if (_pasta != null) return _pasta!;
    final base = await getApplicationSupportDirectory();
    return _pasta = await Directory('${base.path}/manuais')
        .create(recursive: true);
  }

  Future<File> arquivo(ManualPdf m) async =>
      File('${(await pasta()).path}/${m.id}.pdf');

  /// Ids dos manuais já baixados.
  Future<Set<String>> baixados() async {
    try {
      final d = await pasta();
      return {
        for (final f in d.listSync().whereType<File>())
          if (f.path.endsWith('.pdf'))
            f.uri.pathSegments.last.replaceFirst(RegExp(r'\.pdf$'), ''),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<void> baixar(ManualPdf m) async {
    if (downloads.containsKey(m.id)) return;
    final d = downloads[m.id] = DownloadPdf(m);
    notifyListeners();
    final destino = await arquivo(m);
    final parcial = File('${destino.path}.part');
    final cliente = d._cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      // Continua de onde parou, se já houver parte baixada.
      var ja = await parcial.exists() ? await parcial.length() : 0;
      Future<HttpClientResponse> pedir() async {
        final req = await cliente.getUrl(Uri.parse(m.url));
        if (ja > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$ja-');
        return req.close();
      }

      var resp = await pedir();
      if (ja > 0 && resp.statusCode >= 400) {
        // Alguns sites (Funasa) recusam continuar de onde parou: começa
        // de novo, do zero.
        await resp.drain<void>();
        ja = 0;
        resp = await pedir();
      }
      if (resp.statusCode == HttpStatus.ok) {
        ja = 0; // O servidor ignorou o pedido de continuar.
      } else if (resp.statusCode != HttpStatus.partialContent) {
        throw HttpException('o site respondeu ${resp.statusCode}');
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
        downloads.remove(m.id);
        notifyListeners();
        return;
      }
      if (d.total != null && await parcial.length() != d.total) {
        throw const HttpException('a conexão caiu');
      }
      if (!await ehPdf(parcial)) {
        // O site mudou o endereço e devolveu uma página no lugar do PDF.
        await parcial.delete();
        throw const FormatException(
          'o site não entregou o PDF; o endereço pode ter mudado',
        );
      }
      await parcial.rename(destino.path);
      downloads.remove(m.id);
      notifyListeners();
    } catch (e) {
      if (d._cancelado) {
        downloads.remove(m.id);
        notifyListeners();
        return;
      }
      d
        ..estado = EstadoPdf.erro
        ..erro = _mensagem(e);
      notifyListeners();
    } finally {
      cliente.close(force: true);
    }
  }

  /// Para o download; a parte baixada fica guardada para continuar depois.
  void cancelar(ManualPdf m) {
    final d = downloads[m.id];
    if (d == null) return;
    if (d.estado == EstadoPdf.erro) {
      downloads.remove(m.id);
      notifyListeners();
      return;
    }
    d._cancelado = true;
    d._cliente?.close(force: true);
  }

  Future<void> apagar(ManualPdf m) async {
    final f = await arquivo(m);
    if (await f.exists()) await f.delete();
    final parcial = File('${f.path}.part');
    if (await parcial.exists()) await parcial.delete();
    notifyListeners();
  }
}

/// Todo PDF começa com "%PDF".
@visibleForTesting
Future<bool> ehPdf(File f) async {
  final r = await f.open();
  try {
    final b = await r.read(4);
    return b.length == 4 &&
        b[0] == 0x25 &&
        b[1] == 0x50 &&
        b[2] == 0x44 &&
        b[3] == 0x46;
  } finally {
    await r.close();
  }
}

String _mensagem(Object e) {
  if (e is SocketException || e is HttpException || e is TimeoutException) {
    return 'Sem conexão com o site. Toque para continuar de onde parou.';
  }
  if (e is FileSystemException) {
    return 'Não deu para gravar. Confira se o celular tem espaço livre.';
  }
  if (e is FormatException) return 'Erro: ${e.message}.';
  return 'Erro: $e';
}
