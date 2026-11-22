import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ficha da família. Fica só no aparelho (shared_preferences), nunca sai
/// dele a não ser que o usuário compartilhe.
class Pessoa {
  Pessoa({
    this.nome = '',
    this.nascimento = '',
    this.tipoSanguineo = '',
    this.alergias = '',
    this.doencas = '',
    this.remedios = '',
    this.cartaoSus = '',
    this.planoSaude = '',
    this.observacoes = '',
  });

  String nome;
  String nascimento;
  String tipoSanguineo;
  String alergias;
  String doencas;
  String remedios;
  String cartaoSus;
  String planoSaude;
  String observacoes;

  Map<String, String> toJson() => {
        'nome': nome,
        'nascimento': nascimento,
        'tipoSanguineo': tipoSanguineo,
        'alergias': alergias,
        'doencas': doencas,
        'remedios': remedios,
        'cartaoSus': cartaoSus,
        'planoSaude': planoSaude,
        'observacoes': observacoes,
      };

  factory Pessoa.fromJson(Map<String, dynamic> j) => Pessoa(
        nome: j['nome'] ?? '',
        nascimento: j['nascimento'] ?? '',
        tipoSanguineo: j['tipoSanguineo'] ?? '',
        alergias: j['alergias'] ?? '',
        doencas: j['doencas'] ?? '',
        remedios: j['remedios'] ?? '',
        cartaoSus: j['cartaoSus'] ?? '',
        planoSaude: j['planoSaude'] ?? '',
        observacoes: j['observacoes'] ?? '',
      );
}

class Contato {
  Contato({this.nome = '', this.relacao = '', this.telefone = ''});

  String nome;
  String relacao;
  String telefone;

  Map<String, String> toJson() => {'nome': nome, 'relacao': relacao, 'telefone': telefone};

  factory Contato.fromJson(Map<String, dynamic> j) =>
      Contato(nome: j['nome'] ?? '', relacao: j['relacao'] ?? '', telefone: j['telefone'] ?? '');
}

class Ficha {
  Ficha({
    this.endereco = '',
    this.referencia = '',
    this.pontoEncontro = '',
    this.instalacaoEnergia = '',
    List<Pessoa>? pessoas,
    List<Contato>? contatos,
  })  : pessoas = pessoas ?? [],
        contatos = contatos ?? [];

  String endereco;
  String referencia;
  String pontoEncontro;
  String instalacaoEnergia;
  final List<Pessoa> pessoas;
  final List<Contato> contatos;

  static const _chave = 'ficha';

  static Future<Ficha> abrir() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_chave);
    if (texto == null) return Ficha();
    final j = jsonDecode(texto) as Map<String, dynamic>;
    return Ficha(
      endereco: j['endereco'] ?? '',
      referencia: j['referencia'] ?? '',
      pontoEncontro: j['pontoEncontro'] ?? '',
      instalacaoEnergia: j['instalacaoEnergia'] ?? '',
      pessoas: [for (final p in (j['pessoas'] as List? ?? [])) Pessoa.fromJson(p)],
      contatos: [for (final c in (j['contatos'] as List? ?? [])) Contato.fromJson(c)],
    );
  }

  Future<void> salvar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chave,
      jsonEncode({
        'endereco': endereco,
        'referencia': referencia,
        'pontoEncontro': pontoEncontro,
        'instalacaoEnergia': instalacaoEnergia,
        'pessoas': [for (final p in pessoas) p.toJson()],
        'contatos': [for (final c in contatos) c.toJson()],
      }),
    );
  }

  /// Texto para copiar, compartilhar ou mostrar ao socorrista.
  /// Campos vazios não aparecem.
  String comoTexto() {
    final b = StringBuffer('FICHA DA FAMÍLIA\n');
    void linha(String rotulo, String valor) {
      if (valor.trim().isNotEmpty) b.writeln('$rotulo: ${valor.trim()}');
    }

    linha('Endereço', endereco);
    linha('Ponto de referência', referencia);
    linha('Ponto de encontro', pontoEncontro);
    linha('Nº da instalação (energia)', instalacaoEnergia);
    for (final p in pessoas) {
      b.writeln('\n${p.nome.trim().isEmpty ? 'Pessoa sem nome' : p.nome.trim().toUpperCase()}');
      linha('Nascimento', p.nascimento);
      linha('Tipo sanguíneo', p.tipoSanguineo);
      linha('Alergias', p.alergias);
      linha('Doenças', p.doencas);
      linha('Remédios e doses', p.remedios);
      linha('Cartão SUS', p.cartaoSus);
      linha('Plano de saúde', p.planoSaude);
      linha('Observações', p.observacoes);
    }
    if (contatos.isNotEmpty) {
      b.writeln('\nCONTATOS');
      for (final c in contatos) {
        final rel = c.relacao.trim().isEmpty ? '' : ' (${c.relacao.trim()})';
        b.writeln('${c.nome.trim()}$rel: ${c.telefone.trim()}');
      }
    }
    return b.toString().trimRight();
  }
}
