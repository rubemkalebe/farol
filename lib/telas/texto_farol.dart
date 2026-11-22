import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../dados/fontes.dart';
import '../dados/marcacoes.dart';
import '../tema.dart';
import 'ficha.dart' show ligar;

/// Texto de um guia: Markdown com ícones de fonte, orientação geral,
/// caixas de checklist e telefones tocáveis. Usado no capítulo inteiro, na
/// seção aberta pela busca e no fluxo de emergência.
class TextoFarol extends StatelessWidget {
  const TextoFarol({
    super.key,
    required this.markdown,
    required this.capituloId,
    required this.fontes,
    required this.marcacoes,
    this.padding = const EdgeInsets.all(16),
  });

  final String markdown;
  final String capituloId;
  final Map<String, Fonte> fontes;
  final Marcacoes marcacoes;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Markdown(
      data: markdown,
      extensionSet: md.ExtensionSet(
        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
        [SintaxeFonte(), SintaxeGeral(), SintaxeMarcar(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
      ),
      // tel: abre o discador e sms: abre a mensagem. Outros links não
      // são seguidos: o app é offline e não abre páginas.
      onTapLink: (_, href, _) {
        if (href == null) return;
        if (href.startsWith('tel:')) ligar(href.substring(4));
        if (href.startsWith('sms:')) launchUrl(Uri(scheme: 'sms', path: href.substring(4)));
      },
      builders: {
        'fonte': _BotaoFonte((id) => fontes[id] != null ? _mostrarFonte(context, fontes[id]!) : null),
        'geral': _MarcaGeral(() => _mostrarAvisoGeral(context)),
        'marcar': _CaixaMarcar(capituloId, marcacoes),
      },
      padding: padding,
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
  }
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

/// Caixa de marcar no lugar de `[marcar: id]`. O estado fica salvo no aparelho.
class _CaixaMarcar extends MarkdownElementBuilder {
  _CaixaMarcar(this.capitulo, this.marcacoes);

  final String capitulo;
  final Marcacoes marcacoes;

  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
      BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    final item = element.textContent;
    return ListenableBuilder(
      listenable: marcacoes,
      builder: (context, _) {
        final marcado = marcacoes.marcado(capitulo, item);
        return Semantics(
          checked: marcado,
          child: InkWell(
            key: ValueKey('marcar-$item'),
            onTap: () => marcacoes.alternar(capitulo, item),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                marcado ? Icons.check_box : Icons.check_box_outline_blank,
                size: 22,
                color: marcado ? corFeixe : corTexto,
              ),
            ),
          ),
        );
      },
    );
  }
}
