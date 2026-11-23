import 'dart:io';
import 'dart:typed_data';

import 'package:farol/dados/estante.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor local que entrega um PDF (com suporte a Range) e, em outro
/// endereço, uma página HTML no lugar do PDF.
Future<(HttpServer, List<String>)> servidor(Uint8List pdf) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final pedidos = <String>[];
  s.listen((req) async {
    final r = req.response;
    final range = req.headers.value(HttpHeaders.rangeHeader);
    pedidos.add('${req.uri.path}${range == null ? '' : ' $range'}');
    if (req.uri.path == '/manual.pdf') {
      var ini = 0;
      if (range != null) {
        ini = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
        r.statusCode = HttpStatus.partialContent;
      }
      r.contentLength = pdf.length - ini;
      r.add(pdf.sublist(ini));
    } else if (req.uri.path == '/semrange.pdf') {
      // Como o repositório da Funasa: recusa pedido com Range.
      if (range != null) {
        r.statusCode = HttpStatus.forbidden;
      } else {
        r.contentLength = pdf.length;
        r.add(pdf);
      }
    } else if (req.uri.path == '/mudou.pdf') {
      r.write('<html>Página não encontrada</html>');
    } else {
      r.statusCode = HttpStatus.notFound;
    }
    await r.close();
  });
  return (s, pedidos);
}

ManualPdf manual(String url) => ManualPdf(
  id: 'teste',
  tema: 'Plantar',
  titulo: 'Horta',
  orgao: 'Embrapa',
  descricao: 'Como fazer uma horta.',
  url: url,
  pagina: url,
  tamanho: '1 MB',
  licenca: 'livre',
);

void main() {
  final estante = Estante.instancia;
  final pdf = Uint8List.fromList([
    ...'%PDF-1.4\n'.codeUnits,
    ...List.generate(200000, (i) => i % 251),
  ]);
  late Directory pasta;

  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('farol_estante');
    estante.usarPasta(pasta);
  });

  tearDown(() => pasta.delete(recursive: true));

  test('lê a lista de manuais por tema', () {
    final temas = lerEstante('''
temas:
  - tema: Plantar e colher
    manuais:
      - id: horta
        titulo: Horta em casa
        orgao: Embrapa
        ano: 2020
        descricao: Passo a passo.
        url: https://exemplo.gov.br/horta.pdf
        pagina: https://exemplo.gov.br/horta
        tamanho: 3 MB
        licenca: Reprodução permitida citando a fonte.
''');
    expect(temas, hasLength(1));
    final (tema, manuais) = temas.first;
    expect(tema, 'Plantar e colher');
    expect(manuais.single.id, 'horta');
    expect(manuais.single.ano, 2020);
    expect(manuais.single.tema, 'Plantar e colher');
  });

  test('baixa, confere que é PDF e guarda', () async {
    final (s, _) = await servidor(pdf);
    final m = manual('http://${s.address.host}:${s.port}/manual.pdf');
    await estante.baixar(m);
    await s.close(force: true);

    expect(estante.downloads, isEmpty);
    expect(await estante.baixados(), {'teste'});
    expect(await File('${pasta.path}/teste.pdf').readAsBytes(), pdf);
  });

  test('continua de onde parou', () async {
    File('${pasta.path}/teste.pdf.part')
        .writeAsBytesSync(pdf.sublist(0, 90000));
    final (s, pedidos) = await servidor(pdf);
    final m = manual('http://${s.address.host}:${s.port}/manual.pdf');
    await estante.baixar(m);
    await s.close(force: true);

    expect(pedidos, ['/manual.pdf bytes=90000-']);
    expect(await File('${pasta.path}/teste.pdf').readAsBytes(), pdf);
  });

  test('site que não continua: começa do zero', () async {
    File('${pasta.path}/teste.pdf.part').writeAsBytesSync([1, 2, 3]);
    final (s, pedidos) = await servidor(pdf);
    final m = manual('http://${s.address.host}:${s.port}/semrange.pdf');
    await estante.baixar(m);
    await s.close(force: true);

    expect(pedidos, ['/semrange.pdf bytes=3-', '/semrange.pdf']);
    expect(await File('${pasta.path}/teste.pdf').readAsBytes(), pdf);
  });

  test('a lista do app: ids únicos, https e tudo preenchido', () {
    final temas = lerEstante(File('conteudo/estante.yaml').readAsStringSync());
    final ids = <String>{};
    for (final (tema, manuais) in temas) {
      expect(manuais, isNotEmpty, reason: tema);
      for (final m in manuais) {
        expect(ids.add(m.id), isTrue, reason: 'id repetido: ${m.id}');
        expect(m.url, startsWith('https://'), reason: m.id);
        expect(m.pagina, startsWith('https://'), reason: m.id);
        for (final campo in [
          m.titulo,
          m.orgao,
          m.descricao,
          m.tamanho,
          m.licenca,
        ]) {
          expect(campo.trim(), isNotEmpty, reason: m.id);
        }
      }
    }
    expect(ids.length, greaterThanOrEqualTo(20));
  });

  test('recusa página no lugar do PDF', () async {
    final (s, _) = await servidor(pdf);
    final m = manual('http://${s.address.host}:${s.port}/mudou.pdf');
    await estante.baixar(m);
    await s.close(force: true);

    expect(estante.downloads['teste']!.estado, EstadoPdf.erro);
    expect(
      estante.downloads['teste']!.erro,
      contains('endereço pode ter mudado'),
    );
    expect(await estante.baixados(), isEmpty);
    estante.cancelar(m);
    expect(estante.downloads, isEmpty);
  });

  test('apagar tira o arquivo', () async {
    File('${pasta.path}/teste.pdf').writeAsBytesSync(pdf);
    await estante.apagar(manual('http://x/manual.pdf'));
    expect(await estante.baixados(), isEmpty);
  });
}
