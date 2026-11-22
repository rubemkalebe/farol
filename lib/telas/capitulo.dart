import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/fontes.dart';
import '../dados/locais.dart';
import '../dados/marcacoes.dart';
import '../tema.dart';
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
  late final Future<(String, Map<String, Fonte>, Marcacoes)> _dados =
      _carregar();

  Future<(String, Map<String, Fonte>, Marcacoes)> _carregar() async {
    final (bruto, fontes, marcacoes, blocos) = await (
      carregarCapitulo(widget.capitulo),
      carregarFontes(),
      Marcacoes.abrir(),
      blocosDaCidadeEscolhida(),
    ).wait;
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
              if (!snap.hasData || !temMarcacoes(snap.data!.$1)) {
                return const SizedBox.shrink();
              }
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
            return Center(
              child: Text('Erro ao abrir o capítulo: ${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (texto, fontes, marcacoes) = snap.data!;
          final itens = itensDeChecklist(texto);
          return Column(
            children: [
              if (itens.isNotEmpty)
                _Progresso(
                  capitulo: widget.capitulo.id,
                  itens: itens,
                  marcacoes: marcacoes,
                ),
              Expanded(
                child: TextoFarol(
                  markdown: texto,
                  capituloId: widget.capitulo.id,
                  fontes: fontes,
                  marcacoes: marcacoes,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmarLimpeza(Marcacoes marcacoes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desmarcar tudo?'),
        content: const Text(
          'Todos os itens marcados neste capítulo voltam a ficar em branco.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desmarcar'),
          ),
        ],
      ),
    );
    if (ok == true) await marcacoes.limpar(widget.capitulo.id);
  }
}

/// "12 de 62 prontos", com barra, no topo dos capítulos com checklist.
class _Progresso extends StatelessWidget {
  const _Progresso({
    required this.capitulo,
    required this.itens,
    required this.marcacoes,
  });

  final String capitulo;
  final List<String> itens;
  final Marcacoes marcacoes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: marcacoes,
      builder: (context, _) {
        final feitos = itens
            .where((i) => marcacoes.marcado(capitulo, i))
            .length;
        final tudo = feitos == itens.length;
        // Faixa fixa de largura total, com borda embaixo: o texto rola por
        // baixo dela sem parecer um cartão cortado.
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          decoration: BoxDecoration(
            color: corNoite,
            border: Border(
              bottom: BorderSide(color: tudo ? corFeixe : corBorda),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tudo ? 'Tudo pronto!' : '$feitos de ${itens.length} prontos',
                key: const ValueKey('progresso'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: feitos / itens.length,
                  minHeight: 8,
                  backgroundColor: corSuperficieAlta,
                  color: corFeixe,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
