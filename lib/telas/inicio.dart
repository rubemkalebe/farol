import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../tema.dart';
import 'capitulo.dart';

const _icones = <String, IconData>{
  'bolt': Icons.bolt,
  'medical': Icons.medical_services_outlined,
  'checklist': Icons.checklist,
  'phone': Icons.phone_in_talk_outlined,
  'power': Icons.power_outlined,
  'storm': Icons.thunderstorm_outlined,
};

class TelaInicio extends StatelessWidget {
  const TelaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Capitulo>>(
          future: carregarIndice(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Erro ao abrir o conteúdo: ${snap.error}'));
            }
            final capitulos = snap.data;
            if (capitulos == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _Cabecalho(),
                const SizedBox(height: 16),
                for (final c in capitulos) _CartaoCapitulo(capitulo: c),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FAROL',
            style: t.displaySmall?.copyWith(
                color: corFeixe, fontWeight: FontWeight.w800, letterSpacing: 4)),
        Text('Ferramentas e Apoio para Rotinas Off-Line', style: t.titleSmall),
        const SizedBox(height: 4),
        Text('Funciona sem internet.', style: t.bodySmall),
      ],
    );
  }
}

class _CartaoCapitulo extends StatelessWidget {
  const _CartaoCapitulo({required this.capitulo});

  final Capitulo capitulo;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(_icones[capitulo.icone] ?? Icons.article_outlined,
            color: corFeixe, size: 32),
        title: Text(capitulo.titulo,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(capitulo.resumo),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TelaCapitulo(capitulo: capitulo),
        )),
      ),
    );
  }
}
