import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// "Passar o Farol adiante": o próprio app instalado vira um arquivo .apk
/// que dá para mandar por Quick Share ou Bluetooth, sem internet.
/// Só no Android: o iPhone não instala app fora da App Store.
bool get podePassarAdiante =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _canal = MethodChannel('farol/apk');

/// Se o app instalado é um APK inteiro, que dá para mandar e instalar em
/// outro celular. Instalado pela loja em partes, não é: aí a opção some.
Future<bool> apkInteiro() async {
  if (!podePassarAdiante) return false;
  try {
    final info = await _canal.invokeMapMethod<String, Object?>('apk');
    return info != null && info['dividido'] != true;
  } catch (_) {
    return false;
  }
}

class ApkDividido implements Exception {
  const ApkDividido();
}

/// Copia o APK instalado para a pasta temporária com o nome Farol.apk
/// e devolve o caminho. Instalado pela loja em partes (App Bundle), o
/// arquivo principal sozinho não instala: aí lança [ApkDividido].
Future<String> prepararApk() async {
  final info = await _canal.invokeMapMethod<String, Object?>('apk');
  if (info == null) throw const ApkDividido();
  if (info['dividido'] == true) throw const ApkDividido();
  final origem = File(info['caminho']! as String);
  final pasta = await getTemporaryDirectory();
  final destino = File('${pasta.path}/Farol.apk');
  if (await destino.exists() &&
      await destino.length() == await origem.length() &&
      (await destino.lastModified()).isAfter(await origem.lastModified())) {
    return destino.path;
  }
  await origem.copy(destino.path);
  return destino.path;
}
