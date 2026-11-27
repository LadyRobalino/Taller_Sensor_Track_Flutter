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
