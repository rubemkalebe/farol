import 'package:flutter/material.dart';

const corNoite = Color(0xFF0B1320);
const corSuperficie = Color(0xFF16213A);
const corFeixe = Color(0xFFFFD34E);
const corTexto = Color(0xFFE9EEF6);
// Orientação sem fonte oficial: cor distinta do amarelo das fontes.
const corAviso = Color(0xFF8FB8DE);

final _base = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: corNoite,
  colorScheme: ColorScheme.fromSeed(
    seedColor: corFeixe,
    brightness: Brightness.dark,
    primary: corFeixe,
    surface: corSuperficie,
    onSurface: corTexto,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: corNoite,
    foregroundColor: corTexto,
  ),
);

// Letra maior que o padrão: leitura em tela com brilho baixo.
// O textTheme do ThemeData ainda não tem tamanhos; eles vêm da geometria
// da Typography, por isso a fusão antes de aumentar.
final _tipografia = Typography.material2021();

final temaFarol = _base.copyWith(
  textTheme: _tipografia.englishLike.merge(_tipografia.white).apply(
    fontSizeFactor: 1.15,
    bodyColor: corTexto,
    displayColor: corTexto,
  ),
);
