import 'package:flutter/material.dart';

import '../dados/locais.dart';
import '../tema.dart';
import 'largura.dart';

/// Lista de cidades com busca. Devolve o id escolhido (ou [outraCidade]).
class TelaEscolherCidade extends StatefulWidget {
  const TelaEscolherCidade({super.key, required this.cidades, this.atual});

  final List<Cidade> cidades;
  final String? atual;

  @override
  State<TelaEscolherCidade> createState() => _TelaEscolherCidadeState();
}

String _semAcento(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
  const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    b.write(i < 0 ? ch : para[i]);
  }
  return b.toString().toLowerCase();
}

class _TelaEscolherCidadeState extends State<TelaEscolherCidade> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final termo = _semAcento(_busca.trim());
    final lista = widget.cidades
        .where(
          (c) =>
              termo.isEmpty || _semAcento('${c.nome} ${c.uf}').contains(termo),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Onde você está?')),
      body: LarguraLeitura(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'Os telefones e serviços locais mudam conforme a cidade. Dá para trocar depois na tela inicial.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar cidade',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _busca = v),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final c in lista)
                    ListTile(
                      title: Text(c.nome),
                      subtitle: Text(c.uf),
                      trailing: c.id == widget.atual
                          ? const Icon(Icons.check, color: corFeixe)
                          : null,
                      onTap: () => Navigator.pop(context, c.id),
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Outra cidade'),
                    subtitle: const Text(
                      'Mostra os números nacionais. Anote os locais na Ficha da família.',
                    ),
                    trailing: widget.atual == outraCidade
                        ? const Icon(Icons.check, color: corFeixe)
                        : null,
                    onTap: () => Navigator.pop(context, outraCidade),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
