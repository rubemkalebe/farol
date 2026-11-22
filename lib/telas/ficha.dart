import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../dados/ficha.dart';
import '../tema.dart';
import 'largura.dart';

class TelaFicha extends StatefulWidget {
  const TelaFicha({super.key});

  @override
  State<TelaFicha> createState() => _TelaFichaState();
}

class _TelaFichaState extends State<TelaFicha> {
  late final Future<Ficha> _carregar = Ficha.abrir();
  Ficha? _ficha;

  @override
  void dispose() {
    // Campo em edição quando a tela fecha não perde o que foi digitado.
    _ficha?.salvar();
    super.dispose();
  }

  Future<void> _salvar() async {
    await _ficha!.salvar();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ficha da família'),
        actions: [
          IconButton(
            tooltip: 'Mostrar para o socorrista',
            icon: const Icon(Icons.fullscreen),
            onPressed: _ficha == null
                ? null
                : () => _mostrarTextoGrande(context),
          ),
          PopupMenuButton<String>(
            onSelected: (op) async {
              final texto = _ficha!.comoTexto();
              if (op == 'copiar') {
                await Clipboard.setData(ClipboardData(text: texto));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ficha copiada.')),
                  );
                }
              } else {
                await SharePlus.instance.share(ShareParams(text: texto));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copiar', child: Text('Copiar texto')),
              PopupMenuItem(value: 'compartilhar', child: Text('Compartilhar')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<Ficha>(
        future: _carregar,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erro ao abrir a ficha: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final f = _ficha ??= snap.data!;
          final t = Theme.of(context).textTheme;
          return LarguraLeitura(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(
                  'Fica salva só neste aparelho. Ninguém mais vê, a não ser que você compartilhe.',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 16),
                Text('Casa', style: t.titleLarge),
                _Campo(
                  rotulo: 'Endereço',
                  valor: f.endereco,
                  aoMudar: (v) => f.endereco = v,
                  aoSair: _salvar,
                ),
                _Campo(
                  rotulo: 'Ponto de referência',
                  dica: 'Para explicar ao 192/193 como chegar',
                  valor: f.referencia,
                  aoMudar: (v) => f.referencia = v,
                  aoSair: _salvar,
                ),
                _Campo(
                  rotulo: 'Ponto de encontro da família',
                  valor: f.pontoEncontro,
                  aoMudar: (v) => f.pontoEncontro = v,
                  aoSair: _salvar,
                ),
                _Campo(
                  rotulo: 'Nº da instalação de energia',
                  dica: 'Fica na conta de luz',
                  valor: f.instalacaoEnergia,
                  aoMudar: (v) => f.instalacaoEnergia = v,
                  aoSair: _salvar,
                  teclado: TextInputType.number,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text('Pessoas', style: t.titleLarge)),
                    TextButton.icon(
                      onPressed: () => _editarPessoa(context, null),
                      icon: const Icon(Icons.person_add_alt),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                if (f.pessoas.isEmpty)
                  Text(
                    'Nenhuma pessoa ainda. Adicione cada morador da casa.',
                    style: t.bodySmall,
                  ),
                for (final p in f.pessoas)
                  Card(
                    child: ListTile(
                      title: Text(p.nome.isEmpty ? 'Sem nome' : p.nome),
                      subtitle: Text(_resumoPessoa(p)),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editarPessoa(context, p),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text('Contatos', style: t.titleLarge)),
                    TextButton.icon(
                      onPressed: () => _editarContato(context, null),
                      icon: const Icon(Icons.add_call),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                if (f.contatos.isEmpty)
                  Text(
                    'Parentes, vizinhos, médico, escola. Anote também em papel.',
                    style: t.bodySmall,
                  ),
                for (final c in f.contatos)
                  Card(
                    child: ListTile(
                      title: Text(c.nome.isEmpty ? 'Sem nome' : c.nome),
                      subtitle: Text(
                        [
                          c.relacao,
                          c.telefone,
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      onLongPress: () => _editarContato(context, c),
                      onTap: () => _editarContato(context, c),
                      trailing: c.telefone.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Ligar',
                              icon: const Icon(Icons.phone, color: corFeixe),
                              onPressed: () => ligar(c.telefone),
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

  String _resumoPessoa(Pessoa p) {
    final partes = [
      if (p.tipoSanguineo.isNotEmpty) 'Sangue ${p.tipoSanguineo}',
      if (p.alergias.isNotEmpty) 'Alergia: ${p.alergias}',
      if (p.remedios.isNotEmpty) 'Remédios: ${p.remedios}',
    ];
    return partes.isEmpty ? 'Toque para preencher' : partes.join(' · ');
  }

  Future<void> _editarPessoa(BuildContext context, Pessoa? existente) async {
    final p = existente ?? Pessoa();
    final resultado = await Navigator.of(context).push<_Acao>(
      MaterialPageRoute(
        builder: (_) => _TelaPessoa(pessoa: p, nova: existente == null),
      ),
    );
    if (resultado == _Acao.salvar && existente == null) _ficha!.pessoas.add(p);
    if (resultado == _Acao.apagar) _ficha!.pessoas.remove(p);
    // Os campos editam a pessoa direto; salva também quando volta sem apertar Salvar.
    if (resultado != null || existente != null) await _salvar();
  }

  Future<void> _editarContato(BuildContext context, Contato? existente) async {
    final c = existente ?? Contato();
    final nome = TextEditingController(text: c.nome);
    final relacao = TextEditingController(text: c.relacao);
    final telefone = TextEditingController(text: c.telefone);
    final resultado = await showDialog<_Acao>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existente == null ? 'Novo contato' : 'Editar contato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nome,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            TextField(
              controller: relacao,
              decoration: const InputDecoration(
                labelText: 'Quem é',
                hintText: 'Irmã, vizinho, médico...',
              ),
            ),
            TextField(
              controller: telefone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefone com DDD'),
            ),
          ],
        ),
        actions: [
          if (existente != null)
            TextButton(
              onPressed: () => Navigator.pop(context, _Acao.apagar),
              child: const Text('Apagar'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _Acao.salvar),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (resultado == _Acao.salvar) {
      c
        ..nome = nome.text.trim()
        ..relacao = relacao.text.trim()
        ..telefone = telefone.text.trim();
      if (existente == null) _ficha!.contatos.add(c);
    }
    if (resultado == _Acao.apagar) _ficha!.contatos.remove(c);
    if (resultado != null) await _salvar();
  }

  void _mostrarTextoGrande(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Ficha')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: SelectableText(
              _ficha!.comoTexto(),
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Acao { salvar, apagar }

/// Abre o discador com o número. Sem sinal, o próprio telefone avisa.
Future<void> ligar(String numero) async {
  final limpo = numero.replaceAll(RegExp(r'[^0-9+]'), '');
  if (limpo.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: limpo));
}

class _Campo extends StatelessWidget {
  const _Campo({
    required this.rotulo,
    required this.valor,
    required this.aoMudar,
    required this.aoSair,
    this.dica,
    this.teclado,
    this.linhas = 1,
  });

  final String rotulo;
  final String? dica;
  final String valor;
  final ValueChanged<String> aoMudar;
  final VoidCallback aoSair;
  final TextInputType? teclado;
  final int linhas;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Focus(
        onFocusChange: (temFoco) {
          if (!temFoco) aoSair();
        },
        child: TextFormField(
          initialValue: valor,
          keyboardType: teclado,
          minLines: 1,
          maxLines: linhas,
          decoration: InputDecoration(
            labelText: rotulo,
            helperText: dica,
            border: const OutlineInputBorder(),
          ),
          onChanged: aoMudar,
        ),
      ),
    );
  }
}

class _TelaPessoa extends StatelessWidget {
  const _TelaPessoa({required this.pessoa, required this.nova});

  final Pessoa pessoa;
  final bool nova;

  @override
  Widget build(BuildContext context) {
    final p = pessoa;
    void nada() {}
    return Scaffold(
      appBar: AppBar(
        title: Text(nova ? 'Nova pessoa' : 'Editar pessoa'),
        actions: [
          if (!nova)
            IconButton(
              tooltip: 'Apagar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Apagar esta pessoa da ficha?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Apagar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  Navigator.pop(context, _Acao.apagar);
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Campo(
            rotulo: 'Nome',
            valor: p.nome,
            aoMudar: (v) => p.nome = v,
            aoSair: nada,
          ),
          _Campo(
            rotulo: 'Data de nascimento',
            valor: p.nascimento,
            aoMudar: (v) => p.nascimento = v,
            aoSair: nada,
            teclado: TextInputType.datetime,
          ),
          _Campo(
            rotulo: 'Tipo sanguíneo',
            dica: 'Ex.: O+, A-. Deixe em branco se não souber',
            valor: p.tipoSanguineo,
            aoMudar: (v) => p.tipoSanguineo = v,
            aoSair: nada,
          ),
          _Campo(
            rotulo: 'Alergias',
            dica: 'Remédios, alimentos, picadas',
            valor: p.alergias,
            aoMudar: (v) => p.alergias = v,
            aoSair: nada,
            linhas: 3,
          ),
          _Campo(
            rotulo: 'Doenças e condições',
            dica: 'Diabetes, pressão alta, epilepsia, marca-passo...',
            valor: p.doencas,
            aoMudar: (v) => p.doencas = v,
            aoSair: nada,
            linhas: 3,
          ),
          _Campo(
            rotulo: 'Remédios e doses',
            valor: p.remedios,
            aoMudar: (v) => p.remedios = v,
            aoSair: nada,
            linhas: 4,
          ),
          _Campo(
            rotulo: 'Cartão SUS',
            valor: p.cartaoSus,
            aoMudar: (v) => p.cartaoSus = v,
            aoSair: nada,
            teclado: TextInputType.number,
          ),
          _Campo(
            rotulo: 'Plano de saúde',
            valor: p.planoSaude,
            aoMudar: (v) => p.planoSaude = v,
            aoSair: nada,
          ),
          _Campo(
            rotulo: 'Observações',
            dica: 'Aparelho que usa, deficiência, quem cuida...',
            valor: p.observacoes,
            aoMudar: (v) => p.observacoes = v,
            aoSair: nada,
            linhas: 3,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, _Acao.salvar),
            icon: const Icon(Icons.check),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
