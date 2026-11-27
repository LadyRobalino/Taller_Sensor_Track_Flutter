import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'reading.dart';
import 'sensor_theme.dart';

class MotionPage extends StatefulWidget {
  const MotionPage({
    super.key,
    required this.onSave,
    required this.onAvailability,
  });

  final Future<void> Function(Reading) onSave;
  final void Function(Sensor, String) onAvailability;

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  final readings = <Sensor, Reading>{};
  final errors = <Sensor>{};
  final saving = <Sensor>{};
  final subscriptions = <StreamSubscription<Reading>>[];
  bool active = false;

  @override
  void initState() {
    super.initState();
    start();
  }

  void start() {
    active = true;
    readings.clear();
    errors.clear();
    listen(
      Sensor.accelerometer,
      accelerometerEventStream(
        samplingPeriod: const Duration(milliseconds: 150),
      ).map(
        (e) =>
            Reading(Sensor.accelerometer, e.timestamp, x: e.x, y: e.y, z: e.z),
      ),
    );
    listen(
      Sensor.gyroscope,
      gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 150))
          .map(
            (e) =>
                Reading(Sensor.gyroscope, e.timestamp, x: e.x, y: e.y, z: e.z),
          ),
    );
  }

  void listen(Sensor sensor, Stream<Reading> stream) {
    subscriptions.add(
      stream.listen(
        (reading) {
          if (!mounted || !active) return;
          if (!readings.containsKey(sensor) || errors.contains(sensor)) {
            widget.onAvailability(sensor, 'Disponible');
          }
          setState(() {
            readings[sensor] = reading;
            errors.remove(sensor);
          });
        },
        onError: (Object error) {
          if (!mounted || !active) return;
          widget.onAvailability(sensor, 'Sin lectura');
          setState(() => errors.add(sensor));
        },
      ),
    );
  }

  void stop() {
    active = false;
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> save(Reading reading) async {
    setState(() => saving.add(reading.sensor));
    try {
      await widget.onSave(reading);
    } finally {
      if (mounted) setState(() => saving.remove(reading.sensor));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(active ? stop : start),
          icon: Icon(active ? Icons.pause : Icons.play_arrow),
          label: Text(active ? 'Pausar monitoreo' : 'Iniciar monitoreo'),
        ),
        for (final sensor in [Sensor.accelerometer, Sensor.gyroscope])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SensorIcon(sensor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          sensor.label,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: sensor.accent,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errors.contains(sensor)
                        ? 'No se pudo leer el sensor.'
                        : readings[sensor]?.values ??
                              'Esperando la primera lectura…',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: sensor.accent,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        readings[sensor] == null ||
                            errors.contains(sensor) ||
                            saving.contains(sensor)
                        ? null
                        : () => save(readings[sensor]!),
                    child: Text(
                      saving.contains(sensor)
                          ? 'Guardando…'
                          : 'Guardar medición',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
