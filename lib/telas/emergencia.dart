import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../dados/emergencia.dart';
import '../dados/secoes.dart';
import '../tema.dart';
import 'secoes.dart';

Future<Map<String, Pergunta>>? _roteiro;
Future<Map<String, Pergunta>> carregarRoteiro() =>
    _roteiro ??= rootBundle.loadString('conteudo/emergencia.yaml').then(lerRoteiro);

/// "O que está acontecendo?": botões grandes, uma pergunta por tela.
class TelaEmergencia extends StatelessWidget {
  const TelaEmergencia({super.key, this.perguntaId = 'inicio'});

  final String perguntaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergência')),
      body: FutureBuilder<Map<String, Pergunta>>(
        future: carregarRoteiro(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final p = snap.data![perguntaId]!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (perguntaId == 'inicio') ...[
                const BotoesLigar(['192', '193']),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('Em perigo de vida, ligue primeiro.', style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(p.texto,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              for (final o in p.opcoes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      side: const BorderSide(color: corFeixe, width: 1.5),
                      foregroundColor: corTexto,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => _escolher(context, o),
                    child: Row(
                      children: [
                        Expanded(child: Text(o.texto)),
                        const Icon(Icons.chevron_right, color: corFeixe),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _escolher(BuildContext context, Opcao o) async {
    final nav = Navigator.of(context);
    if (o.vai != null) {
      nav.push(MaterialPageRoute(builder: (_) => TelaEmergencia(perguntaId: o.vai!)));
      return;
    }
    final todas = await secoesDaCidadeEscolhida();
    final porChave = {for (final s in todas) s.chave: s};
    final escolhidas = [for (final k in o.secoes) ?porChave[k]];
    if (escolhidas.isEmpty) return;
    nav.push(MaterialPageRoute(
      builder: (_) => TelaSecoes(titulo: o.texto, secoes: escolhidas, ligar: o.ligar),
    ));
  }
}
