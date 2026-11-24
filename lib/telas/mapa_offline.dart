import 'package:flutter/material.dart';

import '../dados/fontes.dart';
import '../dados/mapa_offline.dart';
import '../dados/marcacoes.dart';
import '../dados/secoes.dart';
import '../tema.dart';
import 'texto_farol.dart';

/// Título da seção do guia "Antes de cair" que ensina a baixar o mapa.
const secaoMapaOffline = 'preparacao/Mapa sem internet';

/// Passo a passo do mapa offline, com "Já baixei" e "Agora não".
/// Devolve true se a pessoa marcou que baixou.
class TelaMapaOffline extends StatefulWidget {
  const TelaMapaOffline({super.key, this.cidade});

  /// Nome da cidade, para o título. Nulo em "Outra cidade".
  final String? cidade;

  @override
  State<TelaMapaOffline> createState() => _TelaMapaOfflineState();
}

class _TelaMapaOfflineState extends State<TelaMapaOffline> {
  late final Future<(List<Secao>, Map<String, Fonte>, Marcacoes, MapaOffline)>
  _dados = (
    secoesDaCidadeEscolhida(),
    carregarFontes(),
    Marcacoes.abrir(),
    MapaOffline.abrir(),
  ).wait;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final onde = widget.cidade == null
        ? 'da sua cidade'
        : 'de ${widget.cidade}';
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa sem internet')),
      body: FutureBuilder(
        future: _dados,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro ao abrir: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (secoes, fontes, marcacoes, mapa) = snap.data!;
          final secao = secoes
              .where((s) => s.chave == secaoMapaOffline)
              .firstOrNull;
          final baixado = mapa.baixadoEm;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Baixe o mapa $onde e o caminho até a família enquanto tem '
                  'internet. Na falta de '
                  'sinal, o GPS continua funcionando e o mapa aparece.',
                  style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (baixado != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Você marcou que baixou em ${_data(baixado)}.',
                    style: t.bodySmall?.copyWith(color: corTextoSuave),
                  ),
                ),
              Expanded(
                child: secao == null
                    ? const SizedBox.shrink()
                    : TextoFarol(
                        markdown: secao.markdown,
                        capituloId: secao.capitulo.id,
                        fontes: fontes,
                        marcacoes: marcacoes,
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        key: const ValueKey('mapa-agora-nao'),
                        onPressed: () async {
                          await mapa.adiar();
                          if (context.mounted) Navigator.pop(context, false);
                        },
                        child: const Text('Agora não'),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('mapa-ja-baixei'),
                        onPressed: () async {
                          await mapa.marcarBaixado();
                          if (context.mounted) Navigator.pop(context, true);
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Já baixei'),
                      ),
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
}

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
