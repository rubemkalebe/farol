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
        [
          SintaxeFonte(),
          SintaxeGeral(),
          SintaxeMarcar(),
          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        ],
      ),
      // tel: abre o discador e sms: abre a mensagem. Outros links não
      // são seguidos: o app é offline e não abre páginas.
      onTapLink: (_, href, _) {
        if (href == null) return;
        if (href.startsWith('tel:')) ligar(href.substring(4));
        if (href.startsWith('sms:')) {
          launchUrl(Uri(scheme: 'sms', path: href.substring(4)));
        }
      },
      builders: {
        'fonte': _BotaoFonte(
          (ids) => _mostrarFontes(context, [for (final id in ids) ?fontes[id]]),
        ),
        'geral': _MarcaGeral(() => _mostrarAvisoGeral(context)),
        'marcar': _CaixaMarcar(capituloId, marcacoes),
      },
      padding: padding,
      styleSheet: MarkdownStyleSheet.fromTheme(tema).copyWith(
        p: tema.textTheme.bodyLarge?.copyWith(height: 1.5),
        listBullet: tema.textTheme.bodyLarge?.copyWith(
          height: 1.5,
          color: corFeixe,
        ),
        a: const TextStyle(
          color: corFeixe,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.underline,
          decorationColor: corFeixeSuave,
        ),
        strong: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        h1: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        h2: tema.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: corFeixe,
          letterSpacing: -0.2,
        ),
        h2Padding: const EdgeInsets.only(top: 12, bottom: 4),
        h3: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        h3Padding: const EdgeInsets.only(top: 8),
        blockSpacing: 12,
        blockquotePadding: const EdgeInsets.all(14),
        blockquoteDecoration: BoxDecoration(
          color: corSuperficie,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: corBorda),
        ),
        tableBorder: TableBorder.symmetric(
          inside: const BorderSide(color: corBorda),
        ),
        tableHead: const TextStyle(
          fontWeight: FontWeight.w800,
          color: corFeixe,
        ),
        tableHeadCellsDecoration: const BoxDecoration(color: corSuperficieAlta),
        tableCellsDecoration: const BoxDecoration(color: corSuperficie),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(top: BorderSide(color: corBorda)),
        ),
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
          Text(
            'Orientação geral',
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: corAviso),
          ),
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

void _mostrarFontes(BuildContext context, List<Fonte> fontes) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              fontes.length == 1
                  ? 'De onde veio'
                  : 'De onde veio (${fontes.length} fontes)',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final f in fontes)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: corSuperficie,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: corBorda),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.orgao,
                      style: const TextStyle(
                        color: corFeixe,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      f.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      f.url,
                      style: const TextStyle(
                        color: corTextoSuave,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Consultado em ${f.acessado}',
                      style: const TextStyle(
                        color: corTextoSuave,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Etiqueta pequena no fim da frase: "fonte" ou "2 fontes".
Widget _etiqueta({
  required Key key,
  required IconData icone,
  required String texto,
  required Color cor,
  required VoidCallback onTap,
  required String rotulo,
}) {
  return Semantics(
    button: true,
    label: rotulo,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        // Área de toque maior que o desenho, para quem tem dedo grosso ou tremor.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cor.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 11, color: cor),
                const SizedBox(width: 3),
                Text(
                  texto,
                  style: TextStyle(
                    color: cor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Etiqueta de fonte no lugar de `[fonte: id]` (uma ou várias seguidas).
/// Usa a fonte de ícones embutida no app, então aparece mesmo sem internet.
class _BotaoFonte extends MarkdownElementBuilder {
  _BotaoFonte(this.aoTocar);

  final void Function(List<String> ids) aoTocar;

  @override
  bool isBlockElement() => false;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final ids = element.textContent.split(',');
    return _etiqueta(
      key: ValueKey('fonte-${ids.first}'),
      icone: Icons.info_outline,
      texto: ids.length == 1 ? 'fonte' : '${ids.length} fontes',
      cor: corFeixe,
      rotulo: ids.length == 1 ? 'Ver fonte' : 'Ver ${ids.length} fontes',
      onTap: () => aoTocar(ids),
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
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return _etiqueta(
      key: const ValueKey('geral'),
      icone: Icons.help_outline,
      texto: 'geral',
      cor: corAviso,
      rotulo: 'Orientação geral, sem fonte oficial',
      onTap: aoTocar,
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
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
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
              padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: marcado ? corFeixe : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: marcado ? corFeixe : corTextoSuave,
                    width: 1.6,
                  ),
                ),
                child: Icon(
                  marcado ? Icons.check_box : Icons.check_box_outline_blank,
                  size: marcado ? 16 : 0,
                  color: corNoite,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
