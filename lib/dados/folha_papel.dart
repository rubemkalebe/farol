import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'ficha.dart';

/// Um grupo de telefones da folha impressa (o título vem da seção do guia).
typedef GrupoPapel = (String titulo, List<String> linhas);

final _fonte = RegExp(r'\[(fonte|marcar): [^\]]*\]');
final _geral = RegExp(r'\[geral\]');
final _mapa = RegExp(r'\s*·?\s*\[[^\]]*\]\(mapa:[^)]*\)');
final _link = RegExp(r'\[([^\]]*)\]\([^)]*\)');
final _espacos = RegExp(r'\s+');

String _limpar(String s) => s
    .replaceAll(_fonte, '')
    .replaceAll(_geral, '')
    .replaceAll(_mapa, '')
    .replaceAllMapped(_link, (m) => m[1]!)
    .replaceAll('**', '')
    .replaceAll(_espacos, ' ')
    .trim();

/// Tira do capítulo de contatos (já com os blocos da cidade) as linhas que
/// têm telefone, sem a marcação do Markdown, agrupadas pela seção.
List<GrupoPapel> telefonesParaPapel(String markdown) {
  final grupos = <GrupoPapel>[];
  var titulo = '';
  for (final bruta in markdown.split('\n')) {
    final linha = bruta.trim();
    if (linha.startsWith('## ') || linha.startsWith('### ')) {
      titulo = _limpar(linha.replaceFirst(RegExp(r'^#+ '), ''));
      continue;
    }
    if (!linha.contains('(tel:')) continue;
    String texto;
    if (linha.startsWith('|')) {
      final celulas = [
        for (final c in linha.split('|'))
          if (_limpar(c).isNotEmpty) _limpar(c),
      ];
      texto = celulas.join(' — ');
    } else {
      texto = _limpar(linha.replaceFirst(RegExp(r'^([-*>]|\d+\.)\s*'), ''));
    }
    if (texto.isEmpty) continue;
    if (grupos.isEmpty || grupos.last.$1 != titulo) {
      grupos.add((titulo, <String>[]));
    }
    grupos.last.$2.add(texto);
  }
  return grupos;
}

/// Folha A4 para imprimir ou guardar: telefones da cidade e, se a pessoa
/// quiser, a ficha da família.
Future<Uint8List> gerarFolhaPapel({
  required String cidade,
  required List<GrupoPapel> telefones,
  required pw.Font regular,
  required pw.Font negrito,
  Ficha? ficha,
  DateTime? agora,
}) {
  final data = agora ?? DateTime.now();
  final dia =
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
  final tema = pw.ThemeData.withFont(base: regular, bold: negrito);
  const corpo = pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5);
  final titulo = pw.TextStyle(font: negrito, fontSize: 13);

  pw.Widget grupo(String nome, List<String> linhas) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 10),
      if (nome.isNotEmpty) pw.Text(nome, style: titulo),
      pw.SizedBox(height: 3),
      for (final l in linhas)
        pw.Bullet(
          text: l,
          style: corpo,
          bulletSize: 3,
          bulletMargin: const pw.EdgeInsets.only(top: 5, right: 6),
        ),
    ],
  );

  final linhasFicha = ficha == null
      ? const <String>[]
      : ficha.comoTexto().split('\n').skip(1).toList();

  final doc = pw.Document(title: 'Farol: telefones e ficha', author: 'Farol');
  doc.addPage(
    pw.MultiPage(
      theme: tema,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 1.2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'FAROL · telefones de emergência — $cidade',
              style: pw.TextStyle(font: negrito, fontSize: 14),
            ),
            pw.Text('impresso em $dia', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
      ),
      footer: (c) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Ligações para 190, 192, 193 e 199 são gratuitas. '
            'Confira os números de tempos em tempos.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            '${c.pageNumber}/${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
      build: (_) => [
        for (final (nome, linhas) in telefones) grupo(nome, linhas),
        if (linhasFicha.isEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Contatos da família (preencha à mão)', style: titulo),
          for (var i = 0; i < 6; i++)
            pw.Container(
              height: 26,
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
            ),
        ],
        if (linhasFicha.isNotEmpty) ...[
          pw.NewPage(),
          pw.SizedBox(height: 10),
          pw.Text('FICHA DA FAMÍLIA', style: titulo),
          pw.SizedBox(height: 6),
          for (final l in linhasFicha)
            if (l.trim().isEmpty)
              pw.SizedBox(height: 8)
            else
              pw.Text(
                l,
                style: l == l.toUpperCase() && !l.contains(':')
                    ? pw.TextStyle(font: negrito, fontSize: 11.5)
                    : corpo,
              ),
        ],
      ],
    ),
  );
  return doc.save();
}
