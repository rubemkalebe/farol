// Gera os PNGs do ícone a partir do mesmo desenho do logo (FarolLogo).
// Uso: flutter test ferramentas/icone/gerar_icone_test.dart
// Depois: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:farol/tema.dart';
import 'package:farol/telas/farol_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const lado = 1024.0;

// Cor sólida por baixo: com gradient, o BoxDecoration ignora o color.
Widget _fundo() => const ColoredBox(
  color: corNoite,
  child: DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment(0, -0.45),
        radius: 0.9,
        colors: [Color(0x40FFD34E), Color(0x00FFD34E)],
      ),
    ),
    child: SizedBox.expand(),
  ),
);

Future<void> _salvar(WidgetTester t, Widget w, String nome) async {
  final chave = GlobalKey();
  await t.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: chave,
        child: SizedBox.square(dimension: lado, child: w),
      ),
    ),
  );
  await t.runAsync(() async {
    final rb =
        chave.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await rb.toImage();
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('ferramentas/icone/$nome').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('gera ícone', (t) async {
    t.view.physicalSize = const Size(lado, lado);
    t.view.devicePixelRatio = 1;
    // Ícone completo (legado, web, desktop): fundo + farol grande.
    await _salvar(
      t,
      Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: _fundo()),
          const Center(child: FarolLogo(tamanho: lado * 0.78)),
        ],
      ),
      'icone.png',
    );
    // Frente do ícone adaptativo do Android: só o farol, dentro da zona
    // segura (o sistema recorta as bordas em círculo, gota etc.).
    await _salvar(
      t,
      const Center(child: FarolLogo(tamanho: lado * 0.56)),
      'icone_frente.png',
    );
    // Fundo do adaptativo: escuro com o brilho do feixe.
    await _salvar(t, _fundo(), 'icone_fundo.png');
  });
}
