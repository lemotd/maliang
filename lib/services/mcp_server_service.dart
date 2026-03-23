import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';
import '../models/memory_item.dart';

/// 内嵌 MCP HTTP Server，运行在 app 进程内。
/// 监听 127.0.0.1，同一台设备上的 AI app 可通过 localhost 连接。
class McpServerService {
  static final McpServerService _instance = McpServerService._internal();
  factory McpServerService() => _instance;
  McpServerService._internal();

  HttpServer? _server;
  final MemoryService _memoryService = MemoryService();
  String _authToken = '';

  static const int port = 8765;
  static const String _keyMcpToken = 'mcp_auth_token';

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    await _loadToken();
    // 监听所有接口，支持 localhost 和局域网
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_keyMcpToken) ?? '';
  }

  void _handleRequest(HttpRequest request) async {
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set(
      'Access-Control-Allow-Methods',
      'GET, POST, DELETE, OPTIONS',
    );
    request.response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }

    if (_authToken.isNotEmpty) {
      final auth = request.headers.value('authorization') ?? '';
      if (auth != 'Bearer $_authToken') {
        _sendJson(request, 401, {
          'jsonrpc': '2.0',
          'error': {'code': -32000, 'message': 'Unauthorized'},
        });
        return;
      }
    }

    final path = request.uri.path;

    if (path == '/mcp' && request.method == 'POST') {
      await _handleMcpPost(request);
    } else if (path == '/mcp' && request.method == 'GET') {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      await request.response.close();
    } else if (path == '/mcp' && request.method == 'DELETE') {
      // Session termination
      request.response.statusCode = 200;
      await request.response.close();
    } else {
      _sendJson(request, 404, {
        'jsonrpc': '2.0',
        'error': {'code': -32601, 'message': 'Not found'},
      });
    }
  }

  Future<void> _handleMcpPost(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final method = json['method'] as String? ?? '';
      final id = json['id'];
      final params = json['params'] as Map<String, dynamic>? ?? {};

      // 通知类消息无需响应
      if (method.startsWith('notifications/')) {
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }

      Object? result;
      switch (method) {
        case 'initialize':
          result = _handleInitialize();
          break;
        case 'tools/list':
          result = _handleToolsList();
          break;
        case 'tools/call':
          result = await _handleToolsCall(params);
          break;
        default:
          _sendJson(request, 200, {
            'jsonrpc': '2.0',
            'id': id,
            'error': {'code': -32601, 'message': 'Method not found: $method'},
          });
          return;
      }

      _sendJson(request, 200, {'jsonrpc': '2.0', 'id': id, 'result': result});
    } catch (e) {
      _sendJson(request, 200, {
        'jsonrpc': '2.0',
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error: $e'},
      });
    }
  }

  Map<String, dynamic> _handleInitialize() {
    return {
      'protocolVersion': '2025-03-26',
      'capabilities': {
        'tools': {'listChanged': false},
      },
      'serverInfo': {'name': 'maliang-notes', 'version': '1.0.0'},
    };
  }

  Map<String, dynamic> _handleToolsList() {
    return {
      'tools': [
        _td('list_memories', '列出记忆条目，支持分类/关键词/状态筛选', {
          'category': {
            'type': 'string',
            'description': '分类: pickupCode/packageCode/bill/clothing/note',
          },
          'keyword': {'type': 'string', 'description': '搜索关键词'},
          'completed': {'type': 'boolean', 'description': '完成状态筛选'},
          'limit': {'type': 'integer', 'description': '返回数量上限，默认50'},
        }, []),
        _td(
          'get_memory',
          '获取单条记忆详情',
          {
            'memory_id': {'type': 'string', 'description': '记忆ID'},
          },
          ['memory_id'],
        ),
        _td(
          'search_memories',
          '全文搜索记忆',
          {
            'query': {'type': 'string', 'description': '搜索关键词'},
          },
          ['query'],
        ),
        _td('query_bills', '查询账单记录', {
          'start_date': {'type': 'string', 'description': '开始日期 YYYY-MM-DD'},
          'end_date': {'type': 'string', 'description': '结束日期 YYYY-MM-DD'},
          'bill_category': {'type': 'string', 'description': '账单分类'},
          'min_amount': {'type': 'number', 'description': '最小金额'},
          'max_amount': {'type': 'number', 'description': '最大金额'},
        }, []),
        _td('get_bill_summary', '获取账单统计摘要', {
          'period': {'type': 'string', 'description': '统计周期: week/month/year'},
        }, []),
        _td(
          'add_memory',
          '添加新记忆',
          {
            'title': {'type': 'string', 'description': '标题'},
            'category': {'type': 'string', 'description': '分类'},
            'raw_content': {'type': 'string', 'description': '原始内容'},
            'amount': {'type': 'string', 'description': '金额'},
            'is_expense': {'type': 'boolean', 'description': '是否支出'},
            'bill_category': {'type': 'string', 'description': '账单分类'},
            'merchant_name': {'type': 'string', 'description': '商户名称'},
            'note': {'type': 'string', 'description': '备注'},
          },
          ['title'],
        ),
        _td(
          'update_memory',
          '更新记忆',
          {
            'memory_id': {'type': 'string', 'description': '记忆ID'},
            'title': {'type': 'string', 'description': '新标题'},
            'is_completed': {'type': 'boolean', 'description': '完成状态'},
            'note': {'type': 'string', 'description': '备注'},
            'amount': {'type': 'string', 'description': '金额'},
          },
          ['memory_id'],
        ),
        _td(
          'delete_memory',
          '删除记忆',
          {
            'memory_id': {'type': 'string', 'description': '记忆ID'},
          },
          ['memory_id'],
        ),
        _td(
          'toggle_memory_completed',
          '切换完成状态',
          {
            'memory_id': {'type': 'string', 'description': '记忆ID'},
          },
          ['memory_id'],
        ),
      ],
    };
  }

  Map<String, dynamic> _td(
    String name,
    String desc,
    Map<String, dynamic> props,
    List<String> req,
  ) {
    return {
      'name': name,
      'description': desc,
      'inputSchema': {
        'type': 'object',
        'properties': props,
        if (req.isNotEmpty) 'required': req,
      },
    };
  }

  Future<Map<String, dynamic>> _handleToolsCall(
    Map<String, dynamic> params,
  ) async {
    final name = params['name'] as String? ?? '';
    final args = params['arguments'] as Map<String, dynamic>? ?? {};
    try {
      final text = await _callTool(name, args);
      return {
        'content': [
          {'type': 'text', 'text': text},
        ],
      };
    } catch (e) {
      return {
        'content': [
          {'type': 'text', 'text': '{"error":"$e"}'},
        ],
        'isError': true,
      };
    }
  }

  Future<String> _callTool(String name, Map<String, dynamic> a) async {
    switch (name) {
      case 'list_memories':
        return _tListMemories(a);
      case 'get_memory':
        return _tGetMemory(a);
      case 'search_memories':
        return _tSearch(a);
      case 'query_bills':
        return _tQueryBills(a);
      case 'get_bill_summary':
        return _tBillSummary(a);
      case 'add_memory':
        return _tAdd(a);
      case 'update_memory':
        return _tUpdate(a);
      case 'delete_memory':
        return _tDelete(a);
      case 'toggle_memory_completed':
        return _tToggle(a);
      default:
        return jsonEncode({'error': '未知工具: $name'});
    }
  }

  Map<String, dynamic> _strip(MemoryItem m) {
    final j = m.toJson();
    j.remove('imagePath');
    j.remove('thumbnailPath');
    return j;
  }

  Future<String> _tListMemories(Map<String, dynamic> a) async {
    var list = await _memoryService.getAllMemories();
    final cat = a['category'] as String?;
    final kw = a['keyword'] as String?;
    final done = a['completed'] as bool?;
    final limit = (a['limit'] as num?)?.toInt() ?? 50;
    if (cat != null) list = list.where((m) => m.category.name == cat).toList();
    if (done != null) list = list.where((m) => m.isCompleted == done).toList();
    if (kw != null && kw.isNotEmpty) {
      final k = kw.toLowerCase();
      list = list
          .where(
            (m) =>
                m.title.toLowerCase().contains(k) ||
                (m.rawContent ?? '').toLowerCase().contains(k),
          )
          .toList();
    }
    return jsonEncode({
      'total': list.length,
      'items': list.take(limit).map(_strip).toList(),
    });
  }

  Future<String> _tGetMemory(Map<String, dynamic> a) async {
    final id = a['memory_id'] as String? ?? '';
    final all = await _memoryService.getAllMemories();
    final m = all.where((m) => m.id == id).firstOrNull;
    if (m == null) return jsonEncode({'error': '未找到'});
    return jsonEncode(_strip(m));
  }

  Future<String> _tSearch(Map<String, dynamic> a) async {
    final q = (a['query'] as String? ?? '').toLowerCase();
    final all = await _memoryService.getAllMemories();
    final r = all
        .where(
          (m) =>
              '${m.title} ${m.rawContent ?? ''} ${m.merchantName ?? ''} ${m.note ?? ''}'
                  .toLowerCase()
                  .contains(q),
        )
        .map(_strip)
        .toList();
    return jsonEncode({'count': r.length, 'items': r});
  }

  Future<String> _tQueryBills(Map<String, dynamic> a) async {
    var bills = (await _memoryService.getAllMemories())
        .where((m) => m.category == MemoryCategory.bill)
        .toList();
    final sd = a['start_date'] as String?;
    final ed = a['end_date'] as String?;
    if (sd != null) {
      final s = DateTime.parse(sd);
      bills = bills.where((b) => !b.createdAt.isBefore(s)).toList();
    }
    if (ed != null) {
      final e = DateTime.parse(ed).add(const Duration(days: 1));
      bills = bills.where((b) => b.createdAt.isBefore(e)).toList();
    }
    double pa(MemoryItem b) =>
        double.tryParse(
          (b.amount ?? '0').replaceAll('¥', '').replaceAll(',', '').trim(),
        ) ??
        0;
    final exp = bills
        .where((b) => b.isExpense == true)
        .fold<double>(0, (s, b) => s + pa(b));
    final inc = bills
        .where((b) => b.isExpense == false)
        .fold<double>(0, (s, b) => s + pa(b));
    return jsonEncode({
      'count': bills.length,
      'expenseTotal': double.parse(exp.toStringAsFixed(2)),
      'incomeTotal': double.parse(inc.toStringAsFixed(2)),
      'items': bills.map(_strip).toList(),
    });
  }

  Future<String> _tBillSummary(Map<String, dynamic> a) async {
    final period = a['period'] as String? ?? 'month';
    final now = DateTime.now();
    late DateTime start;
    if (period == 'week') {
      start = DateTime(now.year, now.month, now.day - now.weekday);
    } else if (period == 'year') {
      start = DateTime(now.year);
    } else {
      start = DateTime(now.year, now.month);
    }
    final bills = (await _memoryService.getAllMemories())
        .where(
          (m) =>
              m.category == MemoryCategory.bill && !m.createdAt.isBefore(start),
        )
        .toList();
    double pa(MemoryItem b) =>
        double.tryParse(
          (b.amount ?? '0').replaceAll('¥', '').replaceAll(',', '').trim(),
        ) ??
        0;
    final exp = bills
        .where((b) => b.isExpense == true)
        .fold<double>(0, (s, b) => s + pa(b));
    final inc = bills
        .where((b) => b.isExpense == false)
        .fold<double>(0, (s, b) => s + pa(b));
    return jsonEncode({
      'period': period,
      'totalExpense': double.parse(exp.toStringAsFixed(2)),
      'totalIncome': double.parse(inc.toStringAsFixed(2)),
    });
  }

  Future<String> _tAdd(Map<String, dynamic> a) async {
    final title = a['title'] as String? ?? '';
    if (title.isEmpty) return jsonEncode({'error': '标题不能为空'});
    final catName = a['category'] as String? ?? 'note';
    final cat = MemoryCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => MemoryCategory.note,
    );
    final m = MemoryItem(
      id: 'mcp_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      title: title,
      category: cat,
      createdAt: DateTime.now(),
      rawContent: a['raw_content'] as String?,
      amount: a['amount'] as String?,
      isExpense: a['is_expense'] as bool?,
      billCategory: a['bill_category'] as String?,
      merchantName: a['merchant_name'] as String?,
      note: a['note'] as String?,
    );
    await _memoryService.addMemory(m);
    return jsonEncode({'success': true, 'id': m.id, 'message': '已添加: $title'});
  }

  Future<String> _tUpdate(Map<String, dynamic> a) async {
    final id = a['memory_id'] as String? ?? '';
    final all = await _memoryService.getAllMemories();
    final m = all.where((m) => m.id == id).firstOrNull;
    if (m == null) return jsonEncode({'error': '未找到'});
    final u = m.copyWith(
      title: a['title'] as String?,
      isCompleted: a['is_completed'] as bool?,
      note: a['note'] as String?,
      amount: a['amount'] as String?,
    );
    await _memoryService.updateMemory(u);
    return jsonEncode({'success': true, 'message': '已更新: ${u.title}'});
  }

  Future<String> _tDelete(Map<String, dynamic> a) async {
    await _memoryService.deleteMemory(a['memory_id'] as String? ?? '');
    return jsonEncode({'success': true, 'message': '已删除'});
  }

  Future<String> _tToggle(Map<String, dynamic> a) async {
    final id = a['memory_id'] as String? ?? '';
    await _memoryService.toggleCompleted(id);
    return jsonEncode({'success': true, 'message': '已切换'});
  }

  void _sendJson(HttpRequest request, int code, Map<String, dynamic> data) {
    request.response.statusCode = code;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
    request.response.close();
  }
}
