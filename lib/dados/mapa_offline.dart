import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lembrete do mapa offline. O Farol não tem mapa próprio: quem guarda o
/// mapa é o app de mapas do celular. Como nenhum app de mapas deixa outro
/// app saber se a área foi baixada, vale o que a pessoa marcou aqui.
class MapaOffline {
  MapaOffline._(this._prefs);

  final SharedPreferences _prefs;

  static const chaveBaixado = 'mapa_offline_baixado_em';
  static const chaveAdiado = 'mapa_offline_adiado_em';

  /// Depois disso, pede para conferir se o mapa ainda está no celular.
  static const conferirApos = Duration(days: 180);

  /// "Agora não" esconde o lembrete por este tempo.
  static const adiarPor = Duration(days: 7);

  static Future<MapaOffline> abrir() async =>
      MapaOffline._(await SharedPreferences.getInstance());

  DateTime? _data(String chave) {
    final s = _prefs.getString(chave);
    return s == null ? null : DateTime.tryParse(s);
  }

  DateTime? get baixadoEm => _data(chaveBaixado);

  Future<void> marcarBaixado([DateTime? agora]) async {
    await _prefs.setString(
      chaveBaixado,
      (agora ?? DateTime.now()).toIso8601String(),
    );
    await _prefs.remove(chaveAdiado);
  }

  Future<void> adiar([DateTime? agora]) => _prefs.setString(
    chaveAdiado,
    (agora ?? DateTime.now()).toIso8601String(),
  );

  /// O que a tela inicial deve mostrar agora.
  LembreteMapa lembrete([DateTime? agora]) {
    final hoje = agora ?? DateTime.now();
    final adiado = _data(chaveAdiado);
    if (adiado != null && hoje.difference(adiado) < adiarPor) {
      return LembreteMapa.nenhum;
    }
    final baixado = baixadoEm;
    if (baixado == null) return LembreteMapa.baixar;
    if (hoje.difference(baixado) >= conferirApos) return LembreteMapa.conferir;
    return LembreteMapa.nenhum;
  }
}

enum LembreteMapa { nenhum, baixar, conferir }

/// Endereço para o app de mapas do celular. Sem internet, só aparece o mapa
/// se a área tiver sido baixada antes; a busca pelo endereço pode não achar,
/// mas o app abre.
@visibleForTesting
Uri uriDoMapa(String endereco, TargetPlatform plataforma) {
  switch (plataforma) {
    case TargetPlatform.android:
      // geo: abre o app de mapas padrão (ou pergunta qual usar).
      return Uri.parse('geo:0,0?q=${Uri.encodeComponent(endereco)}');
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return Uri.https('maps.apple.com', '/', {'q': endereco});
    default:
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': endereco,
      });
  }
}

Future<void> abrirNoMapa(String endereco) => launchUrl(
  uriDoMapa(endereco, defaultTargetPlatform),
  mode: LaunchMode.externalApplication,
);
