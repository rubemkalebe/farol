import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'passar_adiante.dart';

/// Página de onde se baixa a versão nova.
final paginaVersoes = Uri.parse(
  'https://github.com/rubemkalebe/farol/releases/latest',
);

final _apiVersoes = Uri.parse(
  'https://api.github.com/repos/rubemkalebe/farol/releases/latest',
);

const _canal = MethodChannel('farol/apk');

/// Compara "1.10.0" com "1.9.2" número a número. Aceita "v" na frente e
/// ignora o que vem depois de "+" ou "-".
int compararVersoes(String a, String b) {
  List<int> partes(String v) {
    final limpo = v.trim().replaceFirst(RegExp('^[vV]'), '');
    return [
      for (final p in limpo.split(RegExp('[+-]')).first.split('.'))
        int.tryParse(p) ?? 0,
    ];
  }

  final x = partes(a), y = partes(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// Pergunta ao GitHub qual é a última versão publicada. Só lê a página
/// pública de versões: não manda nada sobre a pessoa nem sobre o celular.
Future<String?> ultimaVersaoPublicada() async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final req = await c.getUrl(_apiVersoes);
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    req.headers.set(HttpHeaders.userAgentHeader, 'Farol');
    final res = await req.close().timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final corpo = await res.transform(utf8.decoder).join();
    final tag = (jsonDecode(corpo) as Map)['tag_name'];
    return tag is String ? tag.replaceFirst(RegExp('^[vV]'), '') : null;
  } catch (_) {
    return null;
  } finally {
    c.close(force: true);
  }
}

/// Versão instalada, como o Android informa.
Future<String?> versaoInstalada() async {
  try {
    return await _canal.invokeMethod<String>('versao');
  } catch (_) {
    return null;
  }
}

/// Avisa quando sai versão nova. Confere no máximo uma vez por semana e
/// só quando há internet; sem internet, fica quieto. Só vale para quem
/// instalou o APK direto: quem instalar por uma loja é atualizado por ela.
class Atualizacao {
  Atualizacao(
    this._prefs, {
    Future<String?> Function()? publicada,
    Future<String?> Function()? instalada,
  }) : _publicada = publicada ?? ultimaVersaoPublicada,
       _instalada = instalada ?? versaoInstalada;

  final SharedPreferences _prefs;
  final Future<String?> Function() _publicada;
  final Future<String?> Function() _instalada;

  static const chaveConferida = 'atualizacao_conferida_em';
  static const chaveNova = 'atualizacao_versao_nova';
  static const chaveDispensada = 'atualizacao_dispensada';

  static const intervalo = Duration(days: 7);

  static Future<Atualizacao?> abrir() async {
    if (!await apkInteiro()) return null;
    return Atualizacao(await SharedPreferences.getInstance());
  }

  /// A versão nova a mostrar, ou nulo. Usa o que já sabe e só pergunta ao
  /// GitHub se faz uma semana desde a última vez.
  Future<String?> versaoNova([DateTime? agora]) async {
    final hoje = agora ?? DateTime.now();
    final conferida = DateTime.tryParse(_prefs.getString(chaveConferida) ?? '');
    if (conferida == null || hoje.difference(conferida) >= intervalo) {
      final v = await _publicada();
      if (v != null) {
        await _prefs.setString(chaveNova, v);
        await _prefs.setString(chaveConferida, hoje.toIso8601String());
      }
    }
    final nova = _prefs.getString(chaveNova);
    final atual = await _instalada();
    if (nova == null || atual == null) return null;
    if (compararVersoes(nova, atual) <= 0) return null;
    if (_prefs.getString(chaveDispensada) == nova) return null;
    return nova;
  }

  /// "Agora não": esconde o aviso até sair uma versão mais nova que esta.
  Future<void> dispensar(String versao) =>
      _prefs.setString(chaveDispensada, versao);
}
