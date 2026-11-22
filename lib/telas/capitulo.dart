import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../dados/conteudo.dart';

class TelaCapitulo extends StatelessWidget {
  const TelaCapitulo({super.key, required this.capitulo});

  final Capitulo capitulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(capitulo.titulo)),
      body: FutureBuilder<String>(
        future: carregarCapitulo(capitulo),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro ao abrir o capítulo: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Markdown(
            data: snap.data!,
            padding: const EdgeInsets.all(16),
            selectable: true,
          );
        },
      ),
    );
  }
}
