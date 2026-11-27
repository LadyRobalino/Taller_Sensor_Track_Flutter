import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../reading.dart';
import '../sensor_theme.dart';

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, this.store, required this.statistics});
  final ReadingStore? store;
  final bool statistics;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  late Future<List<Reading>>? pending = widget.store?.load();

  void details(Reading reading) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reading.sensor.label),
        content: Text('${reading.values}\n\n${reading.time.toLocal()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget statistics(List<Reading> readings) {
    final acceleration = readings
        .where((r) => r.sensor == Sensor.accelerometer)
        .toList();
    final gps = readings.where((r) => r.sensor == Sensor.gps).lastOrNull;
    final chartValues = acceleration
        .skip(math.max(0, acceleration.length - 50))
        .toList();
    final origin = chartValues.firstOrNull?.time;
    final colors = [Colors.teal, Colors.indigo, Colors.deepOrange];
    final axes = <String, double Function(Reading)>{
      'X': (r) => r.x!,
      'Y': (r) => r.y!,
      'Z': (r) => r.z!,
    };
    final lines = <LineChartBarData>[];
    final extrema = <Widget>[];
    for (final axis in axes.entries) {
      final values = acceleration.map(axis.value);
      if (values.isEmpty) continue;
      extrema.add(
        Text(
          '${axis.key} · mín. ${values.reduce(math.min).toStringAsFixed(2)}'
          ' · máx. ${values.reduce(math.max).toStringAsFixed(2)} m/s²',
        ),
      );
      lines.add(
        LineChartBarData(
          color: colors[lines.length],
          spots: [
            for (final r in chartValues)
              FlSpot(
                r.time.difference(origin!).inMilliseconds / 1000,
                axis.value(r),
              ),
          ],
          dotData: FlDotData(show: chartValues.length == 1),
          barWidth: 2,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Total de registros: ${readings.length}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final sensor in Sensor.values)
          Text(
            '${sensor.label}: ${readings.where((r) => r.sensor == sensor).length}',
          ),
        const SizedBox(height: 16),
        const Text('Rangos del acelerómetro'),
        if (extrema.isEmpty) const Text('Sin mediciones.'),
        ...extrema,
        const SizedBox(height: 16),
        const Text('Última ubicación'),
        Text(
          gps == null
              ? 'Sin mediciones.'
              : '${gps.values}\n${gps.time.toLocal()}',
        ),
        if (lines.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Evolución del acelerómetro · últimas 50 lecturas como máximo',
          ),
          const Text(
            'Vertical: m/s² · Horizontal: segundos desde la primera lectura mostrada',
          ),
          Wrap(
            spacing: 16,
            children: [
              for (var i = 0; i < colors.length; i++)
                Text(
                  axes.keys.elementAt(i),
                  style: TextStyle(color: colors[i]),
                ),
            ],
          ),
          SizedBox(
            height: 230,
            child: Padding(
              padding: const EdgeInsets.only(top: 16, right: 20),
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(1.0, lines.first.spots.last.x),
                  lineBarsData: lines,
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store == null)
      return const Center(
        child: Text('Configura Supabase para consultar registros.'),
      );
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Actualizar'),
            onPressed: () => setState(() => pending = widget.store!.load()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Reading>>(
            future: pending,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError)
                return const Center(
                  child: Text('No se pudieron consultar los registros.'),
                );
              final readings = snapshot.data!;
              if (widget.statistics) return statistics(readings);
              if (readings.isEmpty)
                return const Center(
                  child: Text('Aún no tienes mediciones guardadas.'),
                );
              return ListView(
                children: [
                  for (final reading in readings.reversed)
                    Card(
                      child: ListTile(
                        leading: SensorIcon(reading.sensor),
                        title: Text(reading.sensor.label),
                        subtitle: Text(
                          '${reading.values}\n${reading.time.toLocal()}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => details(reading),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
