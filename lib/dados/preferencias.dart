import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamanho de letra escolhido dentro do app. Multiplica o tamanho que a
/// pessoa já escolheu nas configurações do celular.
class TamanhoTexto {
  const TamanhoTexto(this.id, this.nome, this.escala);

  final String id;
  final String nome;
  final double escala;
}

const tamanhosTexto = [
  TamanhoTexto('normal', 'Normal', 1.0),
  TamanhoTexto('grande', 'Grande', 1.25),
  TamanhoTexto('enorme', 'Muito grande', 1.5),
];

final escalaTexto = ValueNotifier<double>(1.0);

const _chave = 'tamanho_texto';

Future<void> carregarTamanhoTexto() async {
  final id = (await SharedPreferences.getInstance()).getString(_chave);
  escalaTexto.value = tamanhosTexto
      .firstWhere((t) => t.id == id, orElse: () => tamanhosTexto.first)
      .escala;
}

Future<void> salvarTamanhoTexto(TamanhoTexto t) async {
  escalaTexto.value = t.escala;
  await (await SharedPreferences.getInstance()).setString(_chave, t.id);
}
