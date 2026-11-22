import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../dados/emergencia.dart';
import '../dados/secoes.dart';
import '../tema.dart';
import 'secoes.dart';

/// Ícones das opções do roteiro (campo "icone" em conteudo/emergencia.yaml).
const iconesEmergencia = <String, IconData>{
  'pessoa': Icons.airline_seat_flat,
  'ar': Icons.air,
  'sangue': Icons.water_drop,
  'coracao': Icons.favorite,
  'cerebro': Icons.psychology,
  'tremor': Icons.vibration,
  'raio': Icons.bolt,
  'fogo': Icons.local_fire_department,
  'bicho': Icons.pest_control,
  'veneno': Icons.science,
  'acucar': Icons.bloodtype,
  'cabeca': Icons.face,
  'osso': Icons.accessibility_new,
  'calor': Icons.thermostat,
  'fumaca': Icons.cloud,
  'gas': Icons.gas_meter,
  'energia': Icons.power_off,
  'chuva': Icons.thunderstorm,
  'urgente': Icons.priority_high,
  'duvida': Icons.help,
  'ok': Icons.check_circle,
  'perigo': Icons.warning_amber,
  'geladeira': Icons.kitchen,
  'remedio': Icons.medication,
  'aparelho': Icons.monitor_heart,
  'agua': Icons.water,
  'bateria': Icons.battery_alert,
  'telefone': Icons.call,
  'predio': Icons.apartment,
  'voltou': Icons.power,
  'deslizamento': Icons.landslide,
  'vento': Icons.air,
  'limpeza': Icons.cleaning_services,
};

// Guarda o roteiro pronto (não a tarefa de carregamento), para não depender
// de uma leitura que começou em outro contexto.
Map<String, Pergunta>? _roteiro;
Future<Map<String, Pergunta>> carregarRoteiro() async => _roteiro ??=
    lerRoteiro(await rootBundle.loadString('conteudo/emergencia.yaml'));

/// "O que está acontecendo?": botões grandes, uma pergunta por tela.
class TelaEmergencia extends StatefulWidget {
  const TelaEmergencia({super.key, this.perguntaId = 'inicio'});

  final String perguntaId;

  @override
  State<TelaEmergencia> createState() => _TelaEmergenciaState();
}

class _TelaEmergenciaState extends State<TelaEmergencia> {
  late final Future<Map<String, Pergunta>> _roteiroCarregado =
      carregarRoteiro();

  String get perguntaId => widget.perguntaId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergência')),
      body: FutureBuilder<Map<String, Pergunta>>(
        future: _roteiroCarregado,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Erro: ${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data![perguntaId]!;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (perguntaId == 'inicio') ...[
                const BotoesLigar(['192', '193']),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    'Em perigo de vida, ligue primeiro.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  p.texto,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              for (final o in p.opcoes)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _escolher(context, o),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    (o.ligar.isNotEmpty ? corAlerta : corFeixe)
                                        .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                iconesEmergencia[o.icone] ??
                                    Icons.arrow_forward,
                                color: o.ligar.isNotEmpty
                                    ? corAlerta
                                    : corFeixe,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                o.texto,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: corTextoSuave,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _escolher(BuildContext context, Opcao o) async {
    final nav = Navigator.of(context);
    if (o.vai != null) {
      nav.push(
        MaterialPageRoute(builder: (_) => TelaEmergencia(perguntaId: o.vai!)),
      );
      return;
    }
    final todas = await secoesDaCidadeEscolhida();
    final porChave = {for (final s in todas) s.chave: s};
    final escolhidas = [for (final k in o.secoes) ?porChave[k]];
    if (escolhidas.isEmpty) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) =>
            TelaSecoes(titulo: o.texto, secoes: escolhidas, ligar: o.ligar),
      ),
    );
  }
}
