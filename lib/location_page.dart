import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'reading.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({
    super.key,
    required this.onSave,
    required this.onAvailability,
  });

  final Future<void> Function(Reading) onSave;
  final void Function(Sensor, String) onAvailability;

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Reading? reading;
  String? message;
  bool busy = false;

  Future<void> locate() async {
    setState(() {
      busy = true;
      message = null;
      reading = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Activa la ubicación del teléfono e inténtalo de nuevo.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw StateError(
          'Habilita el permiso de ubicación en los ajustes de la app.',
        );
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        throw StateError('Se necesita permiso para consultar tu ubicación.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      widget.onAvailability(Sensor.gps, 'Disponible');
      setState(
        () => reading = Reading(
          Sensor.gps,
          position.timestamp,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      widget.onAvailability(Sensor.gps, 'Sin lectura');
      setState(
        () => message = error is StateError
            ? error.message.toString()
            : 'No se pudo obtener la ubicación. Inténtalo en un lugar abierto.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save(Reading value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar ubicación'),
        content: const Text(
          'Se enviarán tus coordenadas y la hora de captura a Supabase.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => busy = true);
    try {
      await widget.onSave(value);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = reading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: busy ? null : locate,
          icon: const Icon(Icons.my_location),
          label: const Text('Obtener ubicación'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(message!),
        if (value != null) ...[
          const SizedBox(height: 16),
          Text(value.values),
          Text(value.time.toLocal().toString()),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: busy ? null : () => save(value),
            child: const Text('Guardar medición'),
          ),
        ],
      ],
    );
  }
}
