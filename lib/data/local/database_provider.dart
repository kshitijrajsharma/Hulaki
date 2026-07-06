import 'package:fieldchat/data/local/database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app-wide local database. Closed when the provider is disposed.
final databaseProvider = Provider<LocalDatabase>((ref) {
  final database = LocalDatabase();
  ref.onDispose(database.close);
  return database;
});
