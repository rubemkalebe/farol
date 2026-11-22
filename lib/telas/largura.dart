import 'package:flutter/material.dart';

/// Largura máxima de leitura. Em tablet, celular deitado ou computador, o
/// conteúdo fica centralizado em vez de esticar de ponta a ponta (linhas
/// longas demais cansam a leitura). Em celular de pé não muda nada.
const larguraMaxima = 720.0;

class LarguraLeitura extends StatelessWidget {
  const LarguraLeitura({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: larguraMaxima),
      child: child,
    ),
  );
}
