import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dados/estante.dart';
import '../tema.dart';
import 'largura.dart';

/// Manuais em PDF para recomeçar, por tema. Cada um é baixado do site de
/// quem publicou e fica no celular para ler sem internet.
class TelaEstante extends StatefulWidget {
  const TelaEstante({super.key});

  @override
  State<TelaEstante> createState() => _TelaEstanteState();
}

class _TelaEstanteState extends State<TelaEstante> {
  final _estante = Estante.instancia;
  final _temas = carregarEstante();
  late Future<Set<String>> _baixados = _estante.baixados();

  @override
  void initState() {
    super.initState();
    _estante.addListener(_mudou);
  }

  @override
  void dispose() {
    _estante.removeListener(_mudou);
    super.dispose();
  }

  void _mudou() {
    if (!mounted) return;
    setState(() => _baixados = _estante.baixados());
  }

  Future<void> _apagar(ManualPdf m) async {
    final sim = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apagar "${m.titulo}"?'),
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
    if (sim == true) await _estante.apagar(m);
  }

  Future<void> _abrir(ManualPdf m) async {
    final f = await _estante.arquivo(m);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TelaPdf(manual: m, caminho: f.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Manuais para recomeçar')),
      body: FutureBuilder<List<(String, List<ManualPdf>)>>(
        future: _temas,
        builder: (context, temas) {
          if (temas.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Não deu para abrir a lista: ${temas.error}'),
            );
          }
          if (!temas.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return FutureBuilder<Set<String>>(
            future: _baixados,
            builder: (context, snap) {
              final baixados = snap.data ?? const <String>{};
              return LarguraLeitura(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      'Manuais de órgãos públicos e instituições '
                      'reconhecidas para plantar, criar animais, cuidar da '
                      'água e da saúde quando a ajuda demora. Cada um vem do '
                      'site de quem publicou; baixe pelo Wi-Fi o que quiser '
                      'ter à mão.',
                      style: t.bodyMedium?.copyWith(color: corTextoSuave),
                    ),
                    for (final (tema, manuais) in temas.data!) ...[
                      const SizedBox(height: 20),
                      Text(
                        tema.toUpperCase(),
                        style: t.labelMedium?.copyWith(
                          color: corTextoSuave,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final m in manuais)
                        _CartaoManual(
                          manual: m,
                          baixado: baixados.contains(m.id),
                          download: _estante.downloads[m.id],
                          aoBaixar: () => _estante.baixar(m),
                          aoParar: () => _estante.cancelar(m),
                          aoApagar: () => _apagar(m),
                          aoAbrir: () => _abrir(m),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'O Farol não guarda nem altera estes arquivos: o '
                      'download vem do site de cada órgão, e cada manual '
                      'segue a licença de quem publicou. Conteúdo pode estar '
                      'desatualizado: em emergência, siga os guias do Farol '
                      'e ligue 192.',
                      style: t.bodySmall?.copyWith(color: corTextoSuave),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CartaoManual extends StatelessWidget {
  const _CartaoManual({
    required this.manual,
    required this.baixado,
    required this.download,
    required this.aoBaixar,
    required this.aoParar,
    required this.aoApagar,
    required this.aoAbrir,
  });

  final ManualPdf manual;
  final bool baixado;
  final DownloadPdf? download;
  final VoidCallback aoBaixar;
  final VoidCallback aoParar;
  final VoidCallback aoApagar;
  final VoidCallback aoAbrir;

  static String _mb(int bytes) =>
      '${(bytes / 1048576).toStringAsFixed(1).replaceAll('.', ',')} MB';

  @override
  Widget build(BuildContext context) {
    final m = manual;
    final d = download;
    final Widget acao;
    String? estado;
    if (baixado) {
      acao = Wrap(
        spacing: 4,
        children: [
          TextButton(onPressed: aoApagar, child: const Text('Apagar')),
          FilledButton.tonal(
            key: ValueKey('abrir-${m.id}'),
            onPressed: aoAbrir,
            child: const Text('Abrir'),
          ),
        ],
      );
    } else if (d == null) {
      acao = FilledButton.tonal(
        key: ValueKey('baixar-${m.id}'),
        onPressed: aoBaixar,
        child: Text('Baixar · ${m.tamanho}'),
      );
    } else if (d.estado == EstadoPdf.erro) {
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
      estado = pct == null
          ? 'Baixando… ${_mb(d.recebido)}'
          : 'Baixando… ${(pct * 100).floor()}%';
      acao = TextButton(onPressed: aoParar, child: const Text('Parar'));
    }
    final detalhe = [m.orgao, if (m.ano != null) '${m.ano}'].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    m.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (baixado)
                  const Icon(Icons.check_circle, color: corFeixe, size: 20),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              detalhe,
              style: const TextStyle(color: corFeixe, fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(
              m.descricao,
              style: const TextStyle(color: corTextoSuave, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              m.licenca,
              style: const TextStyle(color: corTextoSuave, fontSize: 11.5),
            ),
            if (d != null && d.estado != EstadoPdf.erro) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: d.progresso),
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

/// Lê o PDF no próprio Farol, com zoom de pinça, e lembra a página onde a
/// pessoa parou.
class TelaPdf extends StatefulWidget {
  const TelaPdf({super.key, required this.manual, required this.caminho});

  final ManualPdf manual;
  final String caminho;

  @override
  State<TelaPdf> createState() => _TelaPdfState();
}

class _TelaPdfState extends State<TelaPdf> {
  PdfControllerPinch? _controle;
  int _pagina = 1;
  int _total = 0;
  Object? _erro;

  String get _chave => 'pdf_pagina_${widget.manual.id}';

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  Future<void> _abrir() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final inicial = prefs.getInt(_chave) ?? 1;
      if (!mounted) return;
      setState(() {
        _pagina = inicial;
        _controle = PdfControllerPinch(
          document: PdfDocument.openFile(widget.caminho),
          initialPage: inicial,
        );
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    }
  }

  Future<void> _guardar(int pagina) async {
    setState(() => _pagina = pagina);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_chave, pagina);
    } catch (_) {
      // Sem onde guardar: só não lembra a página.
    }
  }

  @override
  void dispose() {
    _controle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controle;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.manual.titulo),
        bottom: _total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Página $_pagina de $_total · ${widget.manual.orgao}',
                    style: const TextStyle(color: corTextoSuave, fontSize: 13),
                  ),
                ),
              ),
      ),
      body: _erro != null
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Não deu para abrir o PDF: $_erro. Tente apagar e baixar '
                'de novo.',
              ),
            )
          : c == null
          ? const Center(child: CircularProgressIndicator())
          : PdfViewPinch(
              controller: c,
              onDocumentLoaded: (doc) =>
                  setState(() => _total = doc.pagesCount),
              onPageChanged: _guardar,
              onDocumentError: (e) => setState(() => _erro = e),
              backgroundDecoration: const BoxDecoration(color: corNoite),
            ),
    );
  }
}
