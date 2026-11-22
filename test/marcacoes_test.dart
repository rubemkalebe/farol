import 'package:farol/dados/marcacoes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('marca, desmarca e limpa só o capítulo pedido', () async {
    final m = await Marcacoes.abrir();
    await m.alternar('preparacao', 'agua');
    await m.alternar('outro', 'agua');
    expect(m.marcado('preparacao', 'agua'), isTrue);

    await m.alternar('preparacao', 'agua');
    expect(m.marcado('preparacao', 'agua'), isFalse);

    await m.alternar('preparacao', 'pilhas');
    await m.limpar('preparacao');
    expect(m.marcado('preparacao', 'pilhas'), isFalse);
    expect(m.marcado('outro', 'agua'), isTrue);
  });

  test('reconhece capítulo com checklist', () {
    expect(temMarcacoes('- [marcar: agua] Água'), isTrue);
    expect(temMarcacoes('- Água'), isFalse);
  });
}
