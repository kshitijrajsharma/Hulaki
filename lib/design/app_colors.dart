import 'package:flutter/widgets.dart';

/// FieldChat brand palette.
///
/// Ink leads everything: buttons, the mark, active states. Amber stays
/// reserved for GPS and signal. Paper is the app background, mist the
/// surface and divider tone.
abstract final class AppColors {
  const AppColors._();

  static const Color ink = Color(0xFF15181B);
  static const Color inkSoft = Color(0xFF1F2421);
  static const Color paper = Color(0xFFF6F4EE);
  static const Color mist = Color(0xFFECE7DF);
  static const Color white = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFF2EEE6);
  static const Color field = Color(0xFFF0ECDF);

  static const Color textSecondary = Color(0xFF5D584D);
  static const Color textMuted = Color(0xFF8C887F);
  static const Color textFaint = Color(0xFF9A968D);

  static const Color amber = Color(0xFFE0922A);
  static const Color amberText = Color(0xFFA8741A);
  static const Color gpsStrong = Color(0xFF22A75A);
  static const Color danger = Color(0xFFC0392B);
}

/// Hot-key tag colours. Each tag carries one of these as its dot and pin
/// colour, and the same colour filters it on the map.
abstract final class TagColors {
  const TagColors._();

  static const Color ink = AppColors.ink;
  static const Color amber = AppColors.amber;
  static const Color purple = Color(0xFF7B6FC4);
  static const Color red = Color(0xFFC4615E);
  static const Color blue = Color(0xFF3E7CC4);

  static const List<Color> palette = <Color>[ink, amber, purple, red, blue];
}
