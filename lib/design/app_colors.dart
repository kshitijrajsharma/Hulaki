import 'package:flutter/widgets.dart';

/// Hulaki brand palette.
///
/// Ink leads everything: buttons, the mark, active states. Amber stays
/// reserved for GPS and signal. The background family (paper, then hairline,
/// field, mist) is a near-neutral light grey carrying only a trace of warmth,
/// held close to neutral by design so white cards read cleanly on it.
abstract final class AppColors {
  const AppColors._();

  static const Color ink = Color(0xFF15181B);
  static const Color inkSoft = Color(0xFF1F2421);
  static const Color paper = Color(0xFFF6F6F4);
  static const Color mist = Color(0xFFE7E6E3);
  static const Color white = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFF1F0EE);
  static const Color field = Color(0xFFEEEEEB);

  static const Color textSecondary = Color(0xFF5D584D);
  static const Color textMuted = Color(0xFF8C887F);
  static const Color textFaint = Color(0xFF9A968D);

  static const Color amber = Color(0xFFE0922A);
  static const Color amberText = Color(0xFFA8741A);
  static const Color gpsStrong = Color(0xFF22A75A);
  static const Color gpsGood = Color(0xFF3E8E5A);
  static const Color danger = Color(0xFFC0392B);
}

/// Hot-key tag colours. Each tag carries one of these as its dot and pin
/// colour, and the same colour filters it on the map. Tones are muted and a
/// touch dark so they sit with the warm UI while staying legible on the light
/// map.
abstract final class TagColors {
  const TagColors._();

  static const Color ink = AppColors.ink;
  static const Color amber = Color(0xFFC0801F);
  static const Color purple = Color(0xFF6E5DA6);
  static const Color red = Color(0xFFB0503D);
  static const Color blue = Color(0xFF3466A0);
  static const Color forest = Color(0xFF3C7A4E);
  static const Color teal = Color(0xFF2C7A70);
  static const Color sienna = Color(0xFF8C5A3B);
  static const Color olive = Color(0xFF6F7A35);
  static const Color rose = Color(0xFFA44A72);
  static const Color indigo = Color(0xFF464C88);
  static const Color slate = Color(0xFF566069);

  static const List<Color> palette = <Color>[
    ink,
    amber,
    red,
    sienna,
    olive,
    forest,
    teal,
    blue,
    indigo,
    purple,
    rose,
    slate,
  ];
}
