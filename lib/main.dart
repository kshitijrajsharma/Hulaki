import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hulaki/app/app.dart';
import 'package:hulaki/app/env.dart';
import 'package:hulaki/app/providers.dart';
import 'package:hulaki/features/auth/application/auth_providers.dart';
import 'package:hulaki/features/discovery/supabase_public_directory.dart';
import 'package:hulaki/features/identity/supabase_admin_registry.dart';
import 'package:hulaki/features/sync/supabase_blob_store.dart';
import 'package:hulaki/features/sync/supabase_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  final preferences = await SharedPreferences.getInstance();

  SupabaseClient? client;
  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    client = Supabase.instance.client;
    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (client != null) ...[
          transportProvider.overrideWith(
            (ref) => SupabaseTransport(
              client!,
              () => ref.read(deviceIdentityProvider.future),
            ),
          ),
          blobStoreProvider.overrideWithValue(SupabaseBlobStore(client)),
          publicDirectoryProvider.overrideWith(
            (ref) => SupabasePublicDirectory(
              client!,
              () => ref.read(deviceIdentityProvider.future),
            ),
          ),
          adminRegistryProvider.overrideWithValue(
            SupabaseAdminRegistry(client),
          ),
        ],
      ],
      child: const HulakiApp(),
    ),
  );
}
