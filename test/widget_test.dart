import 'package:flutter_test/flutter_test.dart';
import 'package:sensor_track/main.dart';

void main() {
  testWidgets('SensorTrack muestra el inicio después del splash', (
    tester,
  ) async {
    await tester.pumpWidget(const SensorTrackApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sensores del dispositivo'), findsOneWidget);
    expect(find.text('Supabase sin configurar'), findsOneWidget);
  });
}
