import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:farol/dados/compartilhar.dart';
import 'package:farol/dados/estante.dart';
import 'package:farol/dados/wikipedia.dart';
import 'package:farol/dados/zim.dart';
import 'package:farol/telas/compartilhar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Um "ZIM" mínimo: cabeçalho com o número mágico, a posição do MD5 e,
/// no fim, o MD5 de tudo o que vem antes.
Uint8List zimFalso({bool estragado = false}) {
  final corpo = Uint8List(80 + 300000);
  final b = ByteData.sublistView(corpo);
  b.setUint32(0, 72173914, Endian.little);
  b.setUint64(72, corpo.length, Endian.little);
  for (var i = 80; i < corpo.length; i++) {
    corpo[i] = i % 253;
  }
  final soma = md5.convert(corpo).bytes;
  if (estragado) corpo[1000] ^= 0xFF;
  return Uint8List.fromList([...corpo, ...soma]);
}

const idZim = 'wikipedia_pt_medicine_nopic';
const idPdf = 'embrapa-abc-hortalicas';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // O ambiente de teste troca a rede por uma que responde 400 a tudo; aqui
  // os dois lados conversam de verdade, no próprio computador.
  HttpOverrides.global = null;
  final pdf = Uint8List.fromList([
    ...'%PDF-1.4\n'.codeUnits,
    ...List.generate(120000, (i) => i % 251),
  ]);
  late Directory origem, wiki, manuais;
  late Doador doador;
  late Uri base;
  final receptor = Receptor.instancia;

  Future<void> ligar(List<ItemFarol> itens) async {
    doador = Doador(itens: () async => itens);
    await doador.ligar(porta: 0);
    base = Uri.parse('http://127.0.0.1:${doador.porta}');
  }

  ItemFarol item(TipoItem tipo, String id, Uint8List dados) {
    final f = File('${origem.path}/$id.${tipo.name}')..writeAsBytesSync(dados);
    return ItemFarol(
      tipo: tipo,
      id: id,
      titulo: 'Título <$id>',
      tamanho: dados.length,
      caminho: f.path,
    );
  }

  setUp(() async {
    origem = await Directory.systemTemp.createTemp('farol_origem');
    wiki = await Directory.systemTemp.createTemp('farol_wiki');
    manuais = await Directory.systemTemp.createTemp('farol_manuais');
    Wikipedia.instancia.usarPasta(wiki);
    Estante.instancia.usarPasta(manuais);
    doador = Doador(itens: () async => const []);
  });

  tearDown(() async {
    await doador.desligar();
    for (final d in [origem, wiki, manuais]) {
      await d.delete(recursive: true);
    }
  });

  test('lista e recebe um pacote e um manual, conferidos', () async {
    final zim = zimFalso();
    await ligar([
      item(TipoItem.zim, idZim, zim),
      item(TipoItem.pdf, idPdf, pdf),
    ]);
    final itens = await receptor.listar(base);
    expect(itens.map((i) => i.chave), ['zim/$idZim', 'pdf/$idPdf']);
    expect(await receptor.conhece(itens.first), isTrue);
    expect(await receptor.jaTem(itens.first), isFalse);

    for (final i in itens) {
      await receptor.receber(base, i);
    }
    expect(receptor.recebendo, isEmpty);
    expect(await File('${wiki.path}/$idZim.zim').readAsBytes(), zim);
    expect(await File('${manuais.path}/$idPdf.pdf').readAsBytes(), pdf);
    expect(await receptor.jaTem(itens.first), isTrue);
    expect(doador.enviados, 2);
  });

  test('continua de onde parou', () async {
    final zim = zimFalso();
    await ligar([item(TipoItem.zim, idZim, zim)]);
    File('${wiki.path}/$idZim.zim.recebendo')
        .writeAsBytesSync(zim.sublist(0, 100000));
    final itens = await receptor.listar(base);
    await receptor.receber(base, itens.single);
    expect(await File('${wiki.path}/$idZim.zim').readAsBytes(), zim);
  });

  test('recusa arquivo que chegou com defeito', () async {
    await ligar([item(TipoItem.zim, idZim, zimFalso(estragado: true))]);
    final itens = await receptor.listar(base);
    await receptor.receber(base, itens.single);
    final r = receptor.recebendo['zim/$idZim']!;
    expect(r.estado, EstadoRecebimento.erro);
    expect(r.erro, contains('defeito'));
    expect(File('${wiki.path}/$idZim.zim').existsSync(), isFalse);
    receptor.cancelar(itens.single);
    expect(receptor.recebendo, isEmpty);
  });

  test('arquivo que este Farol não conhece fica de fora', () async {
    await ligar([item(TipoItem.zim, 'pacote_de_outra_versao', zimFalso())]);
    final itens = await receptor.listar(base);
    expect(await receptor.conhece(itens.single), isFalse);
    await receptor.receber(base, itens.single);
    expect(
      receptor.recebendo['zim/pacote_de_outra_versao']!.erro,
      contains('não conhece'),
    );
    receptor.cancelar(itens.single);
  });

  test('só entrega o que está na lista', () async {
    await ligar([item(TipoItem.pdf, idPdf, pdf)]);
    final c = HttpClient();
    Future<int> status(String caminho) async {
      final req = await c.getUrl(Uri.parse('$base$caminho'));
      return (await req.close()).statusCode;
    }

    expect(await status('/baixar/pdf/$idPdf'), 200);
    expect(await status('/baixar/pdf/outro'), 404);
    expect(await status('/baixar/zim/$idPdf'), 404);
    expect(await status('/baixar/pdf/..%2F..%2Fetc%2Fpasswd'), 404);
    expect(await status('/qualquer'), 404);
    final post = await c.postUrl(Uri.parse('$base/farol.json'));
    expect((await post.close()).statusCode, 405);
    c.close(force: true);
  });

  test('a página do navegador lista o app e os arquivos, sem HTML solto', () {
    final p = paginaDoador([
      const ItemFarol(
        tipo: TipoItem.apk,
        id: 'farol',
        titulo: 'O app Farol',
        tamanho: 22000000,
      ),
      const ItemFarol(
        tipo: TipoItem.pdf,
        id: idPdf,
        titulo: 'Horta <b>',
        tamanho: 3000000,
      ),
    ]);
    expect(p, contains('href="/baixar/apk/farol"'));
    expect(p, contains('href="/baixar/pdf/$idPdf"'));
    expect(p, contains('Horta &lt;b&gt;'));
    expect(p, contains('21 MB'));
  });

  test('entende o endereço digitado de vários jeitos', () {
    expect(
      enderecoDoador('192.168.43.1').toString(),
      'http://192.168.43.1:8642',
    );
    expect(
      enderecoDoador(' 192.168.43.1:9000 ').toString(),
      'http://192.168.43.1:9000',
    );
    expect(
      enderecoDoador('http://10.0.0.5:8642/').toString(),
      'http://10.0.0.5:8642',
    );
    expect(enderecoDoador(''), isNull);
    expect(enderecoDoador('https://x.com'), isNull);
  });

  test('confere o MD5 do próprio ZIM', () async {
    final f = File('${origem.path}/a.zim')..writeAsBytesSync(zimFalso());
    expect(await zimInteiro(f.path), isTrue);
    f.writeAsBytesSync(zimFalso(estragado: true));
    expect(await zimInteiro(f.path), isFalse);
    f.writeAsBytesSync(zimFalso().sublist(0, 5000));
    expect(await zimInteiro(f.path), isFalse);
  });

  testWidgets('receber sem endereço pede o endereço do outro celular', (
    t,
  ) async {
    await t.pumpWidget(const MaterialApp(home: TelaReceber()));
    await t.tap(find.byKey(const ValueKey('conectar')));
    await t.pump();
    expect(find.textContaining('Digite o endereço'), findsOneWidget);
  });

  testWidgets('escolhe entre mandar e receber', (t) async {
    await t.pumpWidget(const MaterialApp(home: TelaCompartilhar()));
    await t.tap(find.byKey(const ValueKey('receber')));
    await t.pumpAndSettle();
    expect(find.byType(TelaReceber), findsOneWidget);
  });
}
