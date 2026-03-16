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
            errorData['error']?['message'] ??
            '请求失败: ${streamedResponse.statusCode}';
        if (isUsingDefault) {
          throw ApiKeyInvalidException('默认API密钥无效，请在设置中配置您自己的API密钥');
        }
        throw Exception(errorMessage);
      }

      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(
        utf8.decoder,
      )) {
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

第一步：是否是取餐码？
包含明确的取餐码/取餐号/排队号等数字编码，如"A001"、"12号"。仅有餐厅菜单、食物图片不算。

第二步：是否是取件码？
包含明确的快递取件码/取件号，如"12-3-4567"。

第三步：是否是账单？
以下任何一种情况都归为"账单"：
  - 支付成功/完成页面截图（微信支付、支付宝、银行卡等）
  - 转账记录、红包记录
  - 消费小票、发票、收据
  - 外卖订单（美团、饿了么等显示金额的订单页）
  - 购物订单截图（淘宝、京东、拼多多等显示支付金额的页面）
  - 话费、水电费、充值等缴费截图
  - 任何包含"¥"、"元"、"支付"、"付款"、"收款"、"转账"等金额/交易关键词的截图
简单来说：只要图片中出现了明确的金额和交易/支付信息，就归为"账单"。

第四步：是否涉及服饰？
服饰包括：上衣、下装、鞋子、配饰等。以下情况归为"服饰"：
  a) 服饰实物照片（穿搭照、平铺展示、挂在衣架上等）
  b) 服饰商品图或电商商品详情页截图
  c) 服饰订单截图中主要展示商品信息的
注意：社交媒体截图（微博、朋友圈等）即使图中有人穿着衣服，也不应归为"服饰"，应归为"随手记"。只有图片主题明确是展示服饰本身时才归为"服饰"。

第五步：以上都不是，归类为"随手记"。

2. 根据分类提取关键信息作为标题（标题要精简）：
   - 取餐码：店铺名称+取餐码，如"肯德基 A001"
   - 取件码：取件码，如"12-3-4567"
   - 账单：金额带符号，支出如"-¥35.00"，收入如"+¥100.00"
   - 服饰：服饰名称，如"白色圆领T恤"
   - 随手记：一句话概括图片内容

3. 对于非账单非服饰类型（取餐码、取件码、随手记），必须填写infoSections：
   - 取餐码示例：{"title":"🍔 取餐信息","items":[{"label":"店铺","value":"肯德基"},{"label":"取餐码","value":"A001"}]}
   - 取件码示例：{"title":"📦 取件信息","items":[{"label":"取件码","value":"12-3-4567"},{"label":"快递公司","value":"顺丰快递"}]}
   - 随手记：将识别出的信息组织成结构化格式

4. 对于账单类型，提取：amount、isExpense、billCategory、billTime、paymentMethod、merchantName、summary
   billCategory必须且只能从以下列表中选择一个英文名称，禁止使用列表以外的任何值：
   支出类型：${BillExpenseCategory.aiPromptList}
   收入类型：${BillIncomeCategory.aiPromptList}
   如果无法匹配，支出用"other_expense"，收入用"other_income"。

5. 对于服饰类型，提取（只填能识别到的）：clothingName、clothingType、clothingColors(hex数组)、clothingSeasons、clothingBrand、clothingPrice、clothingSize、clothingPurchaseDate
   clothingSeasons必须且只能从以下四个值中选择（可多选）：["春季", "夏季", "秋季", "冬季"]，禁止使用其他任何季节名称。

6. 日程识别（适用于所有分类）：如果图片中包含日程、活动、会议、截止日期、预约、航班、火车票、演出、考试等时间相关信息，额外提取：
   - eventName：日程名称（简洁描述）
   - eventStartTime：开始时间，格式"YYYY-MM-DD HH:mm"。如果图片中没有显示年份，使用当前年份${DateTime.now().year}。
   - eventEndTime：结束时间，格式"YYYY-MM-DD HH:mm"（如果无法确定结束时间，默认为开始时间后1小时）。如果图片中没有显示年份，使用当前年份${DateTime.now().year}。
   注意：日程信息是附加提取的，不影响主分类判断。

请严格按以下JSON格式返回：
{"category":"分类名称","title":"标题","summary":"一段话总结","infoSections":[{"title":"小标题","items":[{"label":"标签","value":"值"}]}],"amount":"金额","isExpense":true/false,"billCategory":"分类","paymentMethod":"支付方式","merchantName":"商户","billTime":"YYYY-MM-DD HH:mm","clothingName":"名称","clothingType":"分类","clothingColors":["#hex"],"clothingSeasons":["季节"],"clothingBrand":"品牌","clothingPrice":"价格","clothingSize":"尺码","clothingPurchaseDate":"YYYY-MM-DD","eventName":"日程名称","eventStartTime":"YYYY-MM-DD HH:mm","eventEndTime":"YYYY-MM-DD HH:mm"}

注意：所有类型都必须填summary。只填图片中实际存在的字段，不存在的省略。billCategory必须从上方列表选择英文名，不要自创分类。clothingSeasons只能从["春季","夏季","秋季","冬季"]中选择。''';

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
                  {
                    'type': 'text',
                    'text':
                        '请分析这张图片并按要求分类。注意按顺序判断：先看是否是取餐码/取件码/账单，再看是否是服饰，最后才归为随手记。',
                  },
                ],
              },
            ],
            'temperature': 0.3,
            'max_tokens': 1024,
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

  String? _validateBillCategory(String? category, bool? isExpense) {
    if (category == null) return null;
    final expense = BillExpenseCategory.fromName(category);
    if (expense != null) return expense.name;
    final income = BillIncomeCategory.fromName(category);
    if (income != null) return income.name;
    // 无法匹配，回退到"其他"
    return (isExpense ?? true) ? 'other_expense' : 'other_income';
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

      // 尝试提取 JSON 对象（处理 AI 返回额外文本的情况）
      String cleanJson = jsonStr;
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch != null) {
        cleanJson = jsonMatch.group(0)!;
      }

      debugPrint(
        '解析JSON: ${cleanJson.substring(0, cleanJson.length.clamp(0, 200))}...',
      );
      final decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('JSON解析结果不是Map: ${decoded.runtimeType}');
        throw FormatException(
          'Expected JSON object, got ${decoded.runtimeType}',
        );
      }
      final json = decoded;

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

      // 辅助函数：获取非空字符串
      String? getNonEmptyString(Map<String, dynamic> json, String key) {
        final value = json[key];
        if (value == null) return null;
        if (value is String && value.trim().isNotEmpty) return value.trim();
        return null;
      }

      // 二次校验：如果 AI 分类为随手记，但内容中包含账单关键词或有 amount 字段，强制改为账单
      // 注意：账单校验优先于服饰校验
      if (category == MemoryCategory.note) {
        final hasAmount = getNonEmptyString(json, 'amount') != null;
        final hasBillCategory = getNonEmptyString(json, 'billCategory') != null;
        if (hasAmount || hasBillCategory) {
          category = MemoryCategory.bill;
          debugPrint('二次校验：检测到amount/billCategory字段，强制改为账单分类');
        } else {
          final fullText = '$title ${json['summary'] ?? ''}'.toLowerCase();
          const billKeywords = [
            '支付',
            '付款',
            '收款',
            '转账',
            '消费',
            '充值',
            '缴费',
            '退款',
            '红包',
            '账单',
            '小票',
            '发票',
            '收据',
            '¥',
            '元',
            '订单金额',
            '实付',
            '应付',
          ];
          for (final keyword in billKeywords) {
            if (fullText.contains(keyword)) {
              category = MemoryCategory.bill;
              debugPrint('二次校验命中账单关键词: $keyword，强制改为账单分类');
              break;
            }
          }
        }
      }

      // 二次校验：如果 AI 分类为随手记，但内容中包含服饰关键词，强制改为服饰
      // 只检查标题和摘要，不检查整个 JSON（避免字段名误触发）
      if (category == MemoryCategory.note) {
        final fullText = '$title ${json['summary'] ?? ''}'.toLowerCase();
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
          '服装', '服饰', '穿搭', '尺码', '码数',
        ];
        for (final keyword in clothingKeywords) {
          if (fullText.contains(keyword)) {
            category = MemoryCategory.clothing;
            debugPrint('二次校验命中服饰关键词: $keyword，强制改为服饰分类');
            break;
          }
        }
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
            // "MM-DD HH:mm" 格式（缺少年份），自动补充当前年份
            if (dateParts.length == 2 && timeParts.length >= 2) {
              return DateTime(
                DateTime.now().year,
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
              );
            }
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
        billCategory: _validateBillCategory(
          getNonEmptyString(json, 'billCategory'),
          getBoolValue(json, 'isExpense'),
        ),
        paymentMethod: getNonEmptyString(json, 'paymentMethod'),
        merchantName: getNonEmptyString(json, 'merchantName'),
        billTime: parseBillTime(getNonEmptyString(json, 'billTime')),
        summary: getNonEmptyString(json, 'summary'),
        infoSections: parseInfoSections(json['infoSections'] as List<dynamic>?),
        clothingName: getNonEmptyString(json, 'clothingName'),
        clothingType: getNonEmptyString(json, 'clothingType'),
        clothingColors:
            (json['clothingColors'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        clothingSeasons:
            (json['clothingSeasons'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .where((s) => const ['春季', '夏季', '秋季', '冬季'].contains(s))
                .toList() ??
            const [],
        clothingBrand: getNonEmptyString(json, 'clothingBrand'),
        clothingPrice: getNonEmptyString(json, 'clothingPrice'),
        clothingSize: getNonEmptyString(json, 'clothingSize'),
        clothingPurchaseDate: getNonEmptyString(json, 'clothingPurchaseDate'),
        eventName: getNonEmptyString(json, 'eventName'),
        eventStartTime: parseBillTime(
          getNonEmptyString(json, 'eventStartTime'),
        ),
        eventEndTime: parseBillTime(getNonEmptyString(json, 'eventEndTime')),
      );
    } catch (e, stackTrace) {
      debugPrint('parseAnalysisResult 解析失败: $e');
      debugPrint('原始内容: $result');
      debugPrint('堆栈: $stackTrace');
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
