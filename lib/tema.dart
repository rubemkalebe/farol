import 'package:flutter/material.dart';

// Paleta do Farol. Fundo quase preto: em tela OLED, pixel preto fica
// apagado e não gasta bateria. A luz é o amarelo do feixe do farol.
const corNoite = Color(0xFF040507);
const corSuperficie = Color(0xFF0F131A);
const corSuperficieAlta = Color(0xFF161B24);
const corBorda = Color(0xFF242C3A);
const corFeixe = Color(0xFFFFD34E);
const corFeixeSuave = Color(0x33FFD34E);
const corTexto = Color(0xFFE9EEF6);
const corTextoSuave = Color(0xFF9AA5B5);
// Orientação sem fonte oficial: cor distinta do amarelo das fontes.
const corAviso = Color(0xFF8FB8DE);
// Emergência: botões de ligar e o "O que está acontecendo?".
// corAlerta é para ícone e texto vermelho sobre o fundo escuro (5,7:1).
// Fundo de botão com texto branco usa corAlertaFundo (4,8:1) → corAlertaEscuro
// (6,9:1): o vermelho claro com branco por cima ficaria em 3,3:1, abaixo do
// mínimo de 4,5:1 da WCAG.
const corAlerta = Color(0xFFFF4D57);
const corAlertaFundo = Color(0xFFD92B36);
const corAlertaEscuro = Color(0xFFB3141F);
// Contorno de campo (busca, formulário): 3:1 sobre o fundo, como pede a WCAG
// para componentes; a borda dos cartões é só decorativa.
const corContorno = Color(0xFF6B778A);

const fonteFarol = 'Atkinson';

final _base = ThemeData(
  useMaterial3: true,
  fontFamily: fonteFarol,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: corNoite,
  colorScheme: const ColorScheme.dark(
    primary: corFeixe,
    onPrimary: Color(0xFF1A1300),
    secondary: corAviso,
    error: corAlerta,
    surface: corSuperficie,
    onSurface: corTexto,
    surfaceContainerHighest: corSuperficieAlta,
    outline: corBorda,
    outlineVariant: corBorda,
  ),
  dividerColor: corBorda,
  appBarTheme: const AppBarTheme(
    backgroundColor: corNoite,
    foregroundColor: corTexto,
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: corTexto,
      letterSpacing: -0.2,
    ),
  ),
  cardTheme: CardThemeData(
    color: corSuperficie,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: corBorda),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: corSuperficie,
    hintStyle: const TextStyle(color: corTextoSuave),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: corContorno),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: corContorno),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: corFeixe, width: 1.5),
    ),
  ),
  chipTheme: const ChipThemeData(
    backgroundColor: corSuperficie,
    side: BorderSide(color: corBorda),
    shape: StadiumBorder(),
    labelStyle: TextStyle(color: corTexto, fontWeight: FontWeight.w600),
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: corSuperficieAlta,
    surfaceTintColor: Colors.transparent,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: corSuperficieAlta,
    surfaceTintColor: Colors.transparent,
  ),
  listTileTheme: const ListTileThemeData(iconColor: corFeixe),
);

// O textTheme do ThemeData ainda não tem tamanhos; eles vêm da geometria
// da Typography, por isso a fusão antes de aumentar.
final _tipografia = Typography.material2021();

// Letra maior que o padrão: leitura em tela com brilho baixo.
final temaFarol = _base.copyWith(
  textTheme: _tipografia.englishLike
      .merge(_tipografia.white)
      .apply(
        fontFamily: fonteFarol,
        fontSizeFactor: 1.15,
        bodyColor: corTexto,
        displayColor: corTexto,
      ),
);
