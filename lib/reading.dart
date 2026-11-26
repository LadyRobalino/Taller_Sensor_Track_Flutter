import 'package:supabase_flutter/supabase_flutter.dart';

enum Sensor {
  accelerometer('Acelerómetro', 'm/s²'),
  gyroscope('Giroscopio', 'rad/s'),
  gps('GPS', 'm');

  const Sensor(this.label, this.unit);
  final String label;
  final String unit;
}

class Reading {
  const Reading(
    this.sensor,
    this.time, {
    this.x,
    this.y,
    this.z,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  factory Reading.fromJson(Map<String, dynamic> row) {
    double? number(String key) => (row[key] as num?)?.toDouble();
    return Reading(
      Sensor.values.byName(row['sensor_type'] as String),
      DateTime.parse(row['recorded_at'] as String),
      x: number('x'),
      y: number('y'),
      z: number('z'),
      latitude: number('latitude'),
      longitude: number('longitude'),
      accuracy: number('accuracy'),
    );
  }

  final Sensor sensor;
  final DateTime time;
  final double? x, y, z, latitude, longitude, accuracy;

  String get values => sensor == Sensor.gps
      ? 'Latitud: ${latitude?.toStringAsFixed(6)}\n'
            'Longitud: ${longitude?.toStringAsFixed(6)}\n'
            'Precisión: ${accuracy?.toStringAsFixed(1)} m'
      : 'X: ${x?.toStringAsFixed(2)} · Y: ${y?.toStringAsFixed(2)} · '
            'Z: ${z?.toStringAsFixed(2)} ${sensor.unit}';

  Map<String, dynamic> toJson() => {
    'sensor_type': sensor.name,
    'recorded_at': time.toUtc().toIso8601String(),
    'x': x,
    'y': y,
    'z': z,
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
  };
}

class ReadingStore {
  ReadingStore(this.client);
  final SupabaseClient client;
  Future<void>? _signIn;

  Future<void> signIn() async {
    if (client.auth.currentSession != null) return;
    try {
      await (_signIn ??= client.auth.signInAnonymously().then<void>((_) {}));
    } finally {
      _signIn = null;
    }
  }

  Future<void> save(Reading reading) async {
    await signIn();
    await client.from('sensor_readings').insert(reading.toJson());
  }

  Future<List<Reading>> load() async {
    await signIn();
    final readings = <Reading>[];
    const pageSize = 500;
    for (var offset = 0; ; offset += pageSize) {
      final rows = await client
          .from('sensor_readings')
          .select()
          .order('recorded_at')
          .order('id')
          .range(offset, offset + pageSize - 1);
      readings.addAll(rows.map(Reading.fromJson));
      if (rows.length < pageSize) return readings;
    }
  }

  Future<void> check() async {
    await signIn();
    await client.from('sensor_readings').select('id').limit(1);
  }
}
