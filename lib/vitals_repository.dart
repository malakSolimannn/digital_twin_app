import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/vital_reading.dart';

class VitalsRepository {
  VitalsRepository._();

  static const String configError =
      'Supabase is not initialized. Add SUPABASE_URL and SUPABASE_ANON_KEY to your run configuration.';

  static SupabaseClient? get client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<VitalReading?> fetchLatestReading() async {
    final currentClient = client;
    if (currentClient == null) return null;

    final rows =
        await currentClient
            .from('vitals')
            .select()
            .order('created_at', ascending: false)
            .limit(1);
    if (rows.isEmpty) return null;
    return VitalReading.fromMap(Map<String, dynamic>.from(rows.first));
  }

  static Stream<List<VitalReading>> readingsStream({int limit = 50}) {
    final currentClient = client;
    if (currentClient == null) return const Stream<List<VitalReading>>.empty();

    return currentClient
        .from('vitals')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit)
        .map(
          (rows) => rows
              .map((row) => VitalReading.fromMap(Map<String, dynamic>.from(row)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }
}
