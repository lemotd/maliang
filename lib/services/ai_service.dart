import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
    final apiAddress = await _configService.getActiveApiAddress();
    final apiKey = await _configService.getActiveApiKey();
    final isUsingDefault = await _configService.isUsingDefaultActiveKey();
    final textModel = await _configService.getActiveTextModel();

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
        'model': textModel,
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
    final apiAddress = await _configService.getActiveApiAddress();
    final apiKey = await _configService.getActiveApiKey();
    final isUsingDefault = await _configService.isUsingDefaultActiveKey();
    final textModel = await _configService.getActiveTextModel();

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
      'model': textModel,
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

  /// 在独立 isolate 中压缩图片并编码为 base64，避免阻塞 UI 线程
  static String _compressAndEncodeImage(Uint8List bytes) {
    Uint8List imageBytes = bytes;
    if (bytes.length > 500 * 1024) {
      final image = img.decodeImage(bytes);
      if (image != null) {
        final quality = (500 * 1024 / bytes.length * 100).round().clamp(20, 85);
        imageBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      }
    }
    return base64Encode(imageBytes);
  }

  Future<String?> analyzeImage(String imagePath) async {
    final apiAddress = await _configService.getActiveApiAddress();
    final apiKey = await _configService.getActiveApiKey();
    final isUsingDefault = await _configService.isUsingDefaultActiveKey();
    final visionModel = await _configService.getActiveVisionModel();

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

    // 在独立 isolate 中压缩 + base64 编码，避免阻塞 UI
    final base64Image = await compute(_compressAndEncodeImage, bytes);
    debugPrint('最终图片大小: ${base64Image.length} chars (base64)');

    final systemPrompt =
        '''你是一个智能助手，专门分析用户分享的图片内容。

【重要】一张图片可能同时包含多种类型的信息。你需要识别出所有类型，并为每种类型分别生成一条记录。

分类类型（按以下顺序逐一检查，每种类型独立判断，可同时命中多个）：

1. 取餐码：包含明确的取餐码/取茶码/取餐号/排队号等数字编码，如"A001"、"12号"。仅有餐厅菜单、食物图片不算。【注意】日期时间（如"2024-03-20"、"14:30"、"3月20日"）不是取餐码；截图中显示的聊天时间、通知时间、日历日期等都不是取餐码。取餐码通常出现在点餐/排队场景中，有明确的"取餐码"、"排队号"等标签。如果图片只是普通截图（聊天记录、通知、文章、社交媒体等）且包含日期时间，应归类为随手记而非取餐码。
2. 取件码：包含明确的快递取件码/取件号，如"12-3-4567"。
3. 账单：包含金额和交易/支付信息（支付截图、转账、小票、发票、外卖订单、购物订单、缴费等）。注意：取餐码/取件码中的数字编号不是金额，不要将其识别为账单。
4. 服饰：服饰实物照片、服饰商品图、电商服饰详情页。社交媒体截图中有人穿衣服不算。
5. 随手记：以上都不是时使用。

【特别注意】当图片同时包含取餐码和金额时：
- 取餐码（如"A001"、"12号"）必须归类为取餐码，不能归类为账单
- 只有明确的支付金额（带¥符号或"元"字的数字）才归类为账单
- 取餐码的title只填码值本身，账单的amount只填实际支付金额
- 不要把取餐码的数字当作金额

例如：一张外卖订单截图同时包含取餐码"A032"和支付金额"¥35.00"，应生成两条记录：一条取餐码（title为"A032"）、一条账单（amount为"35.00"）。绝对不要把取餐码"A032"当作账单。
如果图片中包含多个同类型的信息（如多个取件码、多笔账单），也要为每一个分别生成独立的记录。

每条记录的字段规则：
- 标题要精简：取餐码的title字段必须且只能填取餐码本身如"A001"（绝对不要填店铺名或其他任何非码值内容），取件码的title字段必须且只能填取件码数字本身如"12-3-4567"（绝对不要填商品名、快递公司名或其他任何非码值内容），账单用金额带符号如"-¥35.00"，服饰用名称，随手记用一句话概括
- 特别强调：当图片中有多个取件码时，每条取件码记录的title必须是对应的取件码数字（如"12-3-4567"），不是商品名称
- 所有类型都必须填summary
- 取餐码/取件码/随手记必须填infoSections
- 账单提取：amount、isExpense、billCategory、billTime、paymentMethod、merchantName
  billCategory必须从以下列表选择英文名：
  支出：${BillExpenseCategory.aiPromptList}
  收入：${BillIncomeCategory.aiPromptList}
  无法匹配时支出用"other_expense"，收入用"other_income"
- 服饰提取：clothingName、clothingType、clothingColors(hex数组)、clothingSeasons(只能从["春季","夏季","秋季","冬季"]选)、clothingBrand、clothingPrice、clothingSize、clothingPurchaseDate
- 日程识别（所有分类均可附加）：eventName、eventStartTime、eventEndTime，格式"YYYY-MM-DD HH:mm"，缺少年份用${DateTime.now().year}

请严格按以下JSON格式返回（注意最外层是数组）：
[{"category":"分类名称","title":"标题","summary":"总结","infoSections":[{"title":"小标题","items":[{"label":"标签","value":"值"}]}],"amount":"金额","isExpense":true/false,"billCategory":"分类","paymentMethod":"支付方式","merchantName":"商户","billTime":"YYYY-MM-DD HH:mm","clothingName":"名称","clothingType":"分类","clothingColors":["#hex"],"clothingSeasons":["季节"],"clothingBrand":"品牌","clothingPrice":"价格","clothingSize":"尺码","clothingPurchaseDate":"YYYY-MM-DD","eventName":"日程名称","eventStartTime":"YYYY-MM-DD HH:mm","eventEndTime":"YYYY-MM-DD HH:mm"}]

如果只有一种类型，数组中也只有一个元素。只填图片中实际存在的字段，不存在的省略。''';

    final url = Uri.parse('$apiAddress/chat/completions');
    debugPrint('请求URL: $url');

    final requestBody = jsonEncode({
      'model': visionModel,
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
              'text': '请分析这张图片，识别所有类型的信息，为每种类型分别生成一条记录，以JSON数组返回。',
            },
          ],
        },
      ],
      'temperature': 0.3,
      'max_tokens': 1024,
    });

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    // 重试机制：连接中断（如切后台）时自动重试
    const maxRetries = 3;
    http.Response? response;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        response = await http
            .post(url, headers: headers, body: requestBody)
            .timeout(const Duration(seconds: 60));
        break; // 成功则跳出
      } catch (e) {
        debugPrint('请求失败 (第${attempt + 1}次): $e');
        if (attempt >= maxRetries) rethrow;
        // 递增等待：1s, 2s, 3s，等待网络恢复
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    debugPrint('响应状态码: ${response!.statusCode}');
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

  /// 从 JSON 中提取码值：先查顶层字段，再查 infoSections
  static String? _extractCodeFromJson(
    Map<String, dynamic> json,
    String fieldKey,
    List<String> labelKeywords,
  ) {
    // 1. 先查顶层字段
    final direct = json[fieldKey];
    if (direct is String && direct.trim().isNotEmpty) return direct.trim();

    // 2. 从 infoSections 中按 label 关键词查找
    final sections = json['infoSections'] as List<dynamic>?;
    if (sections != null) {
      for (final section in sections) {
        final items = section['items'] as List<dynamic>?;
        if (items == null) continue;
        for (final item in items) {
          final label = (item['label'] as String? ?? '');
          for (final kw in labelKeywords) {
            if (label.contains(kw)) {
              final val = item['value'] as String?;
              if (val != null && val.trim().isNotEmpty) return val.trim();
            }
          }
        }
      }
    }
    return null;
  }

  /// 解析 AI 返回的多条记录（JSON 数组或单对象格式）
  List<MemoryItem> parseMultipleResults(
    String? result,
    String imagePath,
    String? thumbnailPath,
  ) {
    if (result == null) return [];

    try {
      final jsonStr = result
          .replaceAll(RegExp(r'```json\n?'), '')
          .replaceAll(RegExp(r'\n?```'), '')
          .trim();

      debugPrint(
        'parseMultipleResults 输入: ${jsonStr.substring(0, jsonStr.length.clamp(0, 300))}...',
      );

      // 先尝试直接解析整个字符串
      dynamic decoded;
      try {
        decoded = jsonDecode(jsonStr);
      } catch (_) {
        // 尝试提取 JSON 数组或对象
        final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonStr);
        if (arrayMatch != null) {
          try {
            decoded = jsonDecode(arrayMatch.group(0)!);
          } catch (_) {}
        }
        if (decoded == null) {
          final objMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
          if (objMatch != null) {
            try {
              decoded = jsonDecode(objMatch.group(0)!);
            } catch (_) {}
          }
        }
      }

      if (decoded == null) {
        debugPrint('parseMultipleResults: 无法解析JSON');
        return [];
      }

      // 如果是数组，逐个解析
      if (decoded is List) {
        debugPrint('parseMultipleResults: 检测到数组，长度=${decoded.length}');
        final items = <MemoryItem>[];
        for (var i = 0; i < decoded.length; i++) {
          final itemJson = jsonEncode(decoded[i]);
          final item = parseAnalysisResult(
            itemJson,
            imagePath,
            thumbnailPath,
            idOffset: i,
          );
          if (item != null) items.add(item);
        }
        if (items.isNotEmpty) return items;
      }

      // 如果是单个对象，直接解析
      if (decoded is Map<String, dynamic>) {
        debugPrint('parseMultipleResults: 检测到单对象');
        final item = parseAnalysisResult(result, imagePath, thumbnailPath);
        return item != null ? [item] : [];
      }

      return [];
    } catch (e) {
      debugPrint('parseMultipleResults 解析失败: $e');
      // 最终回退
      final single = parseAnalysisResult(result, imagePath, thumbnailPath);
      return single != null ? [single] : [];
    }
  }

  MemoryItem? parseAnalysisResult(
    String? result,
    String imagePath,
    String? thumbnailPath, {
    int idOffset = 0,
  }) {
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
      var title = json['title'] as String? ?? '未命名记忆';

      MemoryCategory category;
      switch (categoryStr) {
        case '取餐码':
        case '取茶码':
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

      // 二次校验：取餐码的 title 不应该是日期时间格式
      // 带日期时间的截图（聊天记录、通知等）容易被误识别为取餐码
      if (category == MemoryCategory.pickupCode) {
        final codeTitle = title.trim();
        // 检测常见日期时间格式：
        // "2024-03-20", "03-20", "3月20日", "14:30", "2024/03/20", "03/20"
        // "2024.03.20", "周一", "星期一", "上午", "下午"
        final looksLikeDateTime = RegExp(
          r'^\d{2,4}[\-/\.]\d{1,2}[\-/\.]\d{1,2}$|' // 2024-03-20, 03/20/2024
          r'^\d{1,2}[\-/\.]\d{1,2}$|' // 03-20, 3/20
          r'^\d{1,2}月\d{1,2}日?$|' // 3月20日, 3月20
          r'^\d{1,2}:\d{2}(:\d{2})?$|' // 14:30, 14:30:00
          r'^\d{2,4}年\d{1,2}月\d{1,2}日?$|' // 2024年3月20日
          r'^(周[一二三四五六日天]|星期[一二三四五六日天])$|' // 周一, 星期一
          r'^(上午|下午|凌晨|早上|晚上)\d{1,2}:\d{2}$', // 上午10:30
        ).hasMatch(codeTitle);
        if (looksLikeDateTime) {
          category = MemoryCategory.note;
          debugPrint('二次校验：取餐码标题"$codeTitle"看起来像日期时间，降级为随手记');
        }
        // 检测 title 和 summary 中是否完全没有取餐相关上下文
        // 如果 summary 中没有任何取餐/点餐/排队相关词汇，大概率是误识别
        if (category == MemoryCategory.pickupCode) {
          final summaryText = (json['summary'] as String? ?? '').toLowerCase();
          final titleText = title.toLowerCase();
          final combinedText = '$titleText $summaryText';
          const pickupContextKeywords = [
            '取餐',
            '取茶',
            '排队',
            '叫号',
            '点餐',
            '下单',
            '外卖',
            '堂食',
            '餐厅',
            '奶茶',
            '咖啡',
            '饮品',
            '门店',
            '柜台',
            '窗口',
            '等候',
            '备餐',
          ];
          final hasPickupContext = pickupContextKeywords.any(
            (kw) => combinedText.contains(kw),
          );
          if (!hasPickupContext) {
            // 再检查 infoSections 中是否有取餐相关信息
            final sectionsText = jsonEncode(
              json['infoSections'] ?? [],
            ).toLowerCase();
            final hasPickupInSections = pickupContextKeywords.any(
              (kw) => sectionsText.contains(kw),
            );
            if (!hasPickupInSections) {
              category = MemoryCategory.note;
              debugPrint('二次校验：取餐码分类但无任何取餐上下文，降级为随手记');
            }
          }
        }
      }

      // 二次校验：账单的 amount 必须像真实金额（含数字和可选的货币符号/小数点）
      // 如果 amount 看起来像取餐码/取件码（如 "A032"、"12号"），清除 amount
      if (category == MemoryCategory.bill) {
        final rawAmount = getNonEmptyString(json, 'amount');
        if (rawAmount != null) {
          // 去掉货币符号和空格后，应该是纯数字或带小数点的数字
          final cleaned = rawAmount.replaceAll(RegExp(r'[¥￥$€£\s,，+\-]'), '');
          final looksLikeMoney = RegExp(r'^\d+\.?\d*$').hasMatch(cleaned);
          if (!looksLikeMoney) {
            debugPrint('二次校验：amount "$rawAmount" 不像金额，清除');
            json['amount'] = null;
            // 如果清除 amount 后没有其他账单特征，降级为随手记
            if (getNonEmptyString(json, 'billCategory') == null &&
                getNonEmptyString(json, 'paymentMethod') == null &&
                getNonEmptyString(json, 'merchantName') == null) {
              category = MemoryCategory.note;
              debugPrint('二次校验：无账单特征字段，降级为随手记');
            }
          }
        }
      }

      // 二次校验：如果 AI 分类为服饰，但内容实际是食物相关，降级为随手记
      if (category == MemoryCategory.clothing) {
        final fullText = '$title ${json['summary'] ?? ''}'.toLowerCase();
        const foodKeywords = [
          '蛋糕',
          '面包',
          '甜品',
          '甜点',
          '奶茶',
          '咖啡',
          '饮料',
          '果汁',
          '冰淇淋',
          '巧克力',
          '饼干',
          '糖果',
          '零食',
          '小吃',
          '烧烤',
          '火锅',
          '寿司',
          '拉面',
          '披萨',
          '汉堡',
          '三明治',
          '沙拉',
          '牛排',
          '炸鸡',
          '奶油',
          '芝士',
          '抹茶',
          '草莓',
          '水果',
          '美食',
          '食物',
          '餐厅',
          '外卖',
          '堂食',
          '菜单',
          '菜品',
          '料理',
          '烘焙',
          '甜食',
          '糕点',
          '饭',
          '粥',
          '面',
          '汤',
          '菜',
          '肉',
          '鱼',
          '虾',
          '蟹',
          '奶酪',
          '酸奶',
          '布丁',
          '马卡龙',
          '提拉米苏',
          '慕斯',
        ];
        for (final keyword in foodKeywords) {
          if (fullText.contains(keyword)) {
            category = MemoryCategory.note;
            debugPrint('二次校验：服饰分类但包含食物关键词"$keyword"，降级为随手记');
            break;
          }
        }
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

      // 二次校验：如果 AI 分类为随手记，但内容中包含取餐码/取茶码关键词或有 pickupCode 字段，强制改为取餐码
      if (category == MemoryCategory.note) {
        final hasPickupCode = getNonEmptyString(json, 'pickupCode') != null;
        if (hasPickupCode) {
          category = MemoryCategory.pickupCode;
          debugPrint('二次校验：检测到pickupCode字段，强制改为取餐码分类');
        } else {
          final fullText = '$title ${json['summary'] ?? ''}'.toLowerCase();
          const pickupKeywords = ['取餐码', '取茶码', '取餐号', '排队号', '叫号'];
          for (final keyword in pickupKeywords) {
            if (fullText.contains(keyword)) {
              category = MemoryCategory.pickupCode;
              debugPrint('二次校验命中取餐码关键词: $keyword，强制改为取餐码分类');
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

      // 标题后处理：取件码类型强制使用取件码作为标题
      if (category == MemoryCategory.packageCode) {
        debugPrint('取件码原始title: $title');
        debugPrint('取件码JSON: ${jsonEncode(json)}');

        // 收集所有候选码值
        final List<String> candidates = [];

        // 1. 顶层 pickupCode / code 字段
        for (final key in ['pickupCode', 'code', 'packageCode']) {
          final val = json[key];
          if (val is String && val.trim().isNotEmpty) {
            candidates.add(val.trim());
          }
        }

        // 2. 从 infoSections 中按 label 关键词查找
        final sections = json['infoSections'] as List<dynamic>?;
        if (sections != null) {
          for (final section in sections) {
            final items = section['items'] as List<dynamic>?;
            if (items == null) continue;
            for (final item in items) {
              final label = (item['label'] as String? ?? '');
              final val = (item['value'] as String? ?? '').trim();
              if (val.isEmpty) continue;
              // 标签含关键词
              if (label.contains('取件码') ||
                  label.contains('取件号') ||
                  label.contains('编号') ||
                  label.contains('码') ||
                  label.contains('code')) {
                candidates.add(val);
              }
            }
          }
        }

        // 3. 从 infoSections 中找所有看起来像码值的 value
        //    码值特征：含数字和分隔符（如 12-3-4567, 3 1 1234）
        if (sections != null) {
          for (final section in sections) {
            final items = section['items'] as List<dynamic>?;
            if (items == null) continue;
            for (final item in items) {
              final val = (item['value'] as String? ?? '').trim();
              if (val.isEmpty) continue;
              // 宽松匹配：主要由数字和分隔符组成，至少含2个数字
              if (RegExp(r'^[\d\-\s\.]+$').hasMatch(val) &&
                  RegExp(r'\d.*\d').hasMatch(val)) {
                candidates.add(val);
              }
            }
          }
        }

        // 4. 检查 title 本身是否就是码值
        if (RegExp(r'^[\d\-\s\.]+$').hasMatch(title) &&
            RegExp(r'\d').hasMatch(title)) {
          candidates.insert(0, title);
        }

        // 5. 从整个 JSON 文本中用正则提取码值模式（如 12-3-4567）
        if (candidates.isEmpty) {
          final fullText = jsonEncode(json);
          // 匹配 数字-数字-数字 格式（典型取件码）
          final codeMatches = RegExp(
            r'\d+[\-\s]\d+[\-\s]\d+',
          ).allMatches(fullText);
          for (final m in codeMatches) {
            candidates.add(m.group(0)!.trim());
          }
          // 匹配纯数字序列（至少3位）
          if (candidates.isEmpty) {
            final numMatch = RegExp(
              r'(?<!\d)\d{3,}(?!\d)',
            ).firstMatch(fullText);
            if (numMatch != null) {
              candidates.add(numMatch.group(0)!.trim());
            }
          }
        }

        debugPrint('取件码候选: $candidates');

        if (candidates.isNotEmpty) {
          title = candidates.first;
        }
        debugPrint('取件码最终标题: $title');
      }
      // 标题后处理：取餐码类型强制使用取餐码本身
      if (category == MemoryCategory.pickupCode) {
        final code = _extractCodeFromJson(json, 'pickupCode', [
          '取餐码',
          '取餐号',
          '取茶码',
          '取茶号',
          '编号',
          '号码',
          '码',
        ]);
        if (code != null) {
          title = code;
        }
        // 不降级：即使无法从字段中提取码值，title 本身可能就是码值（AI prompt 要求 title 填码值）
      }

      // 校验：取件码类型如果最终标题不含数字，降级为随手记
      if (category == MemoryCategory.packageCode) {
        if (!RegExp(r'\d').hasMatch(title)) {
          debugPrint('取件码分类但标题不含数字，降级为随手记');
          category = MemoryCategory.note;
        }
      }

      // 标题兜底：如果标题为空，使用摘要或默认值
      if (title.trim().isEmpty) {
        final summary = getNonEmptyString(json, 'summary');
        if (summary != null && summary.length <= 30) {
          title = summary;
        } else if (summary != null) {
          title = '${summary.substring(0, 27)}...';
        } else {
          title = '随手记';
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
        id: (DateTime.now().millisecondsSinceEpoch + idOffset).toString(),
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
    final apiKey = await _configService.getActiveApiKey();
    return apiKey.isNotEmpty;
  }
}
