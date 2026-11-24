import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../dados/artigo_wiki.dart';
import '../dados/wikipedia.dart';
import '../dados/zim.dart';
import '../tema.dart';
import 'compartilhar.dart';
import 'estante.dart';
import 'largura.dart';

const _credito =
    'Wikipédia, Vikidia e demais projetos Wiki: licença CC BY-SA. Livros do '
    'Projeto Gutenberg: domínio público. Tudo empacotado pelo Kiwix. Pode '
    'estar desatualizado ou ter erros: em emergência, siga os guias do '
    'Farol e ligue 192.';

String _creditoDe(PacoteWiki p) =>
    'Conteúdo: ${p.fonte}, ${p.licenca == 'domínio público'
        ? 'em domínio público'
        : p.licenca.startsWith('©')
        ? p.licenca
        : 'licença ${p.licenca}'}, '
    'empacotado pelo Kiwix. Pode estar desatualizado ou ter erros: em '
    'emergência, siga os guias do Farol e ligue 192.';

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
      if (_termo.isNotEmpty) {
        _resultados = _wiki.buscar(_termo, biblioteca: true);
      }
    });
  }

  void _buscar(String v) => setState(() {
    _termo = v.trim();
    _resultados = _termo.isEmpty
        ? null
        : _wiki.buscar(_termo, biblioteca: true);
  });

  /// Abre a página inicial do pacote (na Wikipédia, a lista de artigos;
  /// no iFixit, as categorias de aparelhos), para navegar sem saber o nome
  /// do que procurar.
  Future<void> _abrirInicio(PacoteWiki p) async {
    try {
      final zim = await _wiki.abrir(p);
      final inicio = await zim.paginaInicial();
      if (mounted) abrirArtigoWiki(context, p, inicio);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não deu para abrir o pacote: $e')),
      );
    }
  }

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

  Widget _cartao(PacoteWiki p, List<PacoteWiki> instalados) => _CartaoPacote(
    pacote: p,
    instalado: instalados.contains(p),
    download: _wiki.downloads[p.id],
    aoBaixar: () => _wiki.baixar(p),
    aoParar: () => _wiki.cancelar(p),
    aoApagar: () => _apagar(p),
    aoListar: p.pasta == 'gutenberg'
        ? () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => TelaListaPacote(pacote: p)))
        : p.temInicio
        ? () => _abrirInicio(p)
        : null,
    textoListar: p.temInicio ? 'Abrir' : 'Ver todos',
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Biblioteca sem internet')),
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
                      hintText: 'Buscar pelo título. Ex.: dengue, Dom Casmurro',
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
                      'Sem internet, o celular não abre a Wikipédia nem '
                      'livros. Baixe agora o que quiser ler depois, mesmo '
                      'num apagão longo.',
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                Card(
                  child: ListTile(
                    key: const ValueKey('abrir-estante'),
                    leading: const Icon(Icons.menu_book, color: corFeixe),
                    title: const Text(
                      'Manuais para recomeçar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'PDFs de órgãos públicos: plantar, criar animais, '
                      'água, saneamento, saúde sem médico.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TelaEstante()),
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    key: const ValueKey('abrir-compartilhar'),
                    leading: const Icon(Icons.wifi_tethering, color: corFeixe),
                    title: const Text(
                      'Passar para outro celular',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: const Text(
                      'Sem internet: manda ou recebe a biblioteca e os '
                      'manuais pelo Wi-Fi do celular.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TelaCompartilhar(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'WIKIPÉDIA',
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
                for (final p in pacotesWiki.where((p) => p.daWikipedia))
                  _cartao(p, instalados),
                const SizedBox(height: 20),
                Text(
                  'BIBLIOTECA',
                  style: t.labelMedium?.copyWith(
                    color: corTextoSuave,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Para ler, estudar e passar o tempo se a falta de energia '
                  'durar muito. Todos opcionais.',
                  style: t.bodySmall?.copyWith(color: corTextoSuave),
                ),
                const SizedBox(height: 10),
                for (final p in pacotesWiki.where((p) => !p.daWikipedia))
                  _cartao(p, instalados),
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
    this.aoListar,
    this.textoListar = 'Ver todos',
  });

  final PacoteWiki pacote;
  final VoidCallback? aoListar;
  final String textoListar;
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
      estado =
          'Baixado: toque em $textoListar ou busque pelo título lá em cima';
      acao = Wrap(
        spacing: 4,
        children: [
          TextButton(onPressed: aoApagar, child: const Text('Apagar')),
          if (aoListar != null)
            FilledButton.tonal(
              key: ValueKey('listar-${pacote.id}'),
              onPressed: aoListar,
              child: Text(textoListar),
            ),
        ],
      );
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
                  e.tituloLegivel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  p.daWikipedia ? 'Wikipédia · ${p.titulo}' : p.titulo,
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

(String, List<String>) _limpar((String, String, bool) a) {
  final artigo = limparArtigo(a.$1, tituloPadrao: a.$2, imagens: a.$3);
  return (artigo.titulo, dividirEmPartes(artigo.corpo));
}

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
  late final Future<(String, List<String>)> _artigo = _carregar();
  int _parte = 0;

  Future<(String, List<String>)> _carregar() async {
    final zim = await Wikipedia.instancia.abrir(widget.pacote);
    final bytes = await zim.conteudo(widget.entrada);
    final pagina = utf8.decode(bytes, allowMalformed: true);
    // Artigos grandes passam de 300 mil caracteres: limpa fora da tela.
    return compute(_limpar, (
      pagina,
      widget.entrada.tituloLegivel,
      widget.pacote.comImagens,
    ));
  }

  Future<bool> _link(String url) async {
    if (!url.startsWith(esquemaWiki)) return true;
    final caminho = url.substring(esquemaWiki.length);
    final zim = await Wikipedia.instancia.abrir(widget.pacote);
    final atual = (await zim.resolver(widget.entrada)).url;
    final e =
        await zim.artigo(resolverCaminho(atual, caminho)) ??
        await zim.artigo(caminho);
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
      appBar: AppBar(title: Text(widget.entrada.tituloLegivel)),
      body: FutureBuilder<(String, List<String>)>(
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
          final (titulo, partes) = snap.data!;
          final n = partes.length;
          final esc = const HtmlEscape().convert;
          final origem = widget.pacote.daWikipedia
              ? 'Wikipédia · ${widget.pacote.titulo}'
              : widget.pacote.titulo;
          final html = StringBuffer()
            ..write('<h1>${esc(titulo)}</h1>')
            ..write(
              '<p class="farol-fonte">${esc(origem)}'
              '${n > 1 ? ' · parte ${_parte + 1} de $n' : ''}</p>',
            )
            ..write(partes[_parte]);
          if (_parte == n - 1) {
            html.write(
              '<hr><p class="farol-fonte">${esc(_creditoDe(widget.pacote))}</p>',
            );
          }
          final leitor = LarguraLeitura(
            child: HtmlWidget(
              html.toString(),
              key: ValueKey(_parte),
              renderMode: const ListViewMode(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
              ),
              textStyle: t.bodyLarge?.copyWith(height: 1.5),
              onTapUrl: _link,
              customWidgetBuilder: (e) {
                final src = e.attributes['src'] ?? '';
                if (e.localName != 'img' || !src.startsWith(esquemaImagem)) {
                  return null;
                }
                return _ImagemZim(
                  pacote: widget.pacote,
                  artigo: widget.entrada,
                  caminho: src.substring(esquemaImagem.length),
                  descricao: e.attributes['alt'] ?? '',
                );
              },
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
          if (n == 1) return leitor;
          return Column(
            children: [
              Expanded(child: leitor),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _parte == 0
                            ? null
                            : () => setState(() => _parte--),
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Anterior'),
                      ),
                      Expanded(
                        child: Text(
                          'Parte ${_parte + 1} de $n',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: corTextoSuave),
                        ),
                      ),
                      TextButton.icon(
                        key: const ValueKey('proxima-parte'),
                        onPressed: _parte == n - 1
                            ? null
                            : () => setState(() => _parte++),
                        icon: const Icon(Icons.chevron_right),
                        label: const Text('Próxima'),
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

/// Foto ou figura guardada dentro do arquivo ZIM, carregada só quando o
/// artigo abre. Se não achar ou não decodificar, some sem erro na tela.
class _ImagemZim extends StatefulWidget {
  const _ImagemZim({
    required this.pacote,
    required this.artigo,
    required this.caminho,
    required this.descricao,
  });

  final PacoteWiki pacote;
  final EntradaZim artigo;
  final String caminho;
  final String descricao;

  @override
  State<_ImagemZim> createState() => _ImagemZimState();
}

class _ImagemZimState extends State<_ImagemZim> {
  late final Future<Uint8List?> _bytes = _carregar();

  Future<Uint8List?> _carregar() async {
    try {
      final zim = await Wikipedia.instancia.abrir(widget.pacote);
      final atual = (await zim.resolver(widget.artigo)).url;
      final caminho = resolverCaminho(atual, widget.caminho);
      final e =
          await zim.porUrl('C', caminho) ??
          await zim.porUrl('I', caminho) ??
          await zim.porUrl('C', widget.caminho) ??
          await zim.porUrl('I', widget.caminho);
      return e == null ? null : await zim.conteudo(e);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 48);
        }
        final bytes = snap.data;
        if (bytes == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image(
              // Foto grande ocupa muita memória: decodifica no máximo com
              // 900 px de largura, sem aumentar as pequenas.
              image: ResizeImage(
                MemoryImage(bytes),
                width: 900,
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.contain,
              semanticLabel: widget.descricao.isEmpty ? null : widget.descricao,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

/// Lista completa de um pacote (os livros do Gutenberg), com filtro.
class TelaListaPacote extends StatefulWidget {
  const TelaListaPacote({super.key, required this.pacote});

  final PacoteWiki pacote;

  @override
  State<TelaListaPacote> createState() => _TelaListaPacoteState();
}

class _TelaListaPacoteState extends State<TelaListaPacote> {
  late final Future<List<EntradaZim>> _todos = Wikipedia.instancia
      .abrir(widget.pacote)
      .then((z) => z.todosTitulos());
  String _filtro = '';

  static String _semAcento(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final b = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      final i = de.indexOf(c);
      b.write(i < 0 ? c : para[i]);
    }
    return b.toString().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.pacote.titulo)),
      body: FutureBuilder<List<EntradaZim>>(
        future: _todos,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Não deu para abrir a lista: ${snap.error}'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final f = _semAcento(_filtro);
          final lista = f.isEmpty
              ? snap.data!
              : [
                  for (final e in snap.data!)
                    if (_semAcento(e.tituloLegivel).contains(f)) e,
                ];
          return LarguraLeitura(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    key: const ValueKey('filtro-lista'),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Filtrar ${snap.data!.length} títulos',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _filtro = v.trim()),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(lista[i].tituloLegivel),
                      onTap: () =>
                          abrirArtigoWiki(context, widget.pacote, lista[i]),
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
