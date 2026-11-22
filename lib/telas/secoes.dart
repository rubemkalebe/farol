import 'package:flutter/material.dart';

import '../dados/fontes.dart';
import '../dados/marcacoes.dart';
import '../dados/secoes.dart';
import '../tema.dart';
import 'capitulo.dart';
import 'ficha.dart' show ligar;
import 'texto_farol.dart';

const _nomes = {'190': 'Polícia', '192': 'SAMU', '193': 'Bombeiros', '199': 'Defesa Civil'};

/// Botões grandes de ligar, para usar no topo das telas de emergência.
class BotoesLigar extends StatelessWidget {
  const BotoesLigar(this.numeros, {super.key});

  final List<String> numeros;

  @override
  Widget build(BuildContext context) {
    if (numeros.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (final (i, n) in numeros.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: ValueKey('ligar-$n'),
                style: FilledButton.styleFrom(
                  backgroundColor: corAlerta,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                onPressed: () => ligar(n),
                icon: const Icon(Icons.phone),
                label: Text(_nomes.containsKey(n) ? '$n ${_nomes[n]}' : n),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mostra só as seções escolhidas (pela busca ou pelo botão de emergência).
class TelaSecoes extends StatefulWidget {
  const TelaSecoes({super.key, required this.titulo, required this.secoes, this.ligar = const []});

  final String titulo;
  final List<Secao> secoes;
  final List<String> ligar;

  @override
  State<TelaSecoes> createState() => _TelaSecoesState();
}

class _TelaSecoesState extends State<TelaSecoes> {
  late final Future<(Map<String, Fonte>, Marcacoes)> _dados = (carregarFontes(), Marcacoes.abrir()).wait;

  @override
  Widget build(BuildContext context) {
    final texto = widget.secoes.map((s) => '## ${s.titulo}\n\n${s.markdown}').join('\n\n---\n\n');
    final capitulo = widget.secoes.first.capitulo;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          BotoesLigar(widget.ligar),
          Expanded(
            child: FutureBuilder(
              future: _dados,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final (fontes, marcacoes) = snap.data!;
                return TextoFarol(markdown: texto, capituloId: capitulo.id, fontes: fontes, marcacoes: marcacoes);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => TelaCapitulo(capitulo: capitulo))),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text('Abrir o guia completo: ${capitulo.titulo}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
