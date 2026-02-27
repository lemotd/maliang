import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'config_service.dart';
import '../models/memory_item.dart';

class AiService {
  final ConfigService _configService = ConfigService();

  Future<String?> chat(String message, {String? systemPrompt}) async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();

    if (apiKey.isEmpty) {
      throw Exception('API密钥未配置，请在设置中填写API密钥');
    }

    final messages = <Map<String, dynamic>>[];

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': message});

    final url = Uri.parse('$apiAddress/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'glm-4-flashx',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'] as String?;
      return content;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
        errorData['error']?['message'] ?? '请求失败: ${response.statusCode}',
      );
    }
  }

  Future<String?> analyzeImage(String imagePath) async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();

    if (apiKey.isEmpty) {
      throw Exception('API密钥未配置');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('图片文件不存在');
    }

    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final systemPrompt = '''你是一个智能助手，专门分析用户分享的图片内容。请根据图片内容进行分析：

1. 判断图片属于哪个分类：
   - 取餐码：包含餐厅取餐码、取餐号的图片
   - 取件码：包含快递取件码、取件码的图片
   - 账单：包含消费金额、支付信息的图片
   - 随手记：其他无法分类的内容

2. 根据分类提取关键信息作为标题：
   - 取餐码：提取取餐码和店铺名称（如有），格式如"肯德基 取餐码：A001"
   - 取件码：提取取件码，格式如"取件码：12-3-4567"
   - 账单：提取金额，格式如"消费 ¥35.00"
   - 随手记：简要描述图片内容

请严格按照以下JSON格式返回，不要包含其他内容：
{"category":"分类名称","title":"提取的标题"}''';

    final url = Uri.parse('$apiAddress/chat/completions');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'glm-4v-flash',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
              {'type': 'text', 'text': '请分析这张图片'},
            ],
          },
        ],
        'temperature': 0.3,
        'max_tokens': 500,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'] as String?;
      return content;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
        errorData['error']?['message'] ?? '图片分析失败: ${response.statusCode}',
      );
    }
  }

  MemoryItem? parseAnalysisResult(
    String? result,
    String imagePath,
    String? thumbnailPath,
  ) {
    if (result == null) return null;

    try {
      final jsonStr = result
          .replaceAll(RegExp(r'```json\n?'), '')
          .replaceAll(RegExp(r'\n?```'), '')
          .trim();
      final json = jsonDecode(jsonStr);

      final categoryStr = json['category'] as String? ?? '随手记';
      final title = json['title'] as String? ?? '未命名记忆';

      MemoryCategory category;
      switch (categoryStr) {
        case '取餐码':
          category = MemoryCategory.pickupCode;
          break;
        case '取件码':
          category = MemoryCategory.packageCode;
          break;
        case '账单':
          category = MemoryCategory.bill;
          break;
        default:
          category = MemoryCategory.note;
      }

      return MemoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
        createdAt: DateTime.now(),
        rawContent: result,
      );
    } catch (e) {
      return MemoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '随手记',
        category: MemoryCategory.note,
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
        createdAt: DateTime.now(),
        rawContent: result,
      );
    }
  }

  Future<bool> hasApiKey() async {
    final apiKey = await _configService.getApiKey();
    return apiKey.isNotEmpty;
  }
}
