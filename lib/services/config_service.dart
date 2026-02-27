import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _keyApiAddress = 'api_address';
  static const String _keyApiKey = 'api_key';

  static const String defaultApiAddress = 'https://open.bigmodel.cn/api/paas/v4';

  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  Future<String> getApiAddress() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyApiAddress) ?? defaultApiAddress;
  }

  Future<void> setApiAddress(String address) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyApiAddress, address);
  }

  Future<String> getApiKey() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyApiKey) ?? '';
  }

  Future<void> setApiKey(String apiKey) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyApiKey, apiKey);
  }

  Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey.isNotEmpty;
  }

  Future<void> clearConfig() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyApiAddress);
    await prefs.remove(_keyApiKey);
  }
}
