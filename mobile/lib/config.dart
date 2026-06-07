/// App-wide configuration constants.
///
/// API base URL options:
///   - Android emulator:  http://10.0.2.2:8000/api   (default — emulator maps 10.0.2.2 to host machine)
///   - iOS simulator:     http://localhost:8000/api
///   - Real device:       http://<YOUR_LAN_IP>:8000/api  (run `ipconfig` / `ifconfig` to find your IP)
///                        e.g. http://192.168.1.42:8000/api
///
/// Change [apiBaseUrl] before building/running on a real device.
const String apiBaseUrl = 'http://10.0.2.2:8000/api';

/// App display name shown in the UI.
const String appName = 'AI Salomatlik';

/// JWT token storage keys (used by FlutterSecureStorage).
const String kAccessTokenKey = 'access_token';
const String kRefreshTokenKey = 'refresh_token';
