# SensorTrack

Aplicación Flutter para observar y guardar mediciones de acelerómetro, giroscopio y GPS. La prueba física del taller está orientada a Android.

## Ejecutar en Android

Desde la carpeta que contiene `pubspec.yaml`, ejecuta `flutter pub get`. Conecta el Android con depuración USB y consulta su identificador con `flutter devices`.

Para comprobar la interfaz y los sensores puedes ejecutar `flutter run -d ID_ANDROID`. Para guardar y consultar mediciones, configura Supabase:

1. En un proyecto nuevo, ejecuta `supabase/sensor_readings.sql` en SQL Editor.
2. Activa los inicios de sesión anónimos en Authentication. Esta sesión permite que las políticas RLS aíslen las mediciones de cada usuario.
3. Copia la URL y la clave **Publishable**. Sustituye los tres marcadores del comando:

```powershell
flutter run -d ID_ANDROID --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICA
```

Usa la clave pública en el cliente. El historial pertenece a la sesión del dispositivo. Al borrar los datos de la app se puede perder el acceso a esa sesión.

## Demostración y evidencias

- Abre Inicio y captura el estado de conexión.
- Abre Sensores. Inclina y gira el celular. Graba los cambios en los ejes y guarda varias lecturas de ambos sensores.
- En Ubicación, concede permiso, captura una lectura y confirma el guardado solo si autorizas subir esas coordenadas.
- Abre Historial, selecciona una medición y comprueba el detalle.
- Abre Estadísticas. Verifica el conteo, los rangos, la última ubicación y el gráfico.
- En Supabase, abre Table Editor y captura las filas. Oculta las coordenadas si muestran una ubicación privada.
- Sube el código, este README, el SQL y el informe a tu repositorio GitHub.

El [informe técnico](docs/Informe_tecnico.md) describe la arquitectura y el flujo de datos.
