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

  /// 流式 chat，通过 onToken 回调逐步返回生成的文字
  Stream<String> chatStream(String message, {String? systemPrompt}) async* {
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
    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    request.body = jsonEncode({
      'model': 'glm-4-flashx',
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 2048,
      'stream': true,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        final errorData = jsonDecode(body);
        final errorMessage =
            errorData['error']?['message'] ?? '请求失败: ${streamedResponse.statusCode}';
        if (isUsingDefault) {
          throw ApiKeyInvalidException('默认API密钥无效，请在设置中配置您自己的API密钥');
        }
        throw Exception(errorMessage);
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        // 保留最后一个可能不完整的行
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || !trimmed.startsWith('data:')) continue;
          final data = trimmed.substring(5).trim();
          if (data == '[DONE]') return;

          try {
            final json = jsonDecode(data);
            final delta = json['choices']?[0]?['delta']?['content'] as String?;
            if (delta != null && delta.isNotEmpty) {
              yield delta;
            }
          } catch (_) {
            // 忽略解析失败的行
          }
        }
      }
    } finally {
      client.close();
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
        '''你是一个智能助手，专门分析用户分享的图片内容。

【重要】分类判断必须按以下顺序逐步检查，命中即停：

第一步：图片中是否涉及服饰？
服饰物品包括：上衣（T恤、衬衫、卫衣、毛衣、夹克、外套、大衣、羽绒服、马甲、polo衫、背心、风衣、西装）、下装（裤子、牛仔裤、短裤、运动裤、裙子、连衣裙、半身裙）、鞋子（运动鞋、靴子、凉鞋、拖鞋、皮鞋、帆布鞋、高跟鞋、板鞋）、配饰（帽子、围巾、手套、腰带、领带）、袜子、内衣等。
以下任何一种情况都必须归类为"服饰"：
  a) 服饰实物照片（穿搭照、平铺展示、挂在衣架上、试衣间自拍等）
  b) 服饰商品图或电商商品详情页截图
  c) 服饰订单截图、购买记录截图（如淘宝/京东/拼多多/得物/抖音等平台的服饰订单页面）
  d) 任何截图中只要涉及的商品是服饰类（如订单中的商品名称包含衣服、裤子、鞋等关键词，或商品缩略图是服饰）
简单来说：只要图片内容和服饰相关，不管是实物还是截图还是订单，category都必须填"服饰"，绝对不能填"随手记"。

第二步：如果不是服饰，检查是否是取餐码？
必须包含明确的取餐码/取餐号/排队号等数字编码，如"A001"、"12号"。仅有餐厅菜单、食物图片不算。

第三步：如果不是取餐码，检查是否是取件码？
必须包含明确的快递取件码/取件号，如"12-3-4567"。

第四步：如果不是取件码，检查是否是账单？
包含消费金额、支付信息的图片，如支付截图、小票、发票等。

第五步：以上都不是，归类为"随手记"。
随手记是兜底分类，只有确认不是服饰、取餐码、取件码、账单后才能归为随手记。

2. 根据分类提取关键信息作为标题（标题要精简，不要重复分类名称）：
   - 取餐码：只提取店铺名称和取餐码，格式如"肯德基 A001"或"A001"（无店铺名时）
   - 取件码：只提取取件码，格式如"12-3-4567"
   - 账单：提取金额，并根据收支类型添加符号：
     * 支出：格式如"-¥35.00"
     * 收入：格式如"+¥100.00"
     * 无法判断时默认为支出
   - 服饰：用服饰名称作为标题，如"白色圆领T恤"、"黑色牛仔裤"、"Nike Air Max 运动鞋"
   - 随手记：用一句话概括图片的主要内容，如"周末公园散步"、"公司年会合影"、"新买的咖啡机"、"餐厅菜单推荐"等

3. 对于所有非账单非服饰类型（取餐码、取件码、随手记），必须将识别出的信息组织成结构化的信息区域（infoSections）：
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
{"category":"分类名称","title":"提取的标题","summary":"一段话总结图片内容","infoSections":[{"title":"小标题","items":[{"label":"标签","value":"值"}]}],"amount":"金额","isExpense":true/false,"billCategory":"账单分类","paymentMethod":"支付方式","merchantName":"商户名称","billTime":"账单时间","clothingName":"服饰名称","clothingType":"分类","clothingColors":["#hex"],"clothingSeasons":["季节"],"clothingBrand":"品牌","clothingPrice":"价格","clothingSize":"尺码","clothingPurchaseDate":"购买日期"}

注意：
1. 对于所有类型（取餐码、取件码、账单、服饰、随手记），必须填写summary字段，用简洁明了的一段话总结图片的相关内容
2. 对于所有非账单非服饰类型（取餐码、取件码、随手记），必须填写infoSections，将图片中识别出的所有重要信息组织成结构化格式
3. 对于账单类型，填写amount、isExpense、billCategory等字段，infoSections可以留空
4. 只填写图片中实际存在的信息，不存在的字段请省略或留空
5. billCategory必须从上面列出的分类中选择英文名称（如dining、transport、salary等），不要自创分类名称，不要使用中文分类名
6. billTime格式为"YYYY-MM-DD HH:mm"，如"2024-01-15 14:30"
7. 对于服饰类型，请提取以下信息（只填写图片中能识别到的，不确定的不要填）：
   - clothingName(服饰名称，如"条纹圆领T恤")
   - clothingType(具体分类，如T恤、衬衫、牛仔裤、连衣裙、运动鞋、卫衣、西装外套等)
   - clothingColors(色系列表，返回hex色值数组，最多5个主要颜色，如["#FFFFFF","#000000"])
   - clothingSeasons(适用季节列表，从"春季"、"夏季"、"秋季"、"冬季"中选择，如["春季","秋季"])
   - clothingBrand(品牌名称)
   - clothingPrice(价格，如"¥299")
   - clothingSize(尺码，如"L"、"175/92A"、"42码")
   - clothingPurchaseDate(购买日期，格式"YYYY-MM-DD")
   - summary(一句话描述这件服饰)
8. 随手记类型要详细分析图片内容，提取所有有价值的信息，可以适当联想丰富内容，标题应该是对图片的概括性描述
9. 【再次强调】如果图片中出现了任何服饰物品、服饰商品图、服饰订单截图、服饰购买记录，category必须是"服饰"，绝对不能是"随手记"。订单截图中的商品如果是衣服鞋子等服饰，也必须归类为"服饰"''';

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
                  {'type': 'text', 'text': '请分析这张图片。分类时请注意：如果图片中出现了服饰相关内容（包括服饰实物、服饰商品图、服饰订单截图、服饰购买记录等），必须归类为"服饰"，不要归类为"随手记"。'},
                ],
              },
            ],
            'temperature': 0.3,
            'max_tokens': 800,
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
        case '服饰':
          category = MemoryCategory.clothing;
          break;
        default:
          category = MemoryCategory.note;
      }

      // 二次校验：如果 AI 分类为随手记，但内容中包含服饰关键词，强制改为服饰
      if (category == MemoryCategory.note) {
        final fullText = '$title ${json['summary'] ?? ''} ${jsonStr}'.toLowerCase();
        const clothingKeywords = [
          // 上衣
          't恤', '衬衫', '卫衣', '毛衣', '夹克', '外套', '大衣', '羽绒服',
          '马甲', 'polo', '背心', '风衣', '西装', '棉服', '冲锋衣', '衬衣',
          '短袖', '长袖', '上衣', '打底衫', '针织衫', '开衫',
          // 下装
          '裤子', '牛仔裤', '短裤', '运动裤', '裙子', '连衣裙', '半身裙',
          '休闲裤', '西裤', '阔腿裤', '长裤', '裙裤', '百褶裙',
          // 鞋
          '运动鞋', '靴子', '凉鞋', '拖鞋', '皮鞋', '帆布鞋', '高跟鞋',
          '板鞋', '跑鞋', '球鞋', '单鞋', '乐福鞋', '马丁靴', '雪地靴',
          // 配饰
          '帽子', '围巾', '手套', '腰带', '领带', '袜子',
          // 通用
          '服装', '服饰', '穿搭', '尺码', '码数', 'clothingname', 'clothingtype',
        ];
        for (final keyword in clothingKeywords) {
          if (fullText.contains(keyword)) {
            category = MemoryCategory.clothing;
            debugPrint('二次校验命中服饰关键词: $keyword，强制改为服饰分类');
            break;
          }
        }
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
        clothingName: getNonEmptyString(json, 'clothingName'),
        clothingType: getNonEmptyString(json, 'clothingType'),
        clothingColors: (json['clothingColors'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        clothingSeasons: (json['clothingSeasons'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        clothingBrand: getNonEmptyString(json, 'clothingBrand'),
        clothingPrice: getNonEmptyString(json, 'clothingPrice'),
        clothingSize: getNonEmptyString(json, 'clothingSize'),
        clothingPurchaseDate: getNonEmptyString(json, 'clothingPurchaseDate'),
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
