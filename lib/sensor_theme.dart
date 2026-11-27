import 'package:flutter/material.dart';

import 'reading.dart';

extension SensorAppearance on Sensor {
  Color get accent => switch (this) {
    Sensor.accelerometer => const Color(0xff4338a5),
    Sensor.gyroscope => const Color(0xff923674),
    Sensor.gps => const Color(0xff087568),
  };

  IconData get icon => switch (this) {
    Sensor.accelerometer => Icons.speed_rounded,
    Sensor.gyroscope => Icons.rotate_right_rounded,
    Sensor.gps => Icons.location_on_rounded,
  };
}

class SensorIcon extends StatelessWidget {
  const SensorIcon(this.sensor, {super.key});

  final Sensor sensor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Color.alphaBlend(sensor.accent.withAlpha(24), Colors.white),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(sensor.icon, color: sensor.accent),
    );
  }
}

const trackGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff29225b), Color(0xff5140a3)],
);
