class AppConfig {
  static String serverIp = '192.168.0.16';
  static int serverPort = 8000;

  static String get apiBaseUrl => 'http://$serverIp:$serverPort';
  static String get tahminEndpoint => '$apiBaseUrl/tahmin';
}
