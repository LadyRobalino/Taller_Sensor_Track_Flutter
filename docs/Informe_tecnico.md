# Informe técnico de SensorTrack

## Objetivo

SensorTrack permite observar datos de movimiento del teléfono, consultar su ubicación y guardar lecturas para revisar su evolución. La interfaz se implementa en Flutter y los registros se almacenan en PostgreSQL mediante Supabase.

## Arquitectura

| Componente | Responsabilidad |
|---|---|
| `lib/main.dart` | Inicializa Supabase cuando recibe la URL y la clave pública. Presenta el splash, la navegación y el estado de conexión. |
| `lib/pages/accelerometer_page.dart` | Se suscribe al acelerómetro y al giroscopio mediante `sensors_plus`, actualiza los tres ejes de cada sensor y cancela las suscripciones al pausar o salir. |
| `lib/pages/location_page.dart` | Usa `geolocator` para pedir permiso, obtener una posición y mostrar coordenadas, precisión y fecha. Solicita confirmación al guardar la ubicación. |
| `lib/reading.dart` | Representa las mediciones y concentra las operaciones de lectura y escritura en Supabase. |
| `lib/pages/records_page.dart` | Consulta el historial, muestra detalles y calcula conteos, rangos y la última ubicación. Dibuja con `fl_chart` los tres ejes del acelerómetro según el tiempo de captura. |

## Flujo de una medición

El sensor entrega una lectura con marca de tiempo. Flutter muestra los valores y espera a que la persona pulse **Guardar medición**. El repositorio convierte la lectura a JSON e inserta una fila en `sensor_readings`. Los sensores de movimiento guardan X, Y y Z. El GPS guarda latitud, longitud y precisión. Todas las lecturas guardan la fecha y hora de captura, que la app presenta en hora local.

La captura continua se limita a la pantalla de sensores y puede pausarse. El guardado es manual. Cada instalación inicia una sesión anónima en Supabase y el SQL restringe la lectura y escritura a las filas de esa sesión mediante RLS.

## Verificación en el dispositivo

Mover e inclinar el teléfono permite comprobar las variaciones del acelerómetro. Al rotarlo se observan los cambios en el giroscopio. Se debe validar el permiso GPS, guardar una medición de cada tipo y comparar los datos que aparecen en Supabase, Historial y Estadísticas. Las evidencias se obtienen durante la ejecución en el teléfono físico.

## Explicación del código por archivo

### 1 Inicio y navegación

[`lib/main.dart`](../lib/main.dart)

main() prepara Flutter, lee los valores pasados con --dart-define e inicializa Supabase cuando ambos están presentes. SensorTrackApp configura el tema y abre Dashboard, que controla el estado de conexión y la pestaña activa.

#### Arranque de la aplicación

[Líneas 13–28 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/main.dart#L13-L28)

```dart
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
```

ensureInitialized() permite inicializar Supabase antes de runApp(). Si la configuración falta o la inicialización falla, la aplicación puede abrirse y el Dashboard muestra el estado correspondiente.

#### Selección de pantalla

[Líneas 251–260 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/main.dart#L251-L260)

```dart
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
```

El índice de NavigationBar selecciona Inicio, Sensores, Ubicación, Historial o Estadísticas. Historial y Estadísticas comparten RecordsPage. El argumento statistics diferencia ambas vistas y ValueKey(tab) distingue su estado. Dashboard.check() comprueba el acceso a la tabla y Dashboard.save() muestra el resultado del guardado.

**Cómo explicarlo al docente.** main.dart reúne las pantallas y les pasa las funciones que necesitan. Los botones de Sensores y Ubicación terminan llamando al mismo método de guardado.

### 2 Acelerómetro y giroscopio

[`lib/pages/accelerometer_page.dart`](../lib/pages/accelerometer_page.dart)

MotionPage empieza el monitoreo en initState(). Solicita lecturas a sensors_plus con un intervalo de 150 ms y transforma cada evento en un objeto Reading. El acelerómetro entrega m/s² y el giroscopio rad/s.

#### Conversión de eventos a mediciones

[Líneas 40–48 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/pages/accelerometer_page.dart#L40-L48)

```dart
listen(
  Sensor.accelerometer,
  accelerometerEventStream(
    samplingPeriod: const Duration(milliseconds: 150),
  ).map(
    (e) =>
        Reading(Sensor.accelerometer, e.timestamp, x: e.x, y: e.y, z: e.z),
  ),
);
```

#### Actualización de valores en pantalla

[Líneas 62–70 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/pages/accelerometer_page.dart#L62-L70)

```dart
(reading) {
  if (!mounted || !active) return;
  if (!readings.containsKey(sensor) || errors.contains(sensor)) {
    widget.onAvailability(sensor, 'Disponible');
  }
  setState(() {
    readings[sensor] = reading;
    errors.remove(sensor);
  });
```

readings conserva la lectura más reciente de cada sensor. setState() hace que el widget actualice sus tarjetas. Si llega un error, la pantalla informa que el sensor se quedó sin lectura. mounted comprueba que la pantalla siga existiendo y active comprueba que el monitoreo siga encendido.

stop() cancela las suscripciones al pausar el monitoreo. dispose() también llama a stop() al salir. Al pulsar Guardar medición, save() pasa una sola lectura al callback onSave y evita otro guardado del mismo sensor mientras espera la respuesta.

**Cómo explicarlo al docente.** El flujo actualiza la pantalla. El botón de guardado decide cuál de esas lecturas se conserva en Supabase.

### 3 Obtención y guardado de ubicación

[`lib/pages/location_page.dart`](../lib/pages/location_page.dart)

LocationPage utiliza geolocator. locate() comprueba que el servicio de ubicación esté encendido, revisa el permiso y lo solicita si hace falta. Si el permiso se denegó de forma permanente, la app indica que debe habilitarse desde los ajustes.

#### Captura de una posición GPS

[Líneas 51–67 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/pages/location_page.dart#L51-L67)

```dart
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
```

Se pide una posición de alta precisión con un límite de espera de 25 segundos. position.timestamp aporta la hora de la lectura. busy impide iniciar otra operación mientras hay una captura o un guardado en curso.

#### Guardado tras la confirmación

[Líneas 101–107 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/pages/location_page.dart#L101-L107)

```dart
if (!mounted || confirmed != true) return;
setState(() => busy = true);
try {
  await widget.onSave(value);
} finally {
  if (mounted) setState(() => busy = false);
}
```

save() abre un diálogo que explica que las coordenadas y la hora de captura se enviarán a Supabase. Cancelar o cerrar el diálogo deja la lectura en pantalla sin enviarla. onAvailability comunica el resultado del GPS al Dashboard.

**Cómo explicarlo al docente.** Primero el permiso de Android autoriza la lectura. Luego la confirmación dentro de la app autoriza el envío de esa lectura.

### 4 Modelo y acceso a Supabase

[`lib/reading.dart`](../lib/reading.dart)

Sensor define los tipos de medición. Reading almacena el tipo, la hora y los valores. toJson() convierte el objeto en las columnas de PostgreSQL y fromJson() vuelve a construirlo con los datos que devuelve la consulta.

#### Campos que se envían a PostgreSQL

[Líneas 50–59 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/reading.dart#L50-L59)

```dart
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
```

#### Inserción y consulta ordenada

[Líneas 76–94 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/reading.dart#L76-L94)

```dart
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
        .order('recorded_at', ascending: true)
        .order('id', ascending: true)
        .range(offset, offset + pageSize - 1);
    readings.addAll(rows.map(Reading.fromJson));
    if (rows.length < pageSize) return readings;
  }
```

signIn() reutiliza una sesión existente o inicia una sesión anónima si hace falta. PostgreSQL usa el identificador de la sesión como user_id y aplica RLS. Una medición de movimiento usa x, y y z. El GPS usa latitude, longitude y accuracy. Los campos que no aplican quedan en NULL.

load() trae bloques de 500 filas. Ordena por recorded_at de la más antigua a la más reciente y usa id para desempatar. Con ese orden, Estadísticas puede elegir la última lectura GPS y el Historial puede invertir la lista.

**Cómo explicarlo al docente.** Reading describe el dato. ReadingStore sabe cómo guardarlo y cómo recuperarlo.

### 5 Historial y estadísticas

[`lib/pages/records_page.dart`](../lib/pages/records_page.dart)

RecordsPage carga las mediciones al entrar. FutureBuilder muestra la espera, los errores de consulta y el resultado. Actualizar vuelve a pedir los datos. Historial recorre la lista al revés para empezar por lo más reciente, y details() abre el tipo de sensor, sus valores y su hora local.

#### Selección de datos para estadísticas

[Líneas 37–45 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/pages/records_page.dart#L37-L45)

```dart
Widget statistics(List<Reading> readings) {
  final acceleration = readings
      .where((r) => r.sensor == Sensor.accelerometer)
      .toList();
  final gps = readings.where((r) => r.sensor == Sensor.gps).lastOrNull;
  final chartValues = acceleration
      .skip(math.max(0, acceleration.length - 50))
      .toList();
  final origin = chartValues.firstOrNull?.time;
```

#### Puntos del gráfico

[Líneas 66–74 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/pages/records_page.dart#L66-L74)

```dart
spots: [
  for (final r in chartValues)
    FlSpot(
      r.time.difference(origin!).inMilliseconds / 1000,
      axis.value(r),
    ),
],
dotData: FlDotData(show: chartValues.length == 1),
barWidth: 2,
```

Estadísticas muestra el total y el conteo por sensor. Calcula el mínimo y el máximo de cada eje del acelerómetro. El gráfico usa como máximo las 50 lecturas más recientes de ese sensor. El eje horizontal mide segundos desde la primera lectura graficada y el vertical muestra m/s².

La última ubicación es la última fila del GPS en la lista ascendente que entrega ReadingStore. Si existe, se muestra con sus valores y la hora local mediante toLocal(). Si solo hay una lectura del acelerómetro, cada eje se representa con un punto.

**Cómo explicarlo al docente.** Historial y Estadísticas consultan la misma tabla. Historial muestra cada registro y Estadísticas resume el conjunto.

### 6 Apariencia de los sensores

[`lib/sensor_theme.dart`](../lib/sensor_theme.dart)

SensorAppearance agrega un color y un ícono a cada valor de Sensor. De esta forma, una pantalla puede usar sensor.accent y sensor.icon para mantener el mismo estilo que las demás.

#### Colores e íconos por sensor

[Líneas 5–17 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/sensor_theme.dart#L5-L17)

```dart
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
```

#### Degradado de Inicio

[Líneas 38–42 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/lib/sensor_theme.dart#L38-L42)

```dart
const trackGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff29225b), Color(0xff5140a3)],
);
```

SensorIcon es un StatelessWidget que dibuja un ícono en un fondo suave. Inicio, Sensores e Historial lo reutilizan. La pantalla de Ubicación usa el color asignado al GPS en su botón principal.

**Cómo explicarlo al docente.** Si quiero cambiar el color del GPS en la interfaz, lo cambio en sensor_theme.dart y las pantallas que usan ese color toman el nuevo valor.

### 7 Prueba automatizada de la interfaz

[`test/widget_test.dart`](../test/widget_test.dart)

Este archivo Dart está en test/ y comprueba el arranque de la interfaz. La prueba monta SensorTrackApp, avanza un segundo para que termine el splash y busca los textos esperados en Inicio.

#### Prueba de apertura y estado inicial

[Líneas 4–13 del código](https://github.com/LadyRobalino/Taller_Sensor_Track_Flutter/blob/6e70b47b9c4e2a598312cb32693f5c5d0e19d749/test/widget_test.dart#L4-L13)

```dart
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
```

pumpWidget() construye la aplicación en el entorno de pruebas. pump() avanza el reloj de la prueba. expect() y findsOneWidget comprueban que aparezca una sola vez cada texto esperado. Como la prueba construye SensorTrackApp sin pasar ReadingStore, aparece el estado Supabase sin configurar.

**Cómo explicarlo al docente.** La prueba automática verifica el inicio de la pantalla. Las capturas del Xiaomi y de Supabase documentan las pruebas físicas y el guardado real.

## Recorrido para la defensa

1. Abrir main.dart y señalar dónde se inicializa Supabase y se elige la pestaña.

1. Mover el celular y explicar qué hace el flujo en MotionPage. Guardar una lectura y seguir la llamada hasta ReadingStore.save().

1. Abrir Historial, seleccionar la lectura y comprobar la fila correspondiente en Supabase. Mostrar el gráfico y la última ubicación en Estadísticas.
