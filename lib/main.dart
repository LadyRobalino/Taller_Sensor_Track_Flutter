import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'accelerometer_page.dart';
import 'location_page.dart';
import 'reading.dart';
import 'records_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  ReadingStore? store;
  String? setupMessage;
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      store = ReadingStore(Supabase.instance.client);
    } catch (_) {
      setupMessage = 'Verifica la URL y la clave pública de Supabase.';
    }
  }
  runApp(SensorTrackApp(store: store, setupMessage: setupMessage));
}

class SensorTrackApp extends StatelessWidget {
  const SensorTrackApp({super.key, this.store, this.setupMessage});
  final ReadingStore? store;
  final String? setupMessage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SensorTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xff205d63)),
      home: Dashboard(store: store, setupMessage: setupMessage),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key, this.store, this.setupMessage});
  final ReadingStore? store;
  final String? setupMessage;

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final availability = <Sensor, String>{};
  static const titles = [
    'Inicio',
    'Sensores',
    'Ubicación',
    'Historial',
    'Estadísticas',
  ];
  int tab = 0;
  bool splash = true;
  bool checking = false;
  String status = 'Supabase sin configurar';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    status = widget.setupMessage ?? status;
    timer = Timer(const Duration(milliseconds: 850), () {
      setState(() => splash = false);
      unawaited(check());
      unawaited(detectSensors());
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> detectSensors() async {
    const hardware = MethodChannel('sensor_track/hardware');
    try {
      final supported = await hardware.invokeMapMethod<String, bool>(
        'availableSensors',
      );
      if (!mounted || supported == null) return;
      setState(() {
        for (final sensor in Sensor.values) {
          final present = supported[sensor.name];
          if (present != null) {
            availability.putIfAbsent(
              sensor,
              () => present ? 'Disponible' : 'No disponible',
            );
          }
        }
      });
    } on MissingPluginException {
      // On other platforms, each screen reports availability when used.
    } on PlatformException {
      // Keep the manual check available through the sensor screens.
    }
  }

  Future<void> check() async {
    final store = widget.store;
    if (store == null || checking) return;
    setState(() {
      checking = true;
      status = 'Comprobando conexión…';
    });
    String result;
    try {
      await store.check();
      result = 'Supabase conectado';
    } catch (_) {
      result = 'Sin conexión a la tabla. Revisa la red y la configuración.';
    }
    if (mounted)
      setState(() {
        status = result;
        checking = false;
      });
  }

  void report(Sensor sensor, String value) {
    setState(() => availability[sensor] = value);
  }

  Future<void> save(Reading value) async {
    final store = widget.store;
    String message;
    if (store == null) {
      message = 'Configura Supabase para guardar mediciones.';
    } else {
      try {
        await store.save(value);
        message = 'Medición guardada.';
      } catch (_) {
        message = 'No se pudo confirmar el guardado. Revisa la conexión y el historial.';
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void select(int value) => setState(() => tab = value);

  Widget home() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text(status, style: Theme.of(context).textTheme.titleMedium),
      if (widget.store != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: checking ? null : check,
            child: const Text('Verificar conexión'),
          ),
        ),
      const SizedBox(height: 20),
      Text(
        'Sensores del dispositivo',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      for (final sensor in Sensor.values)
        ListTile(
          title: Text(sensor.label),
          subtitle: Text(availability[sensor] ?? 'Por comprobar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => select(sensor == Sensor.gps ? 2 : 1),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (splash)
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sensors, size: 68),
              SizedBox(height: 12),
              Text('SensorTrack', style: TextStyle(fontSize: 30)),
            ],
          ),
        ),
      );

    final page = switch (tab) {
      0 => home(),
      1 => MotionPage(onSave: save, onAvailability: report),
      2 => LocationPage(onSave: save, onAvailability: report),
      _ => RecordsPage(
        key: ValueKey(tab),
        store: widget.store,
        statistics: tab == 4,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(tab == 0 ? 'SensorTrack' : titles[tab])),
      body: SafeArea(child: page),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: select,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Inicio',
          ),
          NavigationDestination(icon: Icon(Icons.sensors), label: 'Sensores'),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Ubicación',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(
            icon: Icon(Icons.show_chart),
            label: 'Estadísticas',
          ),
        ],
      ),
    );
  }
}
