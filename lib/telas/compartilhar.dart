import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dados/compartilhar.dart';
import '../tema.dart';
import 'largura.dart';

/// Escolha entre mandar e receber a biblioteca.
class TelaCompartilhar extends StatelessWidget {
  const TelaCompartilhar({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget opcao({
      required Key key,
      required IconData icone,
      required String titulo,
      required String texto,
      required Widget Function() tela,
    }) => Card(
      child: ListTile(
        key: key,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icone, color: corFeixe, size: 32),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(texto),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => tela())),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Passar para outro celular')),
      body: LarguraLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Sem internet, um celular passa para o outro a biblioteca e os '
              'manuais já baixados, pelo Wi-Fi. Não gasta dados nem crédito. '
              'Quem baixou antes abastece a família e os vizinhos.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 16),
            opcao(
              key: const ValueKey('mandar'),
              icone: Icons.upload,
              titulo: 'Mandar deste celular',
              texto: 'Este celular tem os arquivos e passa para o outro.',
              tela: () => const TelaMandar(),
            ),
            opcao(
              key: const ValueKey('receber'),
              icone: Icons.download,
              titulo: 'Receber neste celular',
              texto: 'O outro celular tem os arquivos e passa para este.',
              tela: () => const TelaReceber(),
            ),
          ],
        ),
      ),
    );
  }
}

class TelaMandar extends StatefulWidget {
  const TelaMandar({super.key, this.doador});

  /// Para testes: um servidor com outra lista de arquivos.
  final Doador? doador;

  @override
  State<TelaMandar> createState() => _TelaMandarState();
}

class _TelaMandarState extends State<TelaMandar> {
  late final Doador _doador = widget.doador ?? Doador();
  List<String> _enderecos = const [];
  Object? _erro;
  Timer? _procura;

  @override
  void initState() {
    super.initState();
    _doador.addListener(_mudou);
    manterTelaAcesa(true);
    _ligar();
    // A pessoa liga o roteador do celular com esta tela aberta: procura a
    // rede de novo de tempos em tempos.
    _procura = Timer.periodic(const Duration(seconds: 3), (_) => _procurar());
  }

  Future<void> _ligar() async {
    try {
      await _doador.ligar();
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    }
    await _procurar();
  }

  Future<void> _procurar() async {
    final e = await enderecosLocais();
    if (!mounted) return;
    if (e.join() != _enderecos.join()) setState(() => _enderecos = e);
  }

  void _mudou() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _procura?.cancel();
    _doador.removeListener(_mudou);
    _doador.desligar();
    manterTelaAcesa(false);
    super.dispose();
  }

  String _comPorta(String ip) =>
      _doador.porta == portaFarol || _doador.porta == 0
      ? ip
      : '$ip:${_doador.porta}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final itens = _doador.itens;
    final semApk = itens.where((i) => i.tipo != TipoItem.apk).toList();
    final total = semApk.fold<int>(0, (s, i) => s + i.tamanho);
    Widget passo(int n, String texto) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: corFeixeSuave,
            child: Text(
              '$n',
              style: const TextStyle(
                color: corFeixe,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: t.bodyLarge)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mandar deste celular')),
      body: LarguraLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_erro != null)
              Text('Não deu para começar: $_erro', style: t.bodyLarge)
            else if (_doador.ligado && semApk.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Este celular ainda não tem pacotes da biblioteca nem '
                  'manuais baixados. Por enquanto, só dá para passar o '
                  'app.',
                  style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            passo(
              1,
              'Ligue o roteador Wi-Fi deste celular (nas configurações: '
              '"Ponto de acesso" ou "Roteador Wi-Fi"). Funciona sem '
              'internet e sem crédito. Se os dois já estão no mesmo Wi-Fi, '
              'pule esta parte.',
            ),
            passo(2, 'Conecte o outro celular a essa rede Wi-Fi.'),
            passo(
              3,
              'No outro celular, abra o Farol, vá em Biblioteca, "Passar '
              'para outro celular", Receber, e digite:',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _enderecos.isEmpty
                    ? Text(
                        'Procurando a rede… Ligue o roteador Wi-Fi ou '
                        'conecte este celular a um Wi-Fi.',
                        style: t.bodyLarge,
                      )
                    : Column(
                        children: [
                          SelectableText(
                            _comPorta(_enderecos.first),
                            key: const ValueKey('endereco'),
                            textAlign: TextAlign.center,
                            style: t.headlineMedium?.copyWith(
                              color: corFeixe,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_enderecos.length > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Se não der, tente: '
                              '${_enderecos.skip(1).map(_comPorta).join(', ')}',
                              textAlign: TextAlign.center,
                              style: t.bodySmall?.copyWith(
                                color: corTextoSuave,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text(
                            'Sem o Farol? Aponte a câmera do outro celular '
                            'para o código: abre uma página para baixar o '
                            'app e os arquivos pelo navegador.',
                            textAlign: TextAlign.center,
                            style: t.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(10),
                            child: QrImageView(
                              data:
                                  'http://${_enderecos.first}:'
                                  '${_doador.porta}/',
                              size: 200,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            if (_doador.ligado) ...[
              Text(
                semApk.isEmpty
                    ? 'Oferecendo o app Farol.'
                    : 'Oferecendo ${semApk.length} '
                          '${semApk.length == 1 ? 'arquivo' : 'arquivos'} '
                          '(${tamanhoLegivel(total)})'
                          '${itens.length > semApk.length ? ' e o app Farol' : ''}.',
                style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (_doador.enviando > 0 || _doador.enviados > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    [
                      if (_doador.enviando > 0)
                        'Mandando agora: ${_doador.enviando}',
                      if (_doador.enviados > 0) 'Já foram: ${_doador.enviados}',
                    ].join(' · '),
                    style: t.bodyLarge?.copyWith(color: corFeixe),
                  ),
                ),
              const SizedBox(height: 6),
              for (final i in semApk)
                Text(
                  '• ${i.titulo} · ${tamanhoLegivel(i.tamanho)}',
                  style: t.bodyMedium?.copyWith(color: corTextoSuave),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Deixe esta tela aberta até o outro celular terminar. Ao sair '
              'dela, o Farol para de mandar.',
              style: t.bodySmall?.copyWith(color: corTextoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

class TelaReceber extends StatefulWidget {
  const TelaReceber({super.key});

  @override
  State<TelaReceber> createState() => _TelaReceberState();
}

class _TelaReceberState extends State<TelaReceber> {
  static const _chave = 'receber_endereco';
  final _receptor = Receptor.instancia;
  final _campo = TextEditingController();
  Uri? _base;
  List<ItemFarol>? _itens;
  Map<String, (bool conhece, bool jaTem)> _situacao = const {};
  bool _conectando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _receptor.addListener(_mudou);
    manterTelaAcesa(true);
    SharedPreferences.getInstance()
        .then((p) {
          final e = p.getString(_chave);
          if (e != null && mounted && _campo.text.isEmpty) _campo.text = e;
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _receptor.removeListener(_mudou);
    _campo.dispose();
    manterTelaAcesa(false);
    super.dispose();
  }

  int _emAndamento = 0;

  void _mudou() {
    if (!mounted) return;
    setState(() {});
    // Só confere o que já está no celular quando algum arquivo termina ou
    // começa, não a cada pedaço que chega.
    if (_receptor.recebendo.length != _emAndamento) {
      _emAndamento = _receptor.recebendo.length;
      _atualizarSituacao();
    }
  }

  Future<void> _atualizarSituacao() async {
    final itens = _itens;
    if (itens == null) return;
    final s = {
      for (final i in itens)
        i.chave: (await _receptor.conhece(i), await _receptor.jaTem(i)),
    };
    if (mounted) setState(() => _situacao = s);
  }

  Future<void> _conectar() async {
    final base = enderecoDoador(_campo.text);
    if (base == null) {
      setState(() => _erro = 'Digite o endereço que aparece no outro celular.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _conectando = true;
      _erro = null;
    });
    try {
      final itens = await _receptor.listar(base);
      try {
        final p = await SharedPreferences.getInstance();
        await p.setString(_chave, _campo.text.trim());
      } catch (_) {}
      setState(() {
        _base = base;
        _itens = itens.where((i) => i.tipo != TipoItem.apk).toList();
      });
      await _atualizarSituacao();
    } on FormatException catch (e) {
      setState(() => _erro = 'Não deu: ${e.message}. Confira o endereço.');
    } catch (_) {
      setState(
        () => _erro =
            'Não achei o outro celular. Confira se os dois estão na mesma '
            'rede Wi-Fi, se a tela "Mandar" está aberta lá e se o endereço '
            'está igual.',
      );
    } finally {
      if (mounted) setState(() => _conectando = false);
    }
  }

  List<ItemFarol> get _faltam => [
    for (final i in _itens ?? const <ItemFarol>[])
      if (_situacao[i.chave] case (true, false)
          when !_receptor.recebendo.containsKey(i.chave))
        i,
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final itens = _itens;
    final faltam = _faltam;
    return Scaffold(
      appBar: AppBar(title: const Text('Receber neste celular')),
      body: LarguraLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Conecte este celular à mesma rede Wi-Fi do outro (o roteador '
              'dele ou um Wi-Fi em comum). No outro, abra "Mandar deste '
              'celular" e digite aqui o endereço que aparece lá.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('campo-endereco'),
              controller: _campo,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Endereço do outro celular',
                hintText: 'Ex.: 192.168.43.1',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _conectar(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const ValueKey('conectar'),
                onPressed: _conectando ? null : _conectar,
                child: Text(_conectando ? 'Procurando…' : 'Conectar'),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(_erro!, style: t.bodyLarge?.copyWith(color: corFeixe)),
            ],
            if (itens != null) ...[
              const SizedBox(height: 16),
              if (itens.isEmpty)
                Text(
                  'O outro celular não tem pacotes nem manuais baixados.',
                  style: t.bodyLarge,
                )
              else if (faltam.length > 1)
                FilledButton.tonal(
                  key: const ValueKey('receber-tudo'),
                  onPressed: () {
                    for (final i in faltam) {
                      _receptor.receber(_base!, i);
                    }
                  },
                  child: Text(
                    'Receber tudo o que falta · '
                    '${tamanhoLegivel(faltam.fold(0, (s, i) => s + i.tamanho))}',
                  ),
                ),
              const SizedBox(height: 8),
              for (final i in itens)
                _CartaoRecebimento(
                  item: i,
                  situacao: _situacao[i.chave],
                  recebimento: _receptor.recebendo[i.chave],
                  aoReceber: () => _receptor.receber(_base!, i),
                  aoParar: () => _receptor.cancelar(i),
                ),
              const SizedBox(height: 12),
              Text(
                'Cada arquivo é conferido ao chegar. Se a conexão cair, '
                'toque em Continuar: recomeça de onde parou.',
                style: t.bodySmall?.copyWith(color: corTextoSuave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CartaoRecebimento extends StatelessWidget {
  const _CartaoRecebimento({
    required this.item,
    required this.situacao,
    required this.recebimento,
    required this.aoReceber,
    required this.aoParar,
  });

  final ItemFarol item;
  final (bool, bool)? situacao;
  final Recebimento? recebimento;
  final VoidCallback aoReceber;
  final VoidCallback aoParar;

  @override
  Widget build(BuildContext context) {
    final r = recebimento;
    final Widget? acao;
    String? estado;
    if (r != null) {
      switch (r.estado) {
        case EstadoRecebimento.recebendo:
          estado = 'Recebendo… ${(r.progresso * 100).floor()}%';
          acao = TextButton(onPressed: aoParar, child: const Text('Parar'));
        case EstadoRecebimento.conferindo:
          estado = 'Conferindo o arquivo…';
          acao = null;
        case EstadoRecebimento.erro:
          estado = r.erro;
          acao = Wrap(
            spacing: 4,
            children: [
              TextButton(onPressed: aoParar, child: const Text('Deixar')),
              FilledButton.tonal(
                onPressed: () {
                  aoParar();
                  aoReceber();
                },
                child: const Text('Continuar'),
              ),
            ],
          );
      }
    } else {
      switch (situacao) {
        case null:
          acao = null;
        case (false, _):
          estado =
              'Este Farol não conhece este arquivo. Atualize o Farol '
              '(dá para receber o app pelo navegador) e tente de novo.';
          acao = null;
        case (true, true):
          estado = 'Já está neste celular';
          acao = null;
        case (true, false):
          acao = FilledButton.tonal(
            key: ValueKey('receber-${item.chave}'),
            onPressed: aoReceber,
            child: Text('Receber · ${tamanhoLegivel(item.tamanho)}'),
          );
      }
    }
    final pronto = r == null && situacao == (true, true);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (pronto)
                  const Icon(Icons.check_circle, color: corFeixe, size: 20),
              ],
            ),
            Text(
              '${item.tipo == TipoItem.pdf ? 'Manual em PDF' : 'Biblioteca'}'
              ' · ${tamanhoLegivel(item.tamanho)}',
              style: const TextStyle(color: corTextoSuave, fontSize: 13),
            ),
            if (r != null && r.estado != EstadoRecebimento.erro) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: r.estado == EstadoRecebimento.conferindo
                    ? null
                    : r.progresso,
              ),
            ],
            if (estado != null) ...[
              const SizedBox(height: 6),
              Text(estado, style: const TextStyle(fontSize: 13)),
            ],
            if (acao != null)
              Align(alignment: Alignment.centerRight, child: acao),
          ],
        ),
      ),
    );
  }
}
