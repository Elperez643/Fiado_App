# iOS Compatibility

## Estado

Fiado App queda preparada para pruebas iOS desde macOS/Xcode sin cambiar logica de negocio. Desde Windows no se puede compilar iOS; la validacion final debe hacerse en macOS.

## Requisitos

- macOS actualizado.
- Xcode instalado desde App Store.
- Command Line Tools activos:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcodebuild -version
```

- CocoaPods:

```bash
sudo gem install cocoapods
pod --version
```

- Flutter con soporte iOS:

```bash
flutter doctor -v
```

## Comandos de preparacion

```bash
flutter clean
flutter pub get
cd ios
pod install
cd ..
flutter build ios --debug --no-codesign
```

## Simulador

```bash
open -a Simulator
flutter devices
flutter run -d "iPhone 15"
```

Para backend local desde simulador iOS usar `http://localhost:5193/api` o la configuracion `localWeb/localDesktop` si el backend corre en la misma Mac. Si el backend corre en otra maquina, usar la IP local.

## iPhone real

1. Abrir `ios/Runner.xcworkspace` en Xcode.
2. Cambiar `Bundle Identifier` de `com.example.fiadoApp` a un identificador propio, por ejemplo `com.tuempresa.fiadoapp`.
3. Seleccionar Team de firma.
4. Conectar iPhone por cable o red.
5. Ejecutar desde Xcode o:

```bash
flutter run -d <device-id>
```

Para backend local desde iPhone fisico usar la IP LAN del equipo que ejecuta el backend, por ejemplo `http://192.168.1.50:5193/api`.

## Permisos iOS configurados

- `NSPhotoLibraryUsageDescription`: seleccionar imagenes de productos.
- `NSCameraUsageDescription`: capturar imagenes de productos si se habilita camara.
- `NSPhotoLibraryAddUsageDescription`: guardar/compartir archivos generados.
- `LSApplicationQueriesSchemes`: `whatsapp`, `https`, `http`.

## Paquetes revisados

| Paquete | iOS | Observacion |
| --- | --- | --- |
| `sqflite` | Compatible | Usa SQLite nativo via `sqflite_darwin`. |
| `image_picker` | Compatible | Requiere permisos de fotos/camara. |
| `pdf` | Compatible | Genera bytes Dart puro. |
| `printing` | Compatible | Validar AirPrint/share sheet en dispositivo. |
| `share_plus` | Compatible | Usa share sheet nativo. |
| `path_provider` | Compatible | Usa directorios sandbox iOS. |
| `url_launcher` | No directo | No esta como dependencia directa; WhatsApp se comparte por `share_plus`. |
| `http` | Compatible | HTTP local puede requerir excepciones ATS si se prueba contra URLs no HTTPS. |

## Errores comunes

- `CocoaPods not installed`: instalar CocoaPods y repetir `pod install`.
- `No profiles for ... were found`: configurar Team y bundle id en Xcode.
- Backend local no conecta desde iPhone: usar IP LAN, no `localhost`.
- HTTP bloqueado en iOS: para produccion usar HTTPS; para pruebas locales revisar ATS si Xcode reporta bloqueo.
- Imagenes no abren selector: revisar permisos en `Info.plist` y reinstalar app.
- `pod install` falla tras cambio de paquetes: ejecutar `flutter clean`, borrar `ios/Pods` y `ios/Podfile.lock`, luego `pod install`.

## Pendientes para macOS

- Ejecutar `flutter build ios --debug --no-codesign`.
- Probar en simulador iPhone y iPad.
- Probar en iPhone real con firma.
- Confirmar share sheet, impresion PDF, seleccion de imagenes y conexion al backend.
