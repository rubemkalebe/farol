import 'package:flutter/material.dart';

import 'dados/preferencias.dart';
import 'telas/inicio.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await carregarTamanhoTexto();
  runApp(const FarolApp());
}

class FarolApp extends StatelessWidget {
  const FarolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Farol',
      debugShowCheckedModeBanner: false,
      // Tema escuro sempre: gasta menos bateria em tela OLED e funciona no escuro.
      theme: temaFarol,
      // Tamanho de letra do app por cima do tamanho do sistema.
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: escalaTexto,
        builder: (context, escala, _) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(mq.textScaler.scale(1) * escala),
            ),
            child: child!,
          );
        },
      ),
      home: const TelaInicio(),
    );
  }
}
