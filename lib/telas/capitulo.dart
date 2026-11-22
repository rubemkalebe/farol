import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../dados/conteudo.dart';
import '../dados/fontes.dart';
import '../tema.dart';

class TelaCapitulo extends StatelessWidget {
  const TelaCapitulo({super.key, required this.capitulo});

  final Capitulo capitulo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(capitulo.titulo)),
      body: FutureBuilder<(String, Map<String, Fonte>)>(
        future: (carregarCapitulo(capitulo), carregarFontes()).wait,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro ao abrir o capítulo: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (texto, fontes) = snap.data!;
          final tema = Theme.of(context);
          return Markdown(
            data: texto,
            extensionSet: md.ExtensionSet(
              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
              [SintaxeFonte(), SintaxeGeral(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
            ),
            builders: {
              'fonte': _BotaoFonte(
                (id) => fontes[id] != null ? _mostrarFonte(context, fontes[id]!) : null,
              ),
              'geral': _MarcaGeral(() => _mostrarAvisoGeral(context)),
            },
            padding: const EdgeInsets.all(16),
            styleSheet: MarkdownStyleSheet.fromTheme(tema).copyWith(
              a: const TextStyle(color: corFeixe, fontWeight: FontWeight.w700),
              blockquoteDecoration: BoxDecoration(
                color: corSuperficie,
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: corFeixe, width: 4)),
              ),
              tableBorder: TableBorder.all(color: tema.dividerColor),
            ),
          );
        },
      ),
    );
  }

  void _mostrarAvisoGeral(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orientação geral',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: corAviso)),
            const SizedBox(height: 6),
            Text(
              'Não encontramos fonte oficial para este ponto. Ele foi escrito com base '
              'em conhecimento técnico comum e pode mudar quando houver uma fonte melhor.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarFonte(BuildContext context, Fonte f) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.orgao, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: corFeixe)),
            const SizedBox(height: 6),
            Text(f.titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SelectableText(f.url, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text('Consultado em ${f.acessado}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Ícone de informação no lugar de `[fonte: id]`. Usa a fonte de ícones
/// embutida no app, então aparece mesmo sem internet.
class _BotaoFonte extends MarkdownElementBuilder {
  _BotaoFonte(this.aoTocar);

  final void Function(String id) aoTocar;

  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    final id = element.textContent;
    return Semantics(
      button: true,
      label: 'Ver fonte',
      child: InkWell(
        key: ValueKey('fonte-$id'),
        onTap: () => aoTocar(id),
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.info_outline, size: 18, color: corFeixe),
        ),
      ),
    );
  }
}

/// Ícone de orientação sem fonte oficial, no lugar de `[geral]`.
class _MarcaGeral extends MarkdownElementBuilder {
  _MarcaGeral(this.aoTocar);

  final VoidCallback aoTocar;

  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    return Semantics(
      button: true,
      label: 'Orientação geral, sem fonte oficial',
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: Icon(Icons.help_outline, size: 18, color: corAviso),
        ),
      ),
    );
  }
}
