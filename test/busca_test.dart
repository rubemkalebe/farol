import 'dart:io';

import 'package:farol/dados/busca.dart';
import 'package:farol/dados/emergencia.dart';
import 'package:farol/dados/locais.dart';
import 'package:farol/dados/secoes.dart';
import 'package:farol/telas/emergencia.dart' show iconesEmergencia;
import 'package:flutter_test/flutter_test.dart';

Future<String> lerDisco(String caminho) async => File(caminho).readAsString();

void main() {
  late Busca busca;
  late List<Secao> secoes;

  setUpAll(() async {
    secoes = await carregarSecoes(blocos: await blocosLocais('mg/belo-horizonte', ler: lerDisco), ler: lerDisco);
    busca = Busca(secoes, lerSinonimos(File('conteudo/sinonimos.yaml').readAsStringSync()));
  });

  // Consulta → título que precisa aparecer entre os 3 primeiros.
  const casos = {
    'meu filho engasgou': 'Engasgo',
    'engasgo bebe': 'Engasgo',
    'escorpião picou': 'Escorpião, cobra e aranha',
    'picada de cobra': 'Escorpião, cobra e aranha',
    'desmaiou': 'Desmaio',
    'nao respira': 'Não responde e não respira: RCP',
    'coração parou': 'Não responde e não respira: RCP',
    'sangrando muito': 'Sangramento forte',
    'queimou a mão': 'Queimadura',
    'convulsão': 'Convulsão',
    'derrame': 'AVC (derrame)',
    'dor no peito': 'Infarto (ataque cardíaco)',
    'diabético passando mal': 'Hipoglicemia (açúcar baixo)',
    'tomou produto de limpeza veneno': 'Envenenamento e intoxicação',
    'faltou luz geladeira': 'Geladeira e comida',
    'insulina sem geladeira': 'Remédios que ficam na geladeira',
    'gerador dentro de casa': 'O que pode matar',
    'água sanitária gotas': 'Água',
    'bateria do celular acabando': 'Bateria do celular',
    'elevador parado': 'Em prédio',
    'rua alagada': 'Chuva forte e alagamento',
    'barranco rachadura': 'Deslizamento de terra',
    'terremoto': 'Tremor de terra (terremoto)',
    'aparelho queimou cemig': 'Aparelho queimou? Você tem direito ao ressarcimento',
    'soro caseiro diarreia': 'Diarreia, vômito e desidratação',
  };

  for (final MapEntry(key: consulta, value: esperado) in casos.entries) {
    test('"$consulta" acha "$esperado"', () {
      final top = busca.buscar(consulta, limite: 3).map((r) => r.secao.titulo).toList();
      expect(top, contains(esperado), reason: 'veio: $top');
    });
  }

  test('trechos dos resultados vêm limpos', () {
    for (final q in casos.keys) {
      for (final r in busca.buscar(q)) {
        expect(r.trecho, isNot(contains(r'$1')), reason: q);
        expect(r.trecho, isNot(contains('[fonte')), reason: q);
        expect(r.trecho.trim(), isNotEmpty, reason: '$q → ${r.secao.chave}');
      }
    }
  });

  test('consulta vazia ou só palavras vazias não devolve nada', () {
    expect(busca.buscar(''), isEmpty);
    expect(busca.buscar('socorro ajuda'), isEmpty);
  });

  test('roteiro de emergência: perguntas ligadas e seções existentes em todas as cidades', () async {
    final roteiro = lerRoteiro(File('conteudo/emergencia.yaml').readAsStringSync());
    expect(roteiro, contains('inicio'));
    final alcancadas = {'inicio'};
    for (final p in roteiro.values) {
      expect(p.opcoes, isNotEmpty, reason: p.id);
      for (final o in p.opcoes) {
        expect(o.vai != null || o.secoes.isNotEmpty, isTrue, reason: '${p.id}: "${o.texto}" não leva a nada');
        if (o.vai != null) {
          expect(roteiro, contains(o.vai), reason: '${p.id}: "${o.texto}" vai para pergunta inexistente');
          alcancadas.add(o.vai!);
        }
        if (o.icone != null) {
          expect(iconesEmergencia, contains(o.icone), reason: '${p.id}: ícone "${o.icone}" não existe');
        }
        for (final t in o.ligar) {
          expect(RegExp(r'^[0-9]+$').hasMatch(t), isTrue, reason: '${p.id}: ligar "$t"');
        }
      }
    }
    expect(alcancadas, roteiro.keys.toSet(), reason: 'há pergunta que nenhuma opção alcança');

    final cidades = [...(await carregarCidades(ler: lerDisco)).map((c) => c.id), null];
    for (final cidade in cidades) {
      final chaves = {
        for (final s in await carregarSecoes(blocos: await blocosLocais(cidade, ler: lerDisco), ler: lerDisco)) s.chave,
      };
      for (final p in roteiro.values) {
        for (final o in p.opcoes) {
          for (final s in o.secoes) {
            expect(chaves, contains(s), reason: 'seção "$s" não existe para ${cidade ?? 'outra'}');
          }
        }
      }
    }
  });
}
