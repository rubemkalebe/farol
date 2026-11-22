import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/fontes.dart';
import '../dados/locais.dart';
import '../dados/marcacoes.dart';
import 'texto_farol.dart';

class TelaCapitulo extends StatefulWidget {
  const TelaCapitulo({super.key, required this.capitulo});

  final Capitulo capitulo;

  @override
  State<TelaCapitulo> createState() => _TelaCapituloState();
}

class _TelaCapituloState extends State<TelaCapitulo> {
  // Carregado uma vez só: criar o Future dentro do build refaz a leitura
  // a cada redesenho e a tela fica presa no indicador de carregamento.
  late final Future<(String, Map<String, Fonte>, Marcacoes)> _dados = _carregar();

  Future<(String, Map<String, Fonte>, Marcacoes)> _carregar() async {
    final (bruto, fontes, marcacoes, blocos) =
        await (carregarCapitulo(widget.capitulo), carregarFontes(), Marcacoes.abrir(), blocosDaCidadeEscolhida()).wait;
    return (aplicarLocais(bruto, blocos), fontes, marcacoes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.capitulo.titulo),
        actions: [
          FutureBuilder(
            future: _dados,
            builder: (context, snap) {
              if (!snap.hasData || !temMarcacoes(snap.data!.$1)) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Desmarcar tudo',
                icon: const Icon(Icons.restart_alt),
                onPressed: () => _confirmarLimpeza(snap.data!.$3),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<(String, Map<String, Fonte>, Marcacoes)>(
        future: _dados,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro ao abrir o capítulo: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (texto, fontes, marcacoes) = snap.data!;
          return TextoFarol(markdown: texto, capituloId: widget.capitulo.id, fontes: fontes, marcacoes: marcacoes);
        },
      ),
    );
  }

  Future<void> _confirmarLimpeza(Marcacoes marcacoes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desmarcar tudo?'),
        content: const Text('Todos os itens marcados neste capítulo voltam a ficar em branco.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desmarcar')),
        ],
      ),
    );
    if (ok == true) await marcacoes.limpar(widget.capitulo.id);
  }
}
