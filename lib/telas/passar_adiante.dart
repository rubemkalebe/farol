import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../dados/passar_adiante.dart';
import '../tema.dart';
import 'largura.dart';

/// Ensina a mandar o Farol para outro celular sem internet e abre o menu
/// de compartilhar com o APK.
class TelaPassarAdiante extends StatefulWidget {
  const TelaPassarAdiante({super.key});

  @override
  State<TelaPassarAdiante> createState() => _TelaPassarAdianteState();
}

class _TelaPassarAdianteState extends State<TelaPassarAdiante> {
  bool _preparando = false;

  Future<void> _enviar() async {
    setState(() => _preparando = true);
    try {
      final caminho = await prepararApk();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              caminho,
              mimeType: 'application/vnd.android.package-archive',
              name: 'Farol.apk',
            ),
          ],
          subject: 'Farol',
        ),
      );
    } on ApkDividido {
      _aviso(
        'Este Farol foi instalado pela loja em partes e não dá para enviar '
        'direto. Peça para a pessoa instalar pela loja ou pelo arquivo .apk.',
      );
    } catch (e) {
      _aviso('Não deu para preparar o arquivo: $e');
    } finally {
      if (mounted) setState(() => _preparando = false);
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
      appBar: AppBar(title: const Text('Passar o Farol adiante')),
      body: LarguraLeitura(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Mande o Farol para o celular de alguém da família ou da '
              'vizinhança, sem internet: o app vai inteiro, com os guias e os '
              'telefones de todas as cidades.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 20),
            Text('Neste celular', style: t.titleLarge),
            const SizedBox(height: 10),
            passo(
              1,
              'Fiquem perto um do outro, com Bluetooth e Wi-Fi ligados nos dois. '
              'Não precisa de internet.',
            ),
            passo(
              2,
              'Toque em "Enviar o Farol" e escolha Quick Share '
              '(Compartilhamento por proximidade) ou Bluetooth. '
              'Se o Bluetooth recusar o arquivo, use o Quick Share.',
            ),
            const SizedBox(height: 4),
            FilledButton.icon(
              key: const Key('enviar-farol'),
              onPressed: _preparando ? null : _enviar,
              icon: _preparando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
              label: Text(_preparando ? 'Preparando...' : 'Enviar o Farol'),
            ),
            const SizedBox(height: 24),
            Text('No outro celular', style: t.titleLarge),
            const SizedBox(height: 10),
            passo(3, 'Aceite o arquivo Farol.apk e toque nele para abrir.'),
            passo(
              4,
              'O Android vai pedir para permitir a instalação de apps '
              'desconhecidos por aquele app (Arquivos ou Quick Share). '
              'Toque em Configurações, ative "Permitir desta fonte" e volte.',
            ),
            passo(
              5,
              'Toque em Instalar. Se aparecer um aviso do Play Protect, '
              'toque em "Mais detalhes" e "Instalar mesmo assim": o aviso '
              'aparece porque o app não veio da loja.',
            ),
            passo(
              6,
              'Depois de instalar, volte às Configurações e desligue a '
              'permissão de apps desconhecidos, por segurança.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Só funciona entre celulares Android: o iPhone não instala '
                  'app fora da App Store. Os pacotes da Wikipédia não vão '
                  'junto; cada celular baixa os seus.',
                  style: t.bodyMedium?.copyWith(color: corTextoSuave),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
