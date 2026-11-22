import 'package:shared_preferences/shared_preferences.dart';

/// Cidade escolhida pelo usuário. O texto nacional vale para todas; os
/// blocos `:::regiao ...` dos capítulos mostram telefones e serviços locais.
class Regiao {
  const Regiao(this.id, this.nome);

  final String id;
  final String nome;
}

const regioes = [
  Regiao('bh', 'Belo Horizonte (MG)'),
  Regiao('natal', 'Natal (RN)'),
  Regiao('mossoro', 'Mossoró (RN)'),
  Regiao('outra', 'Outra cidade'),
];

final idsRegioes = {for (final r in regioes) r.id};

Regiao regiaoPorId(String id) => regioes.firstWhere((r) => r.id == id, orElse: () => regioes.last);

const _chave = 'regiao';

Future<String?> lerRegiao() async => (await SharedPreferences.getInstance()).getString(_chave);

Future<void> salvarRegiao(String id) async =>
    (await SharedPreferences.getInstance()).setString(_chave, id);

final _abre = RegExp(r'^:::regiao ([a-z,]+)\s*$');
final _fecha = RegExp(r'^:::\s*$');

/// Mantém só os blocos da região escolhida. Fora dos blocos, tudo fica.
///
/// ```
/// :::regiao bh
/// texto só para BH
/// :::
/// :::regiao natal,mossoro
/// texto para Natal e Mossoró
/// :::
/// ```
String filtrarRegiao(String markdown, String regiao) {
  final saida = StringBuffer();
  bool? mostrar; // null = fora de bloco
  for (final linha in markdown.split('\n')) {
    final abre = _abre.firstMatch(linha);
    if (mostrar == null && abre != null) {
      mostrar = abre.group(1)!.split(',').contains(regiao);
      continue;
    }
    if (mostrar != null && _fecha.hasMatch(linha)) {
      mostrar = null;
      continue;
    }
    if (mostrar ?? true) saida.writeln(linha);
  }
  return saida.toString();
}

/// Problemas de formato nos blocos de região, para os testes do conteúdo.
List<String> errosDeRegiao(String markdown) {
  final erros = <String>[];
  var dentro = false;
  var n = 0;
  for (final linha in markdown.split('\n')) {
    n++;
    if (linha.startsWith(':::regiao')) {
      final m = _abre.firstMatch(linha);
      if (dentro) erros.add('linha $n: bloco aberto dentro de outro');
      if (m == null) {
        erros.add('linha $n: abertura malformada');
      } else {
        for (final id in m.group(1)!.split(',')) {
          if (!idsRegioes.contains(id)) erros.add('linha $n: região desconhecida "$id"');
        }
      }
      dentro = true;
    } else if (_fecha.hasMatch(linha)) {
      if (!dentro) erros.add('linha $n: fechamento sem abertura');
      dentro = false;
    }
  }
  if (dentro) erros.add('bloco não fechado no fim do arquivo');
  return erros;
}
