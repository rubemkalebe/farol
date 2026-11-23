import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../dados/conteudo.dart';
import '../dados/ficha.dart';
import '../dados/folha_papel.dart';
import '../dados/locais.dart';

/// Monta a folha em PDF (telefones da cidade e, se a pessoa quiser, a
/// ficha) e abre o menu de compartilhar: dali dá para imprimir, salvar ou
/// mandar para alguém imprimir.
Future<void> compartilharFolhaPapel(BuildContext context) async {
  final ficha = await Ficha.abrir();
  final temFicha = ficha.comoTexto().contains('\n');
  var incluirFicha = false;
  if (temFicha) {
    if (!context.mounted) return;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Incluir a ficha da família?'),
        content: const Text(
          'A folha leva os telefones da cidade. A ficha tem dados de saúde '
          'da família: inclua só se o papel vai ficar com gente de confiança.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Só os telefones'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Incluir a ficha'),
          ),
        ],
      ),
    );
    if (r == null) return;
    incluirFicha = r;
  }

  try {
    final cidadeId = await lerCidade();
    final cidades = await carregarCidades();
    final nome =
        cidades.where((c) => c.id == cidadeId).map((c) => c.nome).firstOrNull ??
        'números nacionais';
    final capitulo = (await carregarIndice()).firstWhere(
      (c) => c.id == 'contatos',
    );
    final markdown = aplicarLocais(
      await carregarCapitulo(capitulo),
      await blocosDaCidadeEscolhida(),
    );
    Future<pw.Font> fonte(String arquivo) async =>
        pw.Font.ttf(await rootBundle.load('assets/fontes/atkinson/$arquivo'));
    final bytes = await gerarFolhaPapel(
      cidade: nome,
      telefones: telefonesParaPapel(markdown),
      regular: await fonte('AtkinsonHyperlegible-Regular.ttf'),
      negrito: await fonte('AtkinsonHyperlegible-Bold.ttf'),
      ficha: incluirFicha ? ficha : null,
    );
    final pasta = await getTemporaryDirectory();
    final arquivo = File('${pasta.path}/farol-telefones.pdf');
    await arquivo.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(arquivo.path, mimeType: 'application/pdf')],
        subject: 'Farol: telefones de emergência',
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não deu para montar a folha: $e')),
      );
    }
  }
}
