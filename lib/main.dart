import 'package:flutter/material.dart';

import 'telas/inicio.dart';
import 'tema.dart';

void main() => runApp(const FarolApp());

class FarolApp extends StatelessWidget {
  const FarolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farol',
      debugShowCheckedModeBanner: false,
      // Tema escuro sempre: gasta menos bateria em tela OLED e funciona no escuro.
      theme: temaFarol,
      home: const TelaInicio(),
    );
  }
}
