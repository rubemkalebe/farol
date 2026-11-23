import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:farol/dados/wikipedia.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor local que imita o download.kiwix.org: lista, arquivo com
/// suporte a Range e o .sha256.
Future<(HttpServer, List<String>)> servidor(
  Uint8List arquivo, {
  String? sha,
}) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final pedidos = <String>[];
  final nome = 'wikipedia_pt_medicine_nopic_2026-11.zim';
  s.listen((req) async {
    final r = req.response;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    pedidos.add('${req.uri.path}${range == null ? '' : ' $range'}');
    if (req.uri.path == '/') {
      r.write('<a href="wikipedia_pt_medicine_nopic_2026-10.zim">');
      r.write('<a href="$nome">');
    } else if (req.uri.path == '/$nome') {
      var ini = 0;
      if (range != null) {
        ini = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
        r.statusCode = HttpStatus.partialContent;
      }
      r.contentLength = arquivo.length - ini;
      r.add(arquivo.sublist(ini));
    } else if (req.uri.path == '/$nome.sha256') {
      r.write('${sha ?? sha256.convert(arquivo)}  $nome\n');
    } else {
      r.statusCode = HttpStatus.notFound;
    }
    await r.close();
  });
  return (s, pedidos);
}

void main() {
  final wiki = Wikipedia.instancia;
  final medicina = pacotesWiki.first;
  final arquivo = Uint8List.fromList(List.generate(300000, (i) => i % 251));
  late Directory pasta;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('farol_wiki');
    wiki.usarPasta(pasta);
  });

  tearDown(() async {
    wiki.servidor = servidorKiwix;
    await pasta.delete(recursive: true);
  });

  test('baixa a versão mais nova, confere e instala', () async {
    final (s, pedidos) = await servidor(arquivo);
    wiki.servidor = 'http://${s.address.host}:${s.port}/';
    await wiki.baixar(medicina);
    await s.close(force: true);

    expect(wiki.downloads, isEmpty);
    expect(await wiki.instalados(), [medicina]);
    final f = File('${pasta.path}/${medicina.id}.zim');
    expect(await f.readAsBytes(), arquivo);
    expect(pedidos, contains('/wikipedia_pt_medicine_nopic_2026-11.zim'));
  });

  test('continua de onde parou', () async {
    File('${pasta.path}/${medicina.id}.zim.part')
        .writeAsBytesSync(arquivo.sublist(0, 120000));
    final (s, pedidos) = await servidor(arquivo);
    wiki.servidor = 'http://${s.address.host}:${s.port}/';
    await wiki.baixar(medicina);
    await s.close(force: true);

    expect(
      pedidos,
      contains('/wikipedia_pt_medicine_nopic_2026-11.zim bytes=120000-'),
    );
    expect(
      await File('${pasta.path}/${medicina.id}.zim').readAsBytes(),
      arquivo,
    );
  });

  test('arquivo com defeito não é instalado', () async {
    final (s, _) = await servidor(arquivo, sha: 'f' * 64);
    wiki.servidor = 'http://${s.address.host}:${s.port}/';
    await wiki.baixar(medicina);
    await s.close(force: true);

    expect(await wiki.instalados(), isEmpty);
    expect(wiki.downloads[medicina.id]!.estado, EstadoDownload.erro);
    expect(wiki.downloads[medicina.id]!.erro, contains('defeito'));
    wiki.cancelar(medicina); // "Deixar": tira o erro da tela.
    expect(wiki.downloads, isEmpty);
  });
}
