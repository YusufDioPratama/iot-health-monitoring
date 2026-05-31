# IoT Health Gateway

Flutter Android gateway app for:

ESP32 + MAX30102 -> BLE -> Flutter Gateway -> Django REST API -> PostgreSQL.

## UI

The app uses a polished Material 3 interface for demo/thesis presentation:

- Clean healthcare palette with teal/blue primary tones.
- Status hero dashboard with backend, BLE, queue, and active device state.
- Modern metric cards for Heart Rate, SpO2, RMSSD, SDRR, pNN50, and prediction.
- Highlighted ESPP BLE target cards, local queue status chips, local history
  chart, and grouped settings.

The current remote backend is in legacy API mode. It does not expose `/gateway/`
routes, so the app uses JWT login, sets the active device user, then syncs
sensor metrics to `/api/predict/`.

## Backend URL

```text
<your-backend-url>
```

## Test Data

```text
Username: <your-username>
Password: <your-password>
Device.name: ESP32 Device
Legacy Device.api_key: <your-api-key>
```

`<your-api-key>` is only for the legacy `/api/predict/` flow using
`X-API-KEY`. The app stores it in `flutter_secure_storage` and does not print it
or show it openly in the UI.

## ESP32 BLE Firmware

```text
BLE name: ESPP
Service UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
Notify characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8
Write characteristic: not used
```

ESP32 notification payload:

```json
{
  "bpm": 82,
  "spo2": 97,
  "rmssd": 45.2,
  "sdrr": 53.8,
  "pnn50": 20
}
```

Flutter adds local metadata:

```json
{
  "device_id": "ESP32 Device",
  "seq": 1,
  "timestamp": 1710000000,
  "heart_rate": 82,
  "spo2": 97,
  "rmssd": 45.2,
  "sdrr": 53.8,
  "pnn50": 20,
  "source": "ble"
}
```

`bpm` is mapped to `heart_rate` before syncing. The raw ESP32 payload is kept in
the local queue payload JSON for debugging/history context.

## Current Backend Flow

Login:

```http
POST /auth/login/
```

```json
{
  "username": "<your-username>",
  "password": "<your-password>"
}
```

Set active user after login:

```http
POST /device/set-active-user/
Authorization: Bearer <access_token>
```

```json
{
  "device_name": "ESP32 Device"
}
```

Predict/sync:

```http
POST /api/predict/
X-API-KEY: <your-api-key>
Content-Type: application/json
```

```json
{
  "rmssd": 45.2,
  "sdrr": 53.8,
  "pnn50": 20,
  "heart_rate": 82,
  "spo2": 97
}
```

Do not send `bpm`, `device_id`, `seq`, or `timestamp` to `/api/predict/`.

## pNN50 Zero Handling

The backend ML path uses `log(pnn50)`, so `pnn50 <= 0` is not syncable. The app
stores that packet locally as `invalid_for_sync` and shows:

```text
pNN50 bernilai 0, belum bisa dikirim ke backend ML.
```

It does not silently modify biomedical values.

## Run Flutter

```bash
cd mobile_gateway
flutter pub get
flutter analyze
flutter run
```

## Mock Sensor Mode

Mock mode emits the same shape as the real ESP32:

```json
{
  "bpm": 82,
  "spo2": 97,
  "rmssd": 45.2,
  "sdrr": 53.8,
  "pnn50": 20
}
```

It runs through the same parser, local metadata mapping, security validation,
SQLite queue, `/api/predict/` sync, dashboard update, and local history refresh.

## History

The current backend does not expose a cloud history endpoint. The `Riwayat`
screen shows local synced queue history for now.

```text
Riwayat cloud membutuhkan endpoint backend tambahan.
```

## Security

Never commit real API keys, passwords, database credentials, or `.env` files.
Use placeholders in documentation and enter runtime credentials through Settings
or Flutter `--dart-define` values.
