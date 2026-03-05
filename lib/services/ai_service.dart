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

    final systemPrompt = '''你是一个智能助手
专门分析用户分享的图片内容。请根据图片内容进行分析：

1. 判断图片属于哪个分类：
   - 取餐码：包含餐厅取餐码、取餐号的图片
   - 取件码：包含快递取件码、取件码的图片
   - 账单：包含消费金额、支付信息的图片
   - 随手记：其他无法分类的内容

2. 根据分类提取关键信息作为标题（标题要精简，不要重复分类名称）：
   - 取餐码：只提取店铺名称和取餐码，格式如"肯德基 A001"或"A001"（无店铺名时）
   - 取件码：只提取取件码，格式如"12-3-4567"
   - 账单：提取金额，并根据收支类型添加符号：
     * 支出：格式如"-¥35.00"
     * 收入：格式如"+¥100.00"
     * 无法判断时默认为支出
   - 随手记：简要描述图片内容

3. 根据分类提取详细信息（可选字段，如果图片中有则提取，没有则不填）：
   - 取餐码：shopName(店铺名称)、pickupCode(取餐码)、dishName(餐品名称)
   - 取件码：expressCompany(快递公司)、pickupCode(取件码)、pickupAddress(取件地址)、productType(商品类型)、trackingNumber(快递单号)
   - 账单：amount(金额，带符号如"-35.00")、isExpense(布尔值，true表示支出，false表示收入)、billCategory(账单分类，必须从以下分类中选择一个最匹配的)、billTime(账单时间，格式为"YYYY-MM-DD HH:mm"，从图片中识别的交易时间)：
     * 支出分类及示例：
       - 餐饮：餐厅消费、外卖订单、奶茶咖啡、食堂用餐
       - 零食：水果店、甜品蛋糕、零食小吃
       - 交通：打车滴滴、公交地铁、加油充电、停车费
       - 日用：超市购物、便利店、日用品采购
       - 娱乐：电影票、游戏充值、KTV、游乐园
       - 运动：健身房、体育用品、运动场馆
       - 服饰：衣服鞋子、服装店、箱包
       - 家居：家具家电、装修材料、家居用品
       - 通讯：话费充值、宽带费用
       - 烟酒：香烟、酒水饮料
       - 医疗：医院挂号、药店买药、体检
       - 教育：学费、培训课程、书籍
       - 礼物：生日礼物、节日礼品
       - 宠物：宠物食品、宠物医院、宠物用品
       - 美容：理发店、美容院、化妆品
       - 维修：家电维修、手机维修、汽车维修
       - 旅行：机票火车票、酒店住宿、景点门票
       - 汽车：汽车保养、洗车、违章罚款
       - 保险：车险、寿险、医疗险
       - 税费：个人所得税、房产税
       - 投资：股票买入、基金购买、理财产品
       - 转账：微信转账给他人、支付宝转账、银行卡转账、红包发送
       - 其他：无法归类的支出
     * 收入分类及示例：
       - 工资：月薪、工资收入
       - 奖金：年终奖、绩效奖金
       - 投资：股票收益、基金分红、理财收益
       - 兼职：兼职收入、稿费
       - 红包：收到微信红包、支付宝红包
       - 退款：购物退款、退货退款
       - 转账：收到微信转账、收到支付宝转账、收到银行卡转账
       - 其他：无法归类的收入
   - paymentMethod(支付方式)、merchantName(商户名称)

请严格按照以下JSON格式返回，不要包含其他内容：
{"category":"分类名称","title":"提取的标题","shopName":"店铺名称","pickupCode":"取餐码/取件码","dishName":"餐品名称","expressCompany":"快递公司","pickupAddress":"取件地址","productType":"商品类型","trackingNumber":"快递单号","amount":"金额","isExpense":true/false,"billCategory":"账单分类","paymentMethod":"支付方式","merchantName":"商户名称","billTime":"账单时间"}

注意：只填写图片中实际存在的信息，不存在的字段请省略或留空。billCategory必须从上面列出的分类中选择，不要自创分类名称。billTime格式为"YYYY-MM-DD HH:mm"，如"2024-01-15 14:30"。''';

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
