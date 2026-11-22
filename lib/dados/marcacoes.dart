import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:shared_preferences/shared_preferences.dart';

/// Itens de checklist marcados pelo usuário, guardados só no aparelho.
/// A chave é `marcado:<capítulo>:<item>`.
class Marcacoes extends ChangeNotifier {
  Marcacoes._(this._prefs);

  final SharedPreferences _prefs;

  static Future<Marcacoes> abrir() async =>
      Marcacoes._(await SharedPreferences.getInstance());

  String _chave(String capitulo, String item) => 'marcado:$capitulo:$item';

  bool marcado(String capitulo, String item) =>
      _prefs.getBool(_chave(capitulo, item)) ?? false;

  Future<void> alternar(String capitulo, String item) async {
    await _prefs.setBool(_chave(capitulo, item), !marcado(capitulo, item));
    notifyListeners();
  }

  Future<void> limpar(String capitulo) async {
    for (final k
        in _prefs
            .getKeys()
            .where((k) => k.startsWith('marcado:$capitulo:'))
            .toList()) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }
}

/// Reconhece `[marcar: id]`, que vira uma caixa de marcar no app.
class SintaxeMarcar extends md.InlineSyntax {
  SintaxeMarcar() : super(r'\[marcar: ([a-z0-9-]+)\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('marcar', match.group(1)!));
    return true;
  }
}

final _marcaItem = RegExp(r'\[marcar: ([a-z0-9-]+)\]');

/// Ids dos itens de checklist presentes no texto.
List<String> itensDeChecklist(String markdown) => [
  for (final m in _marcaItem.allMatches(markdown)) m.group(1)!,
];

bool temMarcacoes(String markdown) => _marcaItem.hasMatch(markdown);
