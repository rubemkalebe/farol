import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/locais.dart';
import 'busca.dart';
import 'emergencia.dart';
import 'escolher_cidade.dart';
import '../tema.dart';
import 'capitulo.dart';
import 'ficha.dart';

const _icones = <String, IconData>{
  'bolt': Icons.bolt,
  'medical': Icons.medical_services_outlined,
  'checklist': Icons.checklist,
  'phone': Icons.phone_in_talk_outlined,
  'power': Icons.power_outlined,
  'storm': Icons.thunderstorm_outlined,
};

class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  late final Future<List<Capitulo>> _indice = carregarIndice();
  String? _cidade;
  List<Cidade> _cidades = const [];

  @override
  void initState() {
    super.initState();
    (lerCidade(), carregarCidades()).wait.then((r) {
      if (!mounted) return;
      final (cidade, cidades) = r;
      setState(() {
        _cidade = cidade;
        _cidades = cidades;
      });
      // Primeira vez: pergunta a cidade para mostrar os telefones certos.
      if (cidade == null) WidgetsBinding.instance.addPostFrameCallback((_) => _escolherCidade());
    });
  }

  String get _rotuloCidade {
    if (_cidade == null) return 'Escolher cidade';
    if (_cidade == outraCidade) return 'Outra cidade';
    return _cidades.where((c) => c.id == _cidade).firstOrNull?.rotulo ?? 'Escolher cidade';
  }

  Future<void> _escolherCidade() async {
    final escolhida = await Navigator.of(context).push<String>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TelaEscolherCidade(cidades: _cidades, atual: _cidade),
    ));
    final id = escolhida ?? _cidade ?? outraCidade;
    await salvarCidade(id);
    if (mounted) setState(() => _cidade = id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Capitulo>>(
          future: _indice,
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.place_outlined, size: 18, color: corFeixe),
                    label: Text(_rotuloCidade),
                    onPressed: _escolherCidade,
                  ),
                ),
                const SizedBox(height: 12),
                // No desespero ninguém lê: o primeiro botão vai direto ao trecho certo.
                FilledButton(
                  key: const ValueKey('botao-emergencia'),
                  style: FilledButton.styleFrom(
                    backgroundColor: corAlerta,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaEmergencia())),
                  child: const Row(
                    children: [
                      Icon(Icons.emergency, size: 34),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text('O QUE ESTÁ ACONTECENDO?',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      ),
                      Icon(Icons.chevron_right, size: 30),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('botao-busca'),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    foregroundColor: corTexto,
                  ),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TelaBusca())),
                  icon: const Icon(Icons.search, color: corFeixe),
                  label: const Text('Buscar nos guias', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 20),
                Text('Guias', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final c in capitulos) _CartaoCapitulo(capitulo: c),
                const SizedBox(height: 8),
                Text('Ferramentas', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: const Icon(Icons.family_restroom, color: corFeixe, size: 32),
                    title: const Text('Ficha da família',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Tipo sanguíneo, alergias, remédios e contatos. Fica só no aparelho.'),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const TelaFicha())),
                  ),
                ),
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
