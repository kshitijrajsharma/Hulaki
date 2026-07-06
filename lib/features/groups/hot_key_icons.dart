import 'package:flutter/material.dart';

/// The curated set of Material Symbols a hot-key can carry, keyed by a stable
/// name that is persisted and exported. Keeping the names stable means an icon
/// survives sync and reopening the app; the [IconData] is looked up for display
/// and for rendering the map pin.
const Map<String, IconData> kHotKeyIcons = {
  'delete': Icons.delete,
  'recycling': Icons.recycling,
  'cleaning': Icons.cleaning_services,
  'streetlight': Icons.lightbulb,
  'bolt': Icons.bolt,
  'tree': Icons.park,
  'forest': Icons.forest,
  'grass': Icons.grass,
  'water': Icons.water_drop,
  'flood': Icons.water,
  'crossing': Icons.directions_walk,
  'traffic': Icons.traffic,
  'parking': Icons.local_parking,
  'bus': Icons.directions_bus,
  'bike': Icons.pedal_bike,
  'road': Icons.add_road,
  'construction': Icons.construction,
  'warning': Icons.warning,
  'hazard': Icons.report_problem,
  'pothole': Icons.dangerous,
  'fence': Icons.fence,
  'house': Icons.house,
  'store': Icons.store,
  'hospital': Icons.local_hospital,
  'school': Icons.school,
  'water_tap': Icons.plumbing,
  'fire': Icons.local_fire_department,
  'sign': Icons.signpost,
  'flag': Icons.flag,
  'place': Icons.place,
  'camera': Icons.camera_alt,
  'pets': Icons.pets,
  'agriculture': Icons.agriculture,
  'toilet': Icons.wc,
  'trash_bin': Icons.delete_outline,
  'star': Icons.star,
};

/// Resolves a stored icon name to its glyph, or null when the hot-key has none.
IconData? hotKeyIcon(String? name) => name == null ? null : kHotKeyIcons[name];
