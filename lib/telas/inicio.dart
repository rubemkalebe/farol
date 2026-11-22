import 'package:flutter/material.dart';

import '../dados/conteudo.dart';
import '../dados/locais.dart';
import '../dados/preferencias.dart';
import 'busca.dart';
import 'emergencia.dart';
import 'escolher_cidade.dart';
import '../tema.dart';
import 'capitulo.dart';
import 'farol_logo.dart';
import 'ficha.dart';
import 'largura.dart';

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
      if (cidade == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _escolherCidade());
      }
    });
  }

  String get _rotuloCidade {
    if (_cidade == null) return 'Escolher cidade';
    if (_cidade == outraCidade) return 'Outra cidade';
    return _cidades.where((c) => c.id == _cidade).firstOrNull?.rotulo ??
        'Escolher cidade';
  }

  Future<void> _escolherCidade() async {
    final escolhida = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => TelaEscolherCidade(cidades: _cidades, atual: _cidade),
      ),
    );
    final id = escolhida ?? _cidade ?? outraCidade;
    await salvarCidade(id);
    if (mounted) setState(() => _cidade = id);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: BrilhoFeixe(
        child: SafeArea(
          child: FutureBuilder<List<Capitulo>>(
            future: _indice,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Text('Erro ao abrir o conteúdo: ${snap.error}'),
                );
              }
              final capitulos = snap.data;
              if (capitulos == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return LarguraLeitura(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _Cabecalho(
                      cidade: _rotuloCidade,
                      aoTrocarCidade: _escolherCidade,
                    ),
                    const SizedBox(height: 22),
                    _BotaoEmergencia(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TelaEmergencia(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CampoBusca(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TelaBusca()),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Rotulo('GUIAS'),
                    const SizedBox(height: 10),
                    _GradeGuias(capitulos: capitulos),
                    const SizedBox(height: 28),
                    _Rotulo('FERRAMENTAS'),
                    const SizedBox(height: 10),
                    _CartaoFerramenta(
                      icone: Icons.family_restroom,
                      titulo: 'Ficha da família',
                      texto: 'Tipo sanguíneo, alergias, remédios e contatos. Fica só no aparelho.',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TelaFicha()),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Funciona sem internet · conteúdo com fontes oficiais',
                        style: t.bodySmall?.copyWith(color: corTextoSuave),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.cidade, required this.aoTrocarCidade});

  final String cidade;
  final VoidCallback aoTrocarCidade;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ExcludeSemantics(child: FarolLogo(tamanho: 64)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FAROL',
                style: t.headlineMedium?.copyWith(
                  color: corFeixe,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ferramentas e Apoio para Rotinas Off-Line',
                style: t.bodySmall?.copyWith(color: corTextoSuave),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: aoTrocarCidade,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: corSuperficie,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: corBorda),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.place, size: 15, color: corFeixe),
                      const SizedBox(width: 4),
                      // Flexible: com letra grande, o nome quebra a linha em vez de estourar.
                      Flexible(
                        child: Text(
                          cidade,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.expand_more,
                        size: 16,
                        color: corTextoSuave,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('tamanho-texto'),
          tooltip: 'Tamanho da letra',
          onPressed: () => _escolherTamanho(context),
          icon: const Icon(Icons.text_fields, color: corFeixe, size: 28),
        ),
      ],
    );
  }
}

void _escolherTamanho(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      // Rolável: com a letra "Muito grande" a lista não cabe em tela pequena.
      child: SingleChildScrollView(
        child: ValueListenableBuilder<double>(
          valueListenable: escalaTexto,
          builder: (context, atual, _) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tamanho da letra',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vale para o app todo, além do tamanho escolhido no celular.',
                  style: TextStyle(color: corTextoSuave),
                ),
                const SizedBox(height: 12),
                for (final t in tamanhosTexto)
                  Semantics(
                    selected: t.escala == atual,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        t.escala == atual
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: corFeixe,
                      ),
                      title: Text(
                        t.nome,
                        textScaler: TextScaler.linear(t.escala),
                      ),
                      onTap: () => salvarTamanhoTexto(t),
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

/// No desespero ninguém lê: o primeiro botão vai direto ao trecho certo.
class _BotaoEmergencia extends StatelessWidget {
  const _BotaoEmergencia({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Emergência: o que está acontecendo? Mostra o que fazer e o botão de ligar.',
      excludeSemantics: true,
      child: Material(
        key: const ValueKey('botao-emergencia'),
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [corAlertaFundo, corAlertaEscuro],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55D92B36),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 14, 20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emergency,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'O QUE ESTÁ ACONTECENDO?',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Direto ao que fazer, com o botão de ligar',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xE6FFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('botao-busca'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: corSuperficie,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: corContorno),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: corFeixe),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Buscar: "engasgou", "picada", "faltou luz"…',
                style: TextStyle(color: corTextoSuave, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      color: corTextoSuave,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    ),
  );
}

class _GradeGuias extends StatelessWidget {
  const _GradeGuias({required this.capitulos});

  final List<Capitulo> capitulos;

  @override
  Widget build(BuildContext context) {
    // Com letra grande, uma coluna só: os cartões ficam largos e nada é cortado.
    if (MediaQuery.textScalerOf(context).scale(10) > 13 ||
        MediaQuery.sizeOf(context).width < 340) {
      return Column(
        children: [
          for (final c in capitulos)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CartaoCapitulo(capitulo: c),
            ),
        ],
      );
    }
    final linhas = <Widget>[];
    for (var i = 0; i < capitulos.length; i += 2) {
      linhas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _CartaoCapitulo(capitulo: capitulos[i])),
              const SizedBox(width: 12),
              Expanded(
                child: i + 1 < capitulos.length
                    ? _CartaoCapitulo(capitulo: capitulos[i + 1])
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      linhas.add(const SizedBox(height: 12));
    }
    return Column(children: linhas);
  }
}

class _CartaoCapitulo extends StatelessWidget {
  const _CartaoCapitulo({required this.capitulo});

  final Capitulo capitulo;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TelaCapitulo(capitulo: capitulo)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: corFeixeSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icones[capitulo.icone] ?? Icons.article_outlined,
                  color: corFeixe,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                capitulo.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                capitulo.resumo,
                style: const TextStyle(
                  color: corTextoSuave,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoFerramenta extends StatelessWidget {
  const _CartaoFerramenta({
    required this.icone,
    required this.titulo,
    required this.texto,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: corFeixeSuave,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icone, color: corFeixe),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      texto,
                      style: const TextStyle(
                        color: corTextoSuave,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: corTextoSuave),
            ],
          ),
        ),
      ),
    );
  }
}
