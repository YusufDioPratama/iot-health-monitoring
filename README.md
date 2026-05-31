# IoT Health Monitoring / IoT Health Gateway

Flutter Android gateway app for an IoT health monitoring system. The current working flow is:

```text
ESP32 + MAX30102 -> BLE -> Flutter Mobile Gateway -> Django REST API /api/predict/ -> prediction result
```

The Flutter app lives in:

```text
mobile_gateway/
```

## Current Backend Mode

The app currently uses the legacy Django backend API mode.

- Backend URL: `<your-backend-url>`
- Prediction endpoint: `POST /api/predict/`
- Prediction header: `X-API-KEY`
- Backend URL can be edited from the app settings screen.

Development/testing values are documented for local testing only. Do not treat them as production credentials.

- Testing username: `<your-username>`
- Testing password: `<your-password>`
- Legacy API key: `<your-api-key>`
- Active backend device: `ESP32 Device`

The legacy API key is only for the old `/api/predict/` flow. The app should not use Supabase or database credentials directly.

For shared or non-demo builds, override development defaults with Flutter `--dart-define` values instead of editing app logic.

## ESP32 BLE Configuration

- BLE target name: `ESPP`
- Service UUID: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- Notify characteristic UUID: `beb5483e-36e1-4688-b7f5-ea07361b26a8`

The ESP32 sends UTF-8 JSON payloads like:

```json
{
  "bpm": 82,
  "spo2": 97,
  "rmssd": 45.20,
  "sdrr": 53.80,
  "pnn50": 20
}
```

Flutter maps `bpm` to `heart_rate`, adds local metadata for queue/history/dashboard, and sends only these fields to the backend:

```json
{
  "rmssd": 45.2,
  "sdrr": 53.8,
  "pnn50": 20,
  "heart_rate": 82,
  "spo2": 97
}
```

`device_id`, `seq`, and `timestamp` are kept locally and are not sent to `/api/predict/`.

## Flutter App

Run the app from the Flutter folder:

```powershell
cd mobile_gateway
flutter pub get
flutter analyze
flutter run
```

Build a release APK:

```powershell
cd mobile_gateway
flutter build apk
```

APK output:

```text
mobile_gateway/build/app/outputs/flutter-apk/app-release.apk
```

Real BLE testing must use a physical Android phone. Android emulators usually cannot scan or connect to the ESP32 BLE device.

## Security Notes

- Do not commit `backend/.env` or any `.env` file.
- Do not commit database credentials or Supabase credentials.
- Do not commit generated build files, APKs, AABs, `.sha1` files, IDE folders, or local caches.
- The Flutter gateway communicates with the Django REST API only.
- Never commit real API keys, passwords, database credentials, or `.env` files.
- The API key and test credentials above are placeholders for development/testing values and must not be used as production secrets.
