import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Farol desenhado em código: não precisa de imagem nem de internet.
class FarolLogo extends StatelessWidget {
  const FarolLogo({super.key, this.tamanho = 56});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: tamanho, child: CustomPaint(painter: _PintorFarol()));
  }
}

class _PintorFarol extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final luz = Offset(w * 0.5, h * 0.27);

    // Feixes para os dois lados, saindo da lanterna.
    final feixe = Paint()
      ..shader = RadialGradient(
        colors: [corFeixe.withValues(alpha: 0.55), corFeixe.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: luz, radius: w * 0.6));
    for (final lado in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(luz.dx, luz.dy)
          ..lineTo(luz.dx + lado * w * 0.62, luz.dy - h * 0.16)
          ..lineTo(luz.dx + lado * w * 0.62, luz.dy + h * 0.12)
          ..close(),
        feixe,
      );
    }

    // Torre: trapézio com faixas.
    final torre = Path()
      ..moveTo(w * 0.40, h * 0.36)
      ..lineTo(w * 0.60, h * 0.36)
      ..lineTo(w * 0.66, h * 0.92)
      ..lineTo(w * 0.34, h * 0.92)
      ..close();
    canvas.drawPath(torre, Paint()..color = corTexto);
    canvas.save();
    canvas.clipPath(torre);
    final faixa = Paint()..color = corAlerta;
    for (final y in [0.48, 0.70]) {
      canvas.drawRect(Rect.fromLTWH(0, h * y, w, h * 0.09), faixa);
    }
    canvas.restore();

    // Lanterna, telhado e base.
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.41, h * 0.21, w * 0.18, h * 0.13), Radius.circular(w * 0.03)),
      Paint()..color = corFeixe,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.37, h * 0.22)
        ..lineTo(w * 0.5, h * 0.10)
        ..lineTo(w * 0.63, h * 0.22)
        ..close(),
      Paint()..color = corTexto,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.26, h * 0.90, w * 0.48, h * 0.06), Radius.circular(w * 0.02)),
      Paint()..color = corTextoSuave,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Brilho suave do feixe atrás do topo da tela inicial.
class BrilhoFeixe extends StatelessWidget {
  const BrilhoFeixe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.85, -1.0),
          radius: 1.3,
          colors: [Color(0x26FFD34E), Color(0x00FFD34E)],
          transform: GradientRotation(math.pi / 10),
        ),
      ),
      child: child,
    );
  }
}
