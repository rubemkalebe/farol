import 'package:farol/dados/mapa_offline.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final hoje = DateTime(2026, 11, 23);

  test('sem marcação, pede para baixar', () async {
    final m = await MapaOffline.abrir();
    expect(m.lembrete(hoje), LembreteMapa.baixar);
  });

  test('"Agora não" esconde por uma semana', () async {
    final m = await MapaOffline.abrir();
    await m.adiar(hoje);
    expect(m.lembrete(hoje.add(const Duration(days: 6))), LembreteMapa.nenhum);
    expect(m.lembrete(hoje.add(const Duration(days: 7))), LembreteMapa.baixar);
  });

  test('depois de baixar, só pede para conferir após 6 meses', () async {
    final m = await MapaOffline.abrir();
    await m.adiar(hoje);
    await m.marcarBaixado(hoje);
    expect(m.lembrete(hoje), LembreteMapa.nenhum);
    expect(
      m.lembrete(hoje.add(const Duration(days: 179))),
      LembreteMapa.nenhum,
    );
    expect(
      m.lembrete(hoje.add(const Duration(days: 180))),
      LembreteMapa.conferir,
    );
    // Conferiu: zera a contagem.
    await m.marcarBaixado(hoje.add(const Duration(days: 180)));
    expect(
      m.lembrete(hoje.add(const Duration(days: 200))),
      LembreteMapa.nenhum,
    );
  });

  test('endereço vira o link do app de mapas de cada sistema', () {
    const e = 'Av. Alfredo Balena, 400, Belo Horizonte - MG';
    expect(
      uriDoMapa(e, TargetPlatform.android).toString(),
      'geo:0,0?q=Av.%20Alfredo%20Balena%2C%20400%2C%20Belo%20Horizonte%20-%20MG',
    );
    final ios = uriDoMapa(e, TargetPlatform.iOS);
    expect(ios.host, 'maps.apple.com');
    expect(ios.queryParameters['q'], e);
    final outro = uriDoMapa(e, TargetPlatform.linux);
    expect(outro.host, 'www.google.com');
    expect(outro.queryParameters['query'], e);
  });
}
