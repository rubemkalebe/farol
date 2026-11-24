import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'estante.dart';
import 'passar_adiante.dart';
import 'wikipedia.dart';
import 'zim.dart';

/// Passar a biblioteca de um celular para outro sem internet: um celular
/// liga um servidorzinho na rede local (o roteador do próprio celular ou
/// um Wi-Fi em comum) e o outro baixa dele os pacotes e os manuais.
/// Quem não tem o Farol abre o endereço no navegador e baixa o app.
const portaFarol = 8642;

enum TipoItem { zim, pdf, apk }

/// Um arquivo que um celular oferece ao outro.
class ItemFarol {
  const ItemFarol({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.tamanho,
    this.caminho,
  });

  /// Lê um item da lista do outro celular. Devolve null se vier algo que
  /// este Farol não entende (de uma versão mais nova, por exemplo).
  static ItemFarol? deJson(Object? j) {
    if (j is! Map) return null;
    final tipo = TipoItem.values.asNameMap()[j['tipo']];
    final id = j['id'], titulo = j['titulo'], tamanho = j['tamanho'];
    if (tipo == null || id is! String || titulo is! String || tamanho is! int) {
      return null;
    }
    if (!_idValido.hasMatch(id)) return null;
    return ItemFarol(tipo: tipo, id: id, titulo: titulo, tamanho: tamanho);
  }

  final TipoItem tipo;
  final String id;
  final String titulo;
  final int tamanho;

  /// Onde o arquivo está, só no celular que manda.
  final String? caminho;

  String get chave => '${tipo.name}/$id';

  String get nomeArquivo => switch (tipo) {
    TipoItem.zim => '$id.zim',
    TipoItem.pdf => '$id.pdf',
    TipoItem.apk => 'Farol.apk',
  };

  Map<String, Object> toJson() => {
    'tipo': tipo.name,
    'id': id,
    'titulo': titulo,
    'tamanho': tamanho,
  };
}

final _idValido = RegExp(r'^[A-Za-z0-9._-]+$');

String tamanhoLegivel(int bytes) {
  if (bytes >= 1 << 30) {
    return '${(bytes / (1 << 30)).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
  final mb = bytes / (1 << 20);
  return mb >= 10
      ? '${mb.round()} MB'
      : '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
}

/// O que este celular tem para passar adiante: o próprio Farol (se der),
/// os pacotes da biblioteca e os manuais baixados.
Future<List<ItemFarol>> itensDoAparelho() async {
  final itens = <ItemFarol>[];
  if (await apkInteiro()) {
    try {
      final f = File(await prepararApk());
      itens.add(
        ItemFarol(
          tipo: TipoItem.apk,
          id: 'farol',
          titulo: 'O app Farol',
          tamanho: await f.length(),
          caminho: f.path,
        ),
      );
    } catch (_) {
      // Sem o APK, ainda dá para passar o resto.
    }
  }
  final wiki = Wikipedia.instancia;
  for (final p in await wiki.instalados()) {
    final f = await wiki.arquivo(p);
    itens.add(
      ItemFarol(
        tipo: TipoItem.zim,
        id: p.id,
        titulo: p.daWikipedia ? 'Wikipédia: ${p.titulo}' : p.titulo,
        tamanho: await f.length(),
        caminho: f.path,
      ),
    );
  }
  final estante = Estante.instancia;
  final baixados = await estante.baixados();
  if (baixados.isNotEmpty) {
    for (final (_, manuais) in await carregarEstante()) {
      for (final m in manuais) {
        if (!baixados.contains(m.id)) continue;
        final f = await estante.arquivo(m);
        itens.add(
          ItemFarol(
            tipo: TipoItem.pdf,
            id: m.id,
            titulo: m.titulo,
            tamanho: await f.length(),
            caminho: f.path,
          ),
        );
      }
    }
  }
  return itens;
}

/// Endereços deste celular na rede local, o do roteador do celular
/// primeiro. Os da operadora ficam de fora: por eles o outro não chega.
Future<List<String>> enderecosLocais() async {
  final List<NetworkInterface> placas;
  try {
    placas = await NetworkInterface.list(type: InternetAddressType.IPv4);
  } catch (_) {
    return const [];
  }
  int ordem(String nome) {
    final n = nome.toLowerCase();
    if (n.contains('ap') || n.startsWith('swlan')) return 0;
    if (n.startsWith('wlan') || n.startsWith('wl') || n.startsWith('eth')) {
      return 1;
    }
    return 2;
  }

  final fora = RegExp(
    r'^(rmnet|ccmni|pdp|v4-|clat|dummy|tun|seth|docker|br-|veth|virbr|vmnet)',
  );
  final achados = <(int, String)>[];
  for (final p in placas) {
    if (fora.hasMatch(p.name.toLowerCase())) continue;
    for (final a in p.addresses) {
      if (a.isLoopback || a.isLinkLocal) continue;
      if (!_privado(a.address)) continue;
      achados.add((ordem(p.name), a.address));
    }
  }
  achados.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, e) in achados) e].take(3).toList();
}

bool _privado(String ip) {
  final p = ip.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.contains(null)) return false;
  return p[0] == 10 ||
      (p[0] == 192 && p[1] == 168) ||
      (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31);
}

/// Servidor que oferece os arquivos deste celular na rede local.
/// Só entrega o que está na lista; não recebe nada.
class Doador extends ChangeNotifier {
  Doador({Future<List<ItemFarol>> Function()? itens})
    : _buscarItens = itens ?? itensDoAparelho;

  final Future<List<ItemFarol>> Function() _buscarItens;
  HttpServer? _servidor;
  List<ItemFarol> itens = const [];

  /// Quantos arquivos estão saindo agora e quantos já saíram inteiros.
  int enviando = 0;
  int enviados = 0;

  bool get ligado => _servidor != null;
  int get porta => _servidor?.port ?? 0;

  Future<void> ligar({int porta = portaFarol}) async {
    itens = await _buscarItens();
    HttpServer s;
    try {
      s = await HttpServer.bind(InternetAddress.anyIPv4, porta);
    } on SocketException {
      // Porta ocupada: usa qualquer outra.
      s = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _servidor = s;
    s.listen((req) => _atender(req).catchError((_) {}));
    notifyListeners();
  }

  Future<void> desligar() async {
    final s = _servidor;
    _servidor = null;
    await s?.close(force: true);
  }

  Future<void> _atender(HttpRequest req) async {
    final r = req.response;
    if (req.method != 'GET' && req.method != 'HEAD') {
      r.statusCode = HttpStatus.methodNotAllowed;
      await r.close();
      return;
    }
    final partes = req.uri.pathSegments;
    if (partes.isEmpty) {
      r.headers.contentType = ContentType.html;
      r.write(paginaDoador(itens));
      await r.close();
      return;
    }
    if (partes.length == 1 && partes.first == 'farol.json') {
      r.headers.contentType = ContentType.json;
      r.write(
        jsonEncode({
          'farol': 1,
          'itens': [for (final i in itens) i.toJson()],
        }),
      );
      await r.close();
      return;
    }
    final item = partes.length == 3 && partes.first == 'baixar'
        ? itens.where((i) => i.chave == '${partes[1]}/${partes[2]}').firstOrNull
        : null;
    if (item == null) {
      r.statusCode = HttpStatus.notFound;
      await r.close();
      return;
    }
    await _enviar(req, item);
  }

  Future<void> _enviar(HttpRequest req, ItemFarol item) async {
    final r = req.response;
    final f = File(item.caminho!);
    final total = await f.length();
    var ini = 0;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    final m = range == null
        ? null
        : RegExp(r'^bytes=(\d+)-$').firstMatch(range);
    if (m != null) {
      ini = int.parse(m[1]!);
      if (ini >= total) {
        r.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await r.close();
        return;
      }
      r.statusCode = HttpStatus.partialContent;
      r.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $ini-${total - 1}/$total',
      );
    }
    r.headers
      ..contentType = switch (item.tipo) {
        TipoItem.apk => ContentType(
          'application',
          'vnd.android.package-archive',
        ),
        TipoItem.pdf => ContentType('application', 'pdf'),
        TipoItem.zim => ContentType('application', 'octet-stream'),
      }
      ..set(HttpHeaders.acceptRangesHeader, 'bytes')
      ..set(
        'content-disposition',
        'attachment; filename="${item.nomeArquivo}"',
      );
    r.contentLength = total - ini;
    if (req.method == 'HEAD') {
      await r.close();
      return;
    }
    enviando++;
    notifyListeners();
    var inteiro = false;
    try {
      await r.addStream(f.openRead(ini));
      await r.close();
      inteiro = true;
    } finally {
      enviando--;
      if (inteiro) enviados++;
      if (_servidor != null) notifyListeners();
    }
  }
}

/// Página para quem abre o endereço no navegador, com ou sem o Farol.
@visibleForTesting
String paginaDoador(List<ItemFarol> itens) {
  final e = const HtmlEscape();
  final apk = itens.where((i) => i.tipo == TipoItem.apk).firstOrNull;
  final resto = itens.where((i) => i.tipo != TipoItem.apk);
  String link(ItemFarol i) =>
      '<li><a href="/baixar/${i.tipo.name}/${i.id}">${e.convert(i.titulo)}'
      '</a> <small>${tamanhoLegivel(i.tamanho)}</small></li>';
  return '''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Farol</title>
<style>
body{font-family:sans-serif;background:#0b0f17;color:#eef;margin:0 auto;
max-width:640px;padding:16px;line-height:1.5}
a{color:#ffd54a}li{margin:10px 0}small{color:#aab}
.app{display:block;background:#ffd54a;color:#111;padding:14px;
border-radius:12px;text-align:center;font-weight:700;text-decoration:none}
</style></head><body>
<h1>Farol</h1>
${apk == null ? '' : '''<p><a class="app" href="/baixar/apk/${apk.id}">Baixar o app Farol (${tamanhoLegivel(apk.tamanho)})</a></p>
<p>Depois de baixar, abra o arquivo e permita instalar apps desta fonte.
Com o Farol instalado, receba a biblioteca pelo próprio app (Biblioteca,
"Passar para outro celular", Receber): ele confere cada arquivo.</p>'''}
${resto.isEmpty ? '' : '''<h2>Biblioteca</h2>
<p>Os arquivos .zim abrem no Farol ou no app Kiwix. Os .pdf abrem em
qualquer leitor de PDF.</p>
<ul>${resto.map(link).join()}</ul>'''}
</body></html>''';
}

/// Lê o endereço que a pessoa digitou: "192.168.43.1", com ou sem porta,
/// com ou sem http://.
Uri? enderecoDoador(String texto) {
  var t = texto.trim();
  if (t.isEmpty) return null;
  if (!t.contains('://')) t = 'http://$t';
  final u = Uri.tryParse(t);
  if (u == null || u.host.isEmpty || u.scheme != 'http') return null;
  return Uri(
    scheme: 'http',
    host: u.host,
    port: u.hasPort ? u.port : portaFarol,
  );
}

enum EstadoRecebimento { recebendo, conferindo, erro }

class Recebimento {
  Recebimento(this.item);

  final ItemFarol item;
  EstadoRecebimento estado = EstadoRecebimento.recebendo;
  int recebido = 0;
  String? erro;
  bool _cancelado = false;
  HttpClient? _cliente;

  double get progresso => item.tamanho == 0 ? 0 : recebido / item.tamanho;
}

/// Recebe arquivos de outro celular com o Farol.
class Receptor extends ChangeNotifier {
  Receptor._();

  static final instancia = Receptor._();

  final recebendo = <String, Recebimento>{};

  /// Lista o que o outro celular oferece.
  Future<List<ItemFarol>> listar(Uri base) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await c.getUrl(base.replace(path: '/farol.json'));
      final resp = await req.close().timeout(const Duration(seconds: 15));
      if (resp.statusCode != HttpStatus.ok) {
        throw const FormatException('do outro lado não está um Farol');
      }
      final Object? j;
      try {
        j = jsonDecode(await resp.transform(utf8.decoder).join());
      } on FormatException {
        throw const FormatException('do outro lado não está um Farol');
      }
      if (j is! Map || j['farol'] != 1 || j['itens'] is! List) {
        throw const FormatException('do outro lado não está um Farol');
      }
      return [for (final i in j['itens'] as List) ?ItemFarol.deJson(i)];
    } finally {
      c.close(force: true);
    }
  }

  /// Se este Farol conhece o item e sabe onde guardá-lo.
  Future<bool> conhece(ItemFarol i) async => await _destino(i) != null;

  /// Se o item já está neste celular.
  Future<bool> jaTem(ItemFarol i) async {
    final d = await _destino(i);
    return d != null && await d.$1.exists();
  }

  Future<(File, Future<void> Function(File))?> _destino(ItemFarol i) async {
    switch (i.tipo) {
      case TipoItem.zim:
        final p = pacotesWiki.where((p) => p.id == i.id).firstOrNull;
        if (p == null) return null;
        final w = Wikipedia.instancia;
        return (await w.arquivo(p), (File f) => w.guardarRecebido(p, f));
      case TipoItem.pdf:
        final ManualPdf m;
        try {
          final achado = [for (final (_, ms) in await carregarEstante()) ...ms]
              .where((m) => m.id == i.id)
              .firstOrNull;
          if (achado == null) return null;
          m = achado;
        } catch (_) {
          return null;
        }
        final e = Estante.instancia;
        return (await e.arquivo(m), (File f) => e.guardarRecebido(m, f));
      case TipoItem.apk:
        return null;
    }
  }

  Future<void> receber(Uri base, ItemFarol item) async {
    if (recebendo.containsKey(item.chave)) return;
    final r = recebendo[item.chave] = Recebimento(item);
    notifyListeners();
    final cliente = r._cliente = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final destino = await _destino(item);
      if (destino == null) {
        throw const FormatException('este Farol não conhece esse arquivo');
      }
      final (arquivo, guardar) = destino;
      final parcial = File('${arquivo.path}.recebendo');
      var ja = await parcial.exists() ? await parcial.length() : 0;
      if (ja >= item.tamanho) {
        await parcial.delete();
        ja = 0;
      }
      final req = await cliente.getUrl(
        base.replace(path: '/baixar/${item.tipo.name}/${item.id}'),
      );
      if (ja > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$ja-');
      final resp = await req.close();
      if (resp.statusCode == HttpStatus.ok) {
        ja = 0;
      } else if (resp.statusCode != HttpStatus.partialContent) {
        throw HttpException('o outro celular respondeu ${resp.statusCode}');
      }
      r.recebido = ja;
      final saida = parcial.openWrite(
        mode: ja > 0 ? FileMode.append : FileMode.write,
      );
      var ultimo = DateTime.now();
      try {
        await for (final pedaco in resp.timeout(const Duration(seconds: 30))) {
          if (r._cancelado) break;
          saida.add(pedaco);
          r.recebido += pedaco.length;
          if (DateTime.now().difference(ultimo).inMilliseconds > 250) {
            ultimo = DateTime.now();
            notifyListeners();
          }
        }
      } finally {
        await saida.close();
      }
      if (r._cancelado) {
        recebendo.remove(item.chave);
        notifyListeners();
        return;
      }
      if (await parcial.length() != item.tamanho) {
        throw const HttpException('a conexão caiu');
      }
      r.estado = EstadoRecebimento.conferindo;
      notifyListeners();
      final caminho = parcial.path;
      final bom = switch (item.tipo) {
        TipoItem.zim => await Isolate.run(() => zimInteiro(caminho)),
        TipoItem.pdf => await ehPdf(parcial),
        TipoItem.apk => false,
      };
      if (!bom) {
        await parcial.delete();
        throw const FormatException(
          'o arquivo chegou com defeito; tente de novo',
        );
      }
      await guardar(parcial);
      recebendo.remove(item.chave);
      notifyListeners();
    } catch (e) {
      if (r._cancelado) {
        recebendo.remove(item.chave);
        notifyListeners();
        return;
      }
      r
        ..estado = EstadoRecebimento.erro
        ..erro = mensagemRecebimento(e);
      notifyListeners();
    } finally {
      cliente.close(force: true);
    }
  }

  /// Para de receber; a parte que chegou fica guardada para continuar.
  void cancelar(ItemFarol item) {
    final r = recebendo[item.chave];
    if (r == null) return;
    if (r.estado == EstadoRecebimento.erro) {
      recebendo.remove(item.chave);
      notifyListeners();
      return;
    }
    r._cancelado = true;
    r._cliente?.close(force: true);
  }
}

String mensagemRecebimento(Object e) {
  if (e is SocketException || e is HttpException || e is TimeoutException) {
    return 'A conexão com o outro celular caiu. Confira se os dois estão na '
        'mesma rede e toque em Continuar.';
  }
  if (e is FileSystemException) {
    return 'Não deu para gravar. Confira se o celular tem espaço livre.';
  }
  if (e is FormatException) return 'Erro: ${e.message}.';
  return 'Erro: $e';
}

const _canal = MethodChannel('farol/apk');

/// Deixa a tela acesa enquanto passa os arquivos: com a tela apagada, o
/// celular pode cortar o Wi-Fi no meio.
Future<void> manterTelaAcesa(bool acesa) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _canal.invokeMethod<void>('telaAcesa', acesa);
  } catch (_) {
    // Sem isso, só não segura a tela.
  }
}
