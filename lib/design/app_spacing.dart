/// Spacing scale used across FieldChat. One ramp, no ad-hoc values.
abstract final class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii for the recurring surfaces: chips, cards, bubbles, sheets
/// and inputs.
abstract final class AppRadii {
  const AppRadii._();

  static const double chip = 22;
  static const double card = 16;
  static const double bubble = 14;
  static const double sheet = 20;
  static const double field = 12;
  static const double avatar = 14;
}
