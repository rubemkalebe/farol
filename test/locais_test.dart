import 'dart:io';

import 'package:farol/dados/locais.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

Future<String> lerDisco(String caminho) async => File(caminho).readAsString();
YamlMap abrir(String caminho) => loadYaml(File(caminho).readAsStringSync()) as YamlMap;

void main() {
  final capitulos = {
    for (final f in Directory('conteudo/capitulos').listSync().whereType<File>())
      f.uri.pathSegments.last: f.readAsStringSync(),
  };
  final padrao = abrir('locais/padrao.yaml');
  final blocosPadrao = {for (final k in (padrao['blocos'] as YamlMap).keys) k as String};
  final fontes = {
    for (final f in (abrir('fontes/fontes.yaml')['fontes'] as YamlList)) f['id'] as String,
  };
  final arquivosLocais = Directory('locais').listSync(recursive: true).whereType<File>().toList();
  final empresas = {
    for (final f in Directory('locais/empresas').listSync().whereType<File>())
      f.uri.pathSegments.last.replaceAll('.yaml', ''): abrir(f.path),
  };

  test('o índice lista exatamente os arquivos de cidade', () async {
    final noIndice = {for (final c in await carregarCidades(ler: lerDisco)) c.id};
    final noDisco = {
      for (final f in Directory('locais/cidades').listSync(recursive: true).whereType<File>())
        f.path.replaceFirst('locais/cidades/', '').replaceAll('.yaml', ''),
    };
    expect(noIndice, noDisco);
  });

  test('todo bloco usado nos capítulos existe no padrão (Outra cidade)', () {
    for (final MapEntry(:key, :value) in capitulos.entries) {
      for (final m in marcasLocais(value)) {
        expect(blocosPadrao, contains(m), reason: '$key usa {{$m}}, que falta em locais/padrao.yaml');
      }
    }
  });

  test('arquivos locais só definem blocos conhecidos e têm data de conferência', () {
    for (final f in arquivosLocais.where((f) => !f.path.endsWith('indice.yaml'))) {
      final y = abrir(f.path);
      expect(y['verificado_em'], isNotNull, reason: '${f.path} sem verificado_em');
      for (final k in ((y['blocos'] as YamlMap?) ?? YamlMap()).keys) {
        expect(blocosPadrao, contains(k), reason: '${f.path} define "$k", que não existe no padrão');
      }
    }
  });

  test('cidades apontam para estado e empresas que existem, do tipo certo', () {
    for (final f in Directory('locais/cidades').listSync(recursive: true).whereType<File>()) {
      final c = abrir(f.path);
      expect(File('locais/estados/${c['uf']}.yaml').existsSync(), isTrue, reason: f.path);
      for (final tipo in ['energia', 'agua', 'gas']) {
        final e = c[tipo] as String?;
        if (e == null) continue;
        expect(empresas[e], isNotNull, reason: '${f.path}: empresa "$e" não existe');
        expect(empresas[e]!['tipo'], tipo, reason: '${f.path}: "$e" não é de $tipo');
      }
    }
  });

  test('citações, links de telefone e pubspec dos arquivos locais', () {
    final citacao = RegExp(r'\[fonte: ([a-z0-9-]+)\]');
    final tel = RegExp(r'\]\((tel|sms):([^)]*)\)');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final f in arquivosLocais) {
      final texto = f.readAsStringSync();
      for (final m in citacao.allMatches(texto)) {
        expect(fontes, contains(m.group(1)), reason: '${f.path} cita fonte inexistente ${m.group(1)}');
      }
      for (final m in tel.allMatches(texto)) {
        expect(RegExp(r'^[0-9]+$').hasMatch(m.group(2)!), isTrue, reason: '${f.path}: ${m.group(0)}');
      }
      final pasta = f.parent.path.endsWith('/') ? f.parent.path : '${f.parent.path}/';
      expect(pubspec, contains('- $pasta'), reason: 'pubspec.yaml não inclui $pasta nos assets');
    }
  });

  test('cada cidade só vê os próprios serviços e checklists sem id repetido', () async {
    final cidades = await carregarCidades(ler: lerDisco);
    final nomesEmpresas = {for (final MapEntry(:key, :value) in empresas.entries) key: value['nome'] as String};
    final citacao = RegExp(r'\[fonte: [a-z0-9-]+\]');
    final marcar = RegExp(r'\[marcar: ([a-z0-9-]+)\]');
    for (final id in [...cidades.map((c) => c.id), null]) {
      final blocos = await blocosLocais(id, ler: lerDisco);
      final c = id == null ? null : abrir('locais/cidades/$id.yaml');
      final minhas = {if (c != null) for (final t in ['energia', 'agua', 'gas']) c[t]};
      final outrasCidades = cidades.where((x) => x.id != id).map((x) => x.nome);
      for (final MapEntry(key: cap, value: bruto) in capitulos.entries) {
        final texto = aplicarLocais(bruto, blocos).replaceAll(citacao, '');
        expect(texto.contains('{{'), isFalse, reason: '$cap para $id ficou com {{');
        for (final MapEntry(key: emp, value: nome) in nomesEmpresas.entries) {
          if (!minhas.contains(emp)) {
            expect(texto.contains(nome), isFalse, reason: '$cap mostra $nome para ${id ?? 'outra'}');
          }
        }
        for (final nome in outrasCidades) {
          expect(texto.contains(nome), isFalse, reason: '$cap mostra "$nome" para ${id ?? 'outra'}');
        }
        final ids = [for (final m in marcar.allMatches(texto)) m.group(1)];
        expect(ids.toSet().length, ids.length, reason: '$cap repete id de checklist para $id');
      }
    }
  });
}
