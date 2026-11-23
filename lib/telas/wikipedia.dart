import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../dados/artigo_wiki.dart';
import '../dados/wikipedia.dart';
import '../dados/zim.dart';
import '../tema.dart';
import 'largura.dart';

const _credito =
    'Conteúdo da Wikipédia, licença CC BY-SA 4.0, empacotado pelo Kiwix. '
    'Pode estar desatualizado ou ter erros: em emergência, siga os guias do '
    'Farol e ligue 192.';

/// Pacotes da Wikipédia para baixar e busca nos que já estão no aparelho.
class TelaWikipedia extends StatefulWidget {
  const TelaWikipedia({super.key});

  @override
  State<TelaWikipedia> createState() => _TelaWikipediaState();
}

class _TelaWikipediaState extends State<TelaWikipedia> {
  final _wiki = Wikipedia.instancia;
  late Future<List<PacoteWiki>> _instalados = _wiki.instalados();
  String _termo = '';
  Future<List<(PacoteWiki, EntradaZim)>>? _resultados;

  @override
  void initState() {
    super.initState();
    _wiki.addListener(_mudou);
  }

  @override
  void dispose() {
    _wiki.removeListener(_mudou);
    super.dispose();
  }

  void _mudou() {
    if (!mounted) return;
    setState(() {
      _instalados = _wiki.instalados();
      if (_termo.isNotEmpty) _resultados = _wiki.buscar(_termo);
    });
  }

  void _buscar(String v) => setState(() {
    _termo = v.trim();
    _resultados = _termo.isEmpty ? null : _wiki.buscar(_termo);
  });

  Future<void> _apagar(PacoteWiki p) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apagar "${p.titulo}"?'),
        content: const Text(
          'Libera o espaço no celular. Para ler de novo sem internet, '
          'vai ser preciso baixar outra vez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (sim == true) await _wiki.apagar(p);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Wikipédia sem internet')),
      body: FutureBuilder<List<PacoteWiki>>(
        future: _instalados,
        builder: (context, snap) {
          final instalados = snap.data ?? const <PacoteWiki>[];
          return LarguraLeitura(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (instalados.isNotEmpty) ...[
                  TextField(
                    key: const ValueKey('busca-wiki'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar artigo. Ex.: dengue, hipotermia',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _buscar,
                  ),
                  if (_resultados != null)
                    ResultadosWiki(resultados: _resultados!),
                  const SizedBox(height: 20),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Sem internet, o celular não abre a Wikipédia. Baixe '
                      'agora um pacote para ler depois, mesmo no apagão.',
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                Text(
                  'PACOTES',
                  style: t.labelMedium?.copyWith(
                    color: corTextoSuave,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Baixe pelo Wi-Fi e deixe o Farol aberto até terminar. Se a '
                  'conexão cair, o download continua de onde parou.',
                  style: t.bodySmall?.copyWith(color: corTextoSuave),
                ),
                const SizedBox(height: 10),
                for (final p in pacotesWiki)
                  _CartaoPacote(
                    pacote: p,
                    instalado: instalados.contains(p),
                    download: _wiki.downloads[p.id],
                    aoBaixar: () => _wiki.baixar(p),
                    aoParar: () => _wiki.cancelar(p),
                    aoApagar: () => _apagar(p),
                  ),
                const SizedBox(height: 16),
                Text(
                  _credito,
                  style: t.bodySmall?.copyWith(color: corTextoSuave),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CartaoPacote extends StatelessWidget {
  const _CartaoPacote({
    required this.pacote,
    required this.instalado,
    required this.download,
    required this.aoBaixar,
    required this.aoParar,
    required this.aoApagar,
  });

  final PacoteWiki pacote;
  final bool instalado;
  final Download? download;
  final VoidCallback aoBaixar;
  final VoidCallback aoParar;
  final VoidCallback aoApagar;

  @override
  Widget build(BuildContext context) {
    final d = download;
    final Widget acao;
    final String? estado;
    if (instalado) {
      estado = 'Baixado: funciona sem internet';
      acao = TextButton(onPressed: aoApagar, child: const Text('Apagar'));
    } else if (d == null) {
      estado = null;
      acao = FilledButton.tonal(
        key: ValueKey('baixar-${pacote.id}'),
        onPressed: aoBaixar,
        child: Text('Baixar · ${pacote.tamanho}'),
      );
    } else if (d.estado == EstadoDownload.erro) {
      estado = d.erro;
      acao = Wrap(
        spacing: 4,
        children: [
          TextButton(onPressed: aoParar, child: const Text('Deixar')),
          FilledButton.tonal(
            onPressed: () {
              aoParar();
              aoBaixar();
            },
            child: const Text('Continuar'),
          ),
        ],
      );
    } else {
      final pct = d.progresso;
      estado = d.estado == EstadoDownload.conferindo
          ? 'Conferindo o arquivo…'
          : pct == null
          ? 'Baixando… ${_mb(d.recebido)}'
          : 'Baixando… ${(pct * 100).floor()}% (${_mb(d.recebido)} de ${_mb(d.total!)})';
      acao = TextButton(onPressed: aoParar, child: const Text('Parar'));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pacote.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (pacote.sugerido && !instalado)
                  const Text(
                    'SUGERIDO',
                    style: TextStyle(
                      color: corFeixe,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                if (instalado)
                  const Icon(Icons.check_circle, color: corFeixe, size: 20),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              pacote.descricao,
              style: const TextStyle(color: corTextoSuave, fontSize: 13),
            ),
            if (d != null && d.estado != EstadoDownload.erro) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: d.estado == EstadoDownload.conferindo
                    ? null
                    : d.progresso,
              ),
            ],
            if (estado != null) ...[
              const SizedBox(height: 6),
              Text(estado, style: const TextStyle(fontSize: 13)),
            ],
            Align(alignment: Alignment.centerRight, child: acao),
          ],
        ),
      ),
    );
  }
}

String _mb(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb >= 1024
      ? '${(mb / 1024).toStringAsFixed(1).replaceAll('.', ',')} GB'
      : '${mb.round()} MB';
}

/// Lista de artigos achados, usada aqui e na busca geral do Farol.
class ResultadosWiki extends StatelessWidget {
  const ResultadosWiki({super.key, required this.resultados});

  final Future<List<(PacoteWiki, EntradaZim)>> resultados;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<(PacoteWiki, EntradaZim)>>(
      future: resultados,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }
        if (snap.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Nenhum artigo com esse título nos pacotes baixados.',
              style: TextStyle(color: corTextoSuave),
            ),
          );
        }
        return Column(
          children: [
            for (final (p, e) in snap.data!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.menu_book_outlined, color: corFeixe),
                title: Text(
                  e.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Wikipédia · ${p.titulo}',
                  style: const TextStyle(fontSize: 12, color: corTextoSuave),
                ),
                onTap: () => abrirArtigoWiki(context, p, e),
              ),
          ],
        );
      },
    );
  }
}

void abrirArtigoWiki(BuildContext context, PacoteWiki p, EntradaZim e) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TelaArtigoWiki(pacote: p, entrada: e),
    ),
  );
}

ArtigoLimpo _limpar((String, String) a) =>
    limparArtigo(a.$1, tituloPadrao: a.$2);

class TelaArtigoWiki extends StatefulWidget {
  const TelaArtigoWiki({
    super.key,
    required this.pacote,
    required this.entrada,
  });

  final PacoteWiki pacote;
  final EntradaZim entrada;

  @override
  State<TelaArtigoWiki> createState() => _TelaArtigoWikiState();
}

class _TelaArtigoWikiState extends State<TelaArtigoWiki> {
  late final Future<ArtigoLimpo> _artigo = _carregar();

  Future<ArtigoLimpo> _carregar() async {
    final zim = await Wikipedia.instancia.abrir(widget.pacote);
    final bytes = await zim.conteudo(widget.entrada);
    final pagina = utf8.decode(bytes, allowMalformed: true);
    // Artigos grandes passam de 300 mil caracteres: limpa fora da tela.
    return compute(_limpar, (pagina, widget.entrada.titulo));
  }

  Future<bool> _link(String url) async {
    if (!url.startsWith(esquemaWiki)) return true;
    final caminho = url.substring(esquemaWiki.length);
    final zim = await Wikipedia.instancia.abrir(widget.pacote);
    final e = await zim.artigo(caminho);
    if (!mounted) return true;
    if (e == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esse artigo não está neste pacote.')),
      );
    } else {
      abrirArtigoWiki(context, widget.pacote, e);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.entrada.titulo)),
      body: FutureBuilder<ArtigoLimpo>(
        future: _artigo,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Não deu para abrir o artigo: ${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final a = snap.data!;
          return LarguraLeitura(
            child: HtmlWidget(
              '<h1>${const HtmlEscape().convert(a.titulo)}</h1>'
              '<p class="farol-fonte">Wikipédia · ${const HtmlEscape().convert(widget.pacote.titulo)}</p>'
              '${a.corpo}'
              '<hr><p class="farol-fonte">${const HtmlEscape().convert(_credito)}</p>',
              renderMode: const ListViewMode(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
              ),
              textStyle: t.bodyLarge?.copyWith(height: 1.5),
              onTapUrl: _link,
              customStylesBuilder: (e) => switch (e.localName) {
                'a' => {'color': '#FFD34E', 'text-decoration': 'underline'},
                'h1' => {'font-size': '1.6em', 'margin': '0 0 4px 0'},
                'h2' => {'color': '#FFD34E', 'margin-top': '20px'},
                'table' => {'border-collapse': 'collapse'},
                'td' ||
                'th' => {'border': '1px solid #3A3F4B', 'padding': '4px 6px'},
                'p' when e.classes.contains('farol-fonte') => {
                  'color': '#9AA5B5',
                  'font-size': '0.85em',
                },
                _ => null,
              },
            ),
          );
        },
      ),
    );
  }
}
