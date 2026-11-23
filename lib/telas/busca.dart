import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../dados/busca.dart';
import '../dados/secoes.dart';
import '../dados/wikipedia.dart';
import '../dados/zim.dart';
import '../tema.dart';
import 'secoes.dart';
import 'largura.dart';
import 'wikipedia.dart';

class TelaBusca extends StatefulWidget {
  const TelaBusca({super.key});

  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  late final Future<Busca> _busca = _carregar();
  String _consulta = '';
  late final Future<bool> _temWiki = Wikipedia.instancia.instalados().then(
    (l) => l.isNotEmpty,
  );
  Future<List<(PacoteWiki, EntradaZim)>>? _wiki;

  void _mudou(String v) => setState(() {
    _consulta = v;
    _wiki = v.trim().isEmpty ? null : Wikipedia.instancia.buscar(v, limite: 5);
  });

  Future<Busca> _carregar() async {
    final (secoes, sinonimos) = await (
      secoesDaCidadeEscolhida(),
      rootBundle.loadString('conteudo/sinonimos.yaml'),
    ).wait;
    return Busca(secoes, lerSinonimos(sinonimos));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'O que aconteceu? Ex.: engasgou, picada, faltou luz',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _mudou,
        ),
      ),
      body: FutureBuilder<Busca>(
        future: _busca,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_consulta.trim().isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Escreva do seu jeito: "meu filho engasgou", "escorpião", "sem luz geladeira"…',
              ),
            );
          }
          final resultados = snap.data!.buscar(_consulta);
          final wiki = _WikiNaBusca(temWiki: _temWiki, resultados: _wiki);
          if (resultados.isEmpty) {
            return LarguraLeitura(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Nada encontrado nos guias. Tente outra palavra, ou use o botão de emergência na tela inicial.',
                    ),
                  ),
                  wiki,
                ],
              ),
            );
          }
          return LarguraLeitura(
            child: ListView(
              children: [
                for (final r in resultados)
                  ListTile(
                    title: Text(
                      r.secao.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.secao.capitulo.titulo,
                          style: const TextStyle(color: corFeixe, fontSize: 12),
                        ),
                        if (r.trecho.isNotEmpty)
                          Text(
                            r.trecho,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TelaSecoes(
                          titulo: r.secao.titulo,
                          secoes: [r.secao],
                        ),
                      ),
                    ),
                  ),
                wiki,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Artigos da Wikipédia com o título buscado, se houver pacote baixado.
class _WikiNaBusca extends StatelessWidget {
  const _WikiNaBusca({required this.temWiki, required this.resultados});

  final Future<bool> temWiki;
  final Future<List<(PacoteWiki, EntradaZim)>>? resultados;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: temWiki,
      builder: (context, snap) {
        if (snap.data != true || resultados == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NA WIKIPÉDIA',
                style: TextStyle(
                  color: corTextoSuave,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 12,
                ),
              ),
              ResultadosWiki(resultados: resultados!),
            ],
          ),
        );
      },
    );
  }
}
