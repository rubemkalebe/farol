import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../dados/busca.dart';
import '../dados/secoes.dart';
import '../tema.dart';
import 'secoes.dart';
import 'largura.dart';

class TelaBusca extends StatefulWidget {
  const TelaBusca({super.key});

  @override
  State<TelaBusca> createState() => _TelaBuscaState();
}

class _TelaBuscaState extends State<TelaBusca> {
  late final Future<Busca> _busca = _carregar();
  String _consulta = '';

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
          onChanged: (v) => setState(() => _consulta = v),
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
          if (resultados.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nada encontrado. Tente outra palavra, ou use o botão de emergência na tela inicial.',
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
              ],
            ),
          );
        },
      ),
    );
  }
}
