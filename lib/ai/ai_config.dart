import '../utils/storage.dart';

/// OpenAI 兼容接口的配置。
///
/// 这里只做「保存配置」，不会在任何页面自动调用模型。
class AiConfig {
  static const String _kBaseUrl = 'ai_base_url';
  static const String _kApiKey = 'ai_api_key';
  static const String _kModel = 'ai_model';

  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o-mini';

  String baseUrl;
  String apiKey;
  String model;

  AiConfig({
    String? baseUrl,
    String? apiKey,
    String? model,
  })  : baseUrl = (baseUrl ?? defaultBaseUrl).trim(),
        apiKey = (apiKey ?? '').trim(),
        model = (model ?? defaultModel).trim();

  factory AiConfig.load() {
    final prefs = StorageManager.prefs;
    return AiConfig(
      baseUrl: prefs.getString(_kBaseUrl) ?? defaultBaseUrl,
      apiKey: prefs.getString(_kApiKey) ?? '',
      model: prefs.getString(_kModel) ?? defaultModel,
    );
  }

  Future<void> save() async {
    final prefs = StorageManager.prefs;
    await prefs.setString(_kBaseUrl, baseUrl.trim());
    await prefs.setString(_kApiKey, apiKey.trim());
    await prefs.setString(_kModel, model.trim());
  }

  bool get isConfigured =>
      apiKey.isNotEmpty && baseUrl.isNotEmpty && model.isNotEmpty;

  /// 兼容用户填写 `https://xxx/v1` 或 `https://xxx/v1/chat/completions`
  String get chatCompletionsUrl {
    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.endsWith('/chat/completions')) return b;
    return '$b/chat/completions';
  }
}
