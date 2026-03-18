import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _keyApiAddress = 'api_address';
  static const String _keyApiKey = 'api_key';
  static const String _keyModelType = 'model_type'; // 'zhipu' or 'custom'
  static const String _keyCustomTextModel = 'custom_text_model';
  static const String _keyCustomVisionModel = 'custom_vision_model';
  static const String _keyCustomApiAddress = 'custom_api_address';
  static const String _keyCustomApiKey = 'custom_api_key';

  static const String defaultApiAddress =
      'https://open.bigmodel.cn/api/paas/v4';
  static const String defaultApiKey =
      '909c2ec4bab5450fb7860ce289c9924d.JiLRWyFJr9VGcESI';
  static const String defaultTextModel = 'glm-4-flashx';
  static const String defaultVisionModel = 'glm-4v-flash';

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

  Future<bool> isUsingDefaultApiKey() async {
    final prefs = await _getPrefs();
    final key = prefs.getString(_keyApiKey) ?? '';
    return key.isEmpty;
  }

  Future<void> clearConfig() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyApiAddress);
    await prefs.remove(_keyApiKey);
    await prefs.remove(_keyModelType);
    await prefs.remove(_keyCustomTextModel);
    await prefs.remove(_keyCustomVisionModel);
    await prefs.remove(_keyCustomApiAddress);
    await prefs.remove(_keyCustomApiKey);
  }

  // 模型类型：'zhipu' 或 'custom'
  Future<String> getModelType() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyModelType) ?? 'zhipu';
  }

  Future<void> setModelType(String type) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyModelType, type);
  }

  // 自定义模型配置
  Future<String> getCustomTextModel() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyCustomTextModel) ?? '';
  }

  Future<void> setCustomTextModel(String model) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyCustomTextModel, model);
  }

  Future<String> getCustomVisionModel() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyCustomVisionModel) ?? '';
  }

  Future<void> setCustomVisionModel(String model) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyCustomVisionModel, model);
  }

  Future<String> getCustomApiAddress() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyCustomApiAddress) ?? '';
  }

  Future<void> setCustomApiAddress(String address) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyCustomApiAddress, address);
  }

  Future<String> getCustomApiKey() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyCustomApiKey) ?? '';
  }

  Future<void> setCustomApiKey(String key) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyCustomApiKey, key);
  }

  // 获取当前生效的配置（根据模型类型）
  Future<String> getActiveApiAddress() async {
    final type = await getModelType();
    if (type == 'custom') {
      final addr = await getCustomApiAddress();
      return addr.isNotEmpty ? addr : defaultApiAddress;
    }
    return await getApiAddress();
  }

  Future<String> getActiveApiKey() async {
    final type = await getModelType();
    if (type == 'custom') {
      return await getCustomApiKey();
    }
    return await getApiKey();
  }

  Future<String> getActiveTextModel() async {
    final type = await getModelType();
    if (type == 'custom') {
      final model = await getCustomTextModel();
      return model.isNotEmpty ? model : defaultTextModel;
    }
    return defaultTextModel;
  }

  Future<String> getActiveVisionModel() async {
    final type = await getModelType();
    if (type == 'custom') {
      final model = await getCustomVisionModel();
      return model.isNotEmpty ? model : defaultVisionModel;
    }
    return defaultVisionModel;
  }

  Future<bool> isUsingDefaultActiveKey() async {
    final type = await getModelType();
    if (type == 'custom') {
      final key = await getCustomApiKey();
      return key.isEmpty;
    }
    return await isUsingDefaultApiKey();
  }
}
