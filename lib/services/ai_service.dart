import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'config_service.dart';
import '../models/memory_item.dart';
import '../models/bill_category.dart';

class ApiKeyInvalidException implements Exception {
  final String message;
  ApiKeyInvalidException(this.message);

  @override
  String toString() => message;
}

class AiService {
  final ConfigService _configService = ConfigService();

  Future<String?> chat(String message, {String? systemPrompt}) async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();
    final isUsingDefault = await _configService.isUsingDefaultApiKey();

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
      final errorMessage =
          errorData['error']?['message'] ?? '请求失败: ${response.statusCode}';

      // 如果使用默认 API Key 且调用失败，提示用户更换
      if (isUsingDefault) {
        throw ApiKeyInvalidException('默认API密钥无效，请在设置中配置您自己的API密钥');
      }

      throw Exception(errorMessage);
    }
  }

  Future<String?> analyzeImage(String imagePath) async {
    final apiAddress = await _configService.getApiAddress();
    final apiKey = await _configService.getApiKey();
    final isUsingDefault = await _configService.isUsingDefaultApiKey();

    debugPrint('API地址: $apiAddress');
    debugPrint('API密钥长度: ${apiKey.length}');

    if (apiKey.isEmpty) {
      throw Exception('API密钥未配置');
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('图片文件不存在');
    }

    final bytes = await file.readAsBytes();

    // 如果图片大于 500KB，进行压缩
    var imageBytes = bytes;
    if (bytes.length > 500 * 1024) {
      final image = img.decodeImage(bytes);
      if (image != null) {
        final quality = (500 * 1024 / bytes.length * 100).round().clamp(20, 85);
        imageBytes = img.encodeJpg(image, quality: quality);
        debugPrint('图片压缩: ${bytes.length} -> ${imageBytes.length} bytes');
      }
    }

    final base64Image = base64Encode(imageBytes);
    debugPrint('最终图片大小: ${imageBytes.length} bytes');

    final systemPrompt =
        '''你是一个智能助手
专门分析用户分享的图片内容。请根据图片内容进行分析：

1. 判断图片属于哪个分类（请仔细判断，不要误分类）：
   - 取餐码：必须包含明确的取餐码/取餐号/排队号等数字编码，如"A001"、"12号"、"B-03"等。注意：仅有餐厅菜单、食物图片、店铺信息但没有取餐码的，不属于取餐码类型
   - 取件码：必须包含明确的快递取件码/取件号，如"12-3-4567"、"丰巢取件码"等。注意：仅有快递单号但没有取件码的，不属于取件码类型
   - 账单：包含消费金额、支付信息的图片，如支付截图、小票、发票等
   - 随手记：其他无法归类的图片，如截图、文档、名片、海报、通知、菜单、食物照片、风景、物品等

2. 根据分类提取关键信息作为标题（标题要精简，不要重复分类名称）：
   - 取餐码：只提取店铺名称和取餐码，格式如"肯德基 A001"或"A001"（无店铺名时）
   - 取件码：只提取取件码，格式如"12-3-4567"
   - 账单：提取金额，并根据收支类型添加符号：
     * 支出：格式如"-¥35.00"
     * 收入：格式如"+¥100.00"
     * 无法判断时默认为支出
   - 随手记：用一句话概括图片的主要内容，如"周末公园散步"、"公司年会合影"、"新买的咖啡机"、"餐厅菜单推荐"等

3. 对于所有非账单类型（取餐码、取件码、随手记），必须将识别出的信息组织成结构化的信息区域（infoSections）：
   - 每个信息区域包含：
     * title：小标题名称，根据内容类型命名，可添加合适的emoji表情，如"📋 基本信息"、"📍 地点信息"、"📅 时间信息"、"📝 内容详情"等
     * items：信息项列表，每项包含label（标签名）和value（值）
   
   - 取餐码示例：
     {"title":"🍔 取餐信息","items":[{"label":"店铺","value":"肯德基"},{"label":"取餐码","value":"A001"},{"label":"餐品","value":"香辣鸡腿堡套餐"}]}
   
   - 取件码示例：
     {"title":"📦 取件信息","items":[{"label":"取件码","value":"12-3-4567"},{"label":"快递公司","value":"顺丰快递"},{"label":"取件地址","value":"菜鸟驿站XX店"}]}
   
   - 随手记示例（会议通知）：
     {"title":"📅 会议信息","items":[{"label":"主题","value":"产品评审会"},{"label":"时间","value":"2024年1月15日 14:00"},{"label":"地点","value":"3楼会议室A"}]}
   
   - 随手记示例（活动海报）：
     {"title":"🎉 活动详情","items":[{"label":"活动名称","value":"新年促销"},{"label":"时间","value":"1月20日-1月30日"},{"label":"优惠","value":"全场8折"}]}
   
   - 如果图片中包含多种类型的信息，可以创建多个信息区域

4. 对于随手记类型，请尽可能详细地识别图片内容，可以适当联想：
   - 食物/餐饮：描述食物名称、口味特点、餐厅风格、用餐场景、推荐理由等
   - 风景/旅行：描述地点、季节、天气、景色特点、游玩建议等
   - 人物/活动：描述活动类型、参与人员、氛围、时间地点等
   - 物品/产品：描述物品名称、品牌、特点、用途、购买渠道等
   - 文档/截图：提取文档标题、关键内容、要点总结等
   - 可以适当联想相关内容，如推荐搭配、使用建议、注意事项等

5. 对于账单类型，请提取以下信息：
   - amount(金额，带符号如"-35.00")
   - isExpense(布尔值，true表示支出，false表示收入)
   - billCategory(账单分类，必须从以下分类中选择一个最匹配的英文名称，如dining、transport等)
   - billTime(账单时间，格式为"YYYY-MM-DD HH:mm")
   - paymentMethod(支付方式)
   - merchantName(商户名称)
   - summary(账单摘要，一句话描述交易)
   
   账单分类列表：
   支出：${BillExpenseCategory.aiPromptList}
   收入：${BillIncomeCategory.aiPromptList}

请严格按照以下JSON格式返回，不要包含其他内容：
{"category":"分类名称","title":"提取的标题","summary":"一段话总结图片内容","infoSections":[{"title":"小标题","items":[{"label":"标签","value":"值"}]}],"amount":"金额","isExpense":true/false,"billCategory":"账单分类","paymentMethod":"支付方式","merchantName":"商户名称","billTime":"账单时间"}

注意：
1. 对于所有类型（取餐码、取件码、账单、随手记），必须填写summary字段，用简洁明了的一段话总结图片的相关内容
2. 对于所有非账单类型（取餐码、取件码、随手记），必须填写infoSections，将图片中识别出的所有重要信息组织成结构化格式
3. 对于账单类型，填写amount、isExpense、billCategory等字段，infoSections可以留空
4. 只填写图片中实际存在的信息，不存在的字段请省略或留空
5. billCategory必须从上面列出的分类中选择英文名称（如dining、transport、salary等），不要自创分类名称，不要使用中文分类名
6. billTime格式为"YYYY-MM-DD HH:mm"，如"2024-01-15 14:30"
7. 随手记类型要详细分析图片内容，提取所有有价值的信息，可以适当联想丰富内容，标题应该是对图片的概括性描述''';

    final url = Uri.parse('$apiAddress/chat/completions');
    debugPrint('请求URL: $url');

    final response = await http
        .post(
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
        )
        .timeout(const Duration(seconds: 60));

    debugPrint('响应状态码: ${response.statusCode}');
    debugPrint('响应体长度: ${response.bodyBytes.length}');

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'] as String?;
      debugPrint('AI返回内容: $content');
      return content;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      debugPrint('错误响应: $errorData');
      final errorMessage =
          errorData['error']?['message'] ?? '图片分析失败: ${response.statusCode}';

      // 如果使用默认 API Key 且调用失败，提示用户更换
      if (isUsingDefault) {
        throw ApiKeyInvalidException('默认API密钥无效，请在设置中配置您自己的API密钥');
      }

      throw Exception(errorMessage);
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

      // 辅助函数：获取非空字符串
      String? getNonEmptyString(Map<String, dynamic> json, String key) {
        final value = json[key];
        if (value == null) return null;
        if (value is String && value.trim().isNotEmpty) return value.trim();
        return null;
      }

      // 辅助函数：获取布尔值
      bool? getBoolValue(Map<String, dynamic> json, String key) {
        final value = json[key];
        if (value == null) return null;
        if (value is bool) return value;
        if (value is String) {
          return value.toLowerCase() == 'true';
        }
        return null;
      }

      // 辅助函数：解析账单时间
      DateTime? parseBillTime(String? timeStr) {
        if (timeStr == null || timeStr.isEmpty) return null;
        try {
          // 尝试解析 "YYYY-MM-DD HH:mm" 格式
          final parts = timeStr.split(' ');
          if (parts.length == 2) {
            final dateParts = parts[0].split('-');
            final timeParts = parts[1].split(':');
            if (dateParts.length == 3 && timeParts.length >= 2) {
              return DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
            }
          }
          // 尝试直接解析 ISO 格式
          return DateTime.parse(timeStr);
        } catch (e) {
          debugPrint('解析账单时间失败: $timeStr, 错误: $e');
          return null;
        }
      }

      // 辅助函数：解析信息区域
      List<InfoSection> parseInfoSections(List<dynamic>? sectionsJson) {
        if (sectionsJson == null) return [];
        return sectionsJson.map((section) {
          final items =
              (section['items'] as List<dynamic>?)?.map((item) {
                return InfoItem(
                  label: item['label'] as String? ?? '',
                  value: item['value'] as String? ?? '',
                );
              }).toList() ??
              [];
          return InfoSection(
            title: section['title'] as String? ?? '',
            items: items,
          );
        }).toList();
      }

      return MemoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        category: category,
        imagePath: imagePath,
        thumbnailPath: thumbnailPath,
        createdAt: DateTime.now(),
        rawContent: result,
        shopName: getNonEmptyString(json, 'shopName'),
        pickupCode: getNonEmptyString(json, 'pickupCode'),
        dishName: getNonEmptyString(json, 'dishName'),
        expressCompany: getNonEmptyString(json, 'expressCompany'),
        pickupAddress: getNonEmptyString(json, 'pickupAddress'),
        productType: getNonEmptyString(json, 'productType'),
        trackingNumber: getNonEmptyString(json, 'trackingNumber'),
        amount: getNonEmptyString(json, 'amount'),
        isExpense: getBoolValue(json, 'isExpense'),
        billCategory: getNonEmptyString(json, 'billCategory'),
        paymentMethod: getNonEmptyString(json, 'paymentMethod'),
        merchantName: getNonEmptyString(json, 'merchantName'),
        billTime: parseBillTime(getNonEmptyString(json, 'billTime')),
        summary: getNonEmptyString(json, 'summary'),
        infoSections: parseInfoSections(json['infoSections'] as List<dynamic>?),
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
