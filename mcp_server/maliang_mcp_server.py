#!/usr/bin/env python3
"""
马良神记 MCP Server
独立运行的 MCP Server，通过 .maliang 备份文件读写马良神记数据。
支持 streamable-http / sse / stdio 三种传输模式。
支持公网部署，Bearer Token 鉴权。

启动方式:
  # 默认 streamable-http 模式（推荐）
  python maliang_mcp_server.py

  # 指定数据文件和端口
  MALIANG_DATA_FILE=data.maliang MCP_PORT=8765 python maliang_mcp_server.py

  # 带 Token 鉴权
  MCP_AUTH_TOKEN=your_token python maliang_mcp_server.py

  # stdio 模式（本地 MCP 客户端）
  MCP_TRANSPORT=stdio python maliang_mcp_server.py
"""

import json
import os
import base64
from datetime import datetime, timedelta
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("maliang-notes")

DATA_FILE = os.environ.get("MALIANG_DATA_FILE", "")


def _get_data_file() -> str:
    if DATA_FILE:
        return DATA_FILE
    maliang_files = [f for f in os.listdir(".") if f.endswith(".maliang")]
    if not maliang_files:
        raise FileNotFoundError("未找到 .maliang 数据文件，请设置 MALIANG_DATA_FILE 环境变量")
    maliang_files.sort(key=lambda f: os.path.getmtime(f), reverse=True)
    return maliang_files[0]


def _load_data() -> dict:
    path = _get_data_file()
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _save_data(data: dict) -> str:
    path = _get_data_file()
    data["exportTime"] = datetime.now().isoformat()
    data["memoryCount"] = len(data.get("memories", []))
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return path


def _strip_image(memory: dict) -> dict:
    result = {k: v for k, v in memory.items() if k not in ("imageData", "thumbnailData")}
    result["hasImage"] = "imageData" in memory
    result["hasThumbnail"] = "thumbnailData" in memory
    return result


def _parse_amount(b: dict) -> float:
    try:
        return float((b.get("amount") or "0").replace("¥", "").replace(",", "").strip())
    except (ValueError, AttributeError):
        return 0.0


# ============================================================
# Tools
# ============================================================

@mcp.tool()
def list_memories(
    category: str | None = None,
    keyword: str | None = None,
    completed: bool | None = None,
    limit: int = 50,
    offset: int = 0,
) -> str:
    """
    列出记忆条目。

    Args:
        category: 按分类筛选 (pickupCode/packageCode/bill/clothing/note)
        keyword: 按关键词搜索标题和内容
        completed: 按完成状态筛选
        limit: 返回数量上限，默认50
        offset: 偏移量，用于分页
    """
    data = _load_data()
    memories = data.get("memories", [])

    if category:
        memories = [m for m in memories if m.get("category") == category]
    if completed is not None:
        memories = [m for m in memories if m.get("isCompleted", False) == completed]
    if keyword:
        kw = keyword.lower()
        memories = [
            m for m in memories
            if kw in (m.get("title", "") or "").lower()
            or kw in (m.get("rawContent", "") or "").lower()
            or kw in (m.get("summary", "") or "").lower()
            or kw in (m.get("merchantName", "") or "").lower()
            or kw in (m.get("shopName", "") or "").lower()
        ]

    total = len(memories)
    items = [_strip_image(m) for m in memories[offset:offset + limit]]
    return json.dumps({"total": total, "offset": offset, "limit": limit, "items": items}, ensure_ascii=False, indent=2)


@mcp.tool()
def get_memory(memory_id: str) -> str:
    """
    获取单条记忆的详细信息。

    Args:
        memory_id: 记忆ID
    """
    data = _load_data()
    for m in data.get("memories", []):
        if m.get("id") == memory_id:
            return json.dumps(_strip_image(m), ensure_ascii=False, indent=2)
    return json.dumps({"error": f"未找到ID为 {memory_id} 的记忆"}, ensure_ascii=False)


@mcp.tool()
def search_memories(query: str) -> str:
    """
    全文搜索记忆，搜索标题、内容、商户名、备注等所有文本字段。

    Args:
        query: 搜索关键词
    """
    data = _load_data()
    q = query.lower()
    results = []
    for m in data.get("memories", []):
        searchable = " ".join(str(v) for v in m.values() if isinstance(v, str)).lower()
        if q in searchable:
            results.append(_strip_image(m))
    return json.dumps({"query": query, "count": len(results), "items": results}, ensure_ascii=False, indent=2)


@mcp.tool()
def query_bills(
    start_date: str | None = None,
    end_date: str | None = None,
    bill_category: str | None = None,
    expense_only: bool | None = None,
    min_amount: float | None = None,
    max_amount: float | None = None,
) -> str:
    """
    查询账单记录，支持按日期、分类、金额范围筛选。

    Args:
        start_date: 开始日期 (YYYY-MM-DD)
        end_date: 结束日期 (YYYY-MM-DD)
        bill_category: 账单分类
        expense_only: True=仅支出, False=仅收入, None=全部
        min_amount: 最小金额
        max_amount: 最大金额
    """
    data = _load_data()
    bills = [m for m in data.get("memories", []) if m.get("category") == "bill"]

    if start_date:
        start = datetime.fromisoformat(start_date)
        bills = [b for b in bills if datetime.fromisoformat(b.get("createdAt", "2000-01-01")) >= start]
    if end_date:
        end = datetime.fromisoformat(end_date) + timedelta(days=1)
        bills = [b for b in bills if datetime.fromisoformat(b.get("createdAt", "2099-12-31")) < end]
    if bill_category:
        bills = [b for b in bills if b.get("billCategory") == bill_category]
    if expense_only is not None:
        bills = [b for b in bills if b.get("isExpense", True) == expense_only]
    if min_amount is not None:
        bills = [b for b in bills if _parse_amount(b) >= min_amount]
    if max_amount is not None:
        bills = [b for b in bills if _parse_amount(b) <= max_amount]

    expense = sum(_parse_amount(b) for b in bills if b.get("isExpense", True))
    income = sum(_parse_amount(b) for b in bills if not b.get("isExpense", True))

    return json.dumps({
        "count": len(bills),
        "expenseTotal": round(expense, 2),
        "incomeTotal": round(income, 2),
        "items": [_strip_image(b) for b in bills],
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def get_bill_summary(period: str = "month") -> str:
    """
    获取账单统计摘要。

    Args:
        period: 统计周期 (week/month/year)
    """
    data = _load_data()
    bills = [m for m in data.get("memories", []) if m.get("category") == "bill"]
    now = datetime.now()

    if period == "week":
        start = now - timedelta(days=now.weekday())
        start = start.replace(hour=0, minute=0, second=0, microsecond=0)
    elif period == "year":
        start = now.replace(month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    else:
        start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

    period_bills = [
        b for b in bills
        if datetime.fromisoformat(b.get("createdAt", "2000-01-01")) >= start
    ]

    expenses = [b for b in period_bills if b.get("isExpense", True)]
    incomes = [b for b in period_bills if not b.get("isExpense", True)]

    expense_by_cat = {}
    for b in expenses:
        cat = b.get("billCategory", "other")
        expense_by_cat[cat] = expense_by_cat.get(cat, 0) + _parse_amount(b)

    return json.dumps({
        "period": period,
        "startDate": start.isoformat(),
        "totalExpense": round(sum(_parse_amount(b) for b in expenses), 2),
        "totalIncome": round(sum(_parse_amount(b) for b in incomes), 2),
        "expenseCount": len(expenses),
        "incomeCount": len(incomes),
        "expenseByCategory": {k: round(v, 2) for k, v in sorted(expense_by_cat.items(), key=lambda x: -x[1])},
    }, ensure_ascii=False, indent=2)


@mcp.tool()
def add_memory(
    title: str,
    category: str = "note",
    raw_content: str | None = None,
    amount: str | None = None,
    is_expense: bool | None = None,
    bill_category: str | None = None,
    merchant_name: str | None = None,
    payment_method: str | None = None,
    note: str | None = None,
    shop_name: str | None = None,
    pickup_code: str | None = None,
    express_company: str | None = None,
    pickup_address: str | None = None,
) -> str:
    """
    添加一条新记忆。

    Args:
        title: 标题
        category: 分类 (pickupCode/packageCode/bill/clothing/note)
        raw_content: 原始内容文本
        amount: 金额（账单类型）
        is_expense: 是否支出（账单类型）
        bill_category: 账单分类
        merchant_name: 商户名称
        payment_method: 支付方式
        note: 备注
        shop_name: 店铺名称（取餐码类型）
        pickup_code: 取餐码/取件码
        express_company: 快递公司（取件码类型）
        pickup_address: 取件地址
    """
    data = _load_data()
    memories = data.get("memories", [])
    now = datetime.now()
    memory_id = f"mcp_{now.strftime('%Y%m%d%H%M%S')}_{len(memories)}"

    new_memory = {
        "id": memory_id, "title": title, "category": category,
        "createdAt": now.isoformat(), "isCompleted": False,
        "rawContent": raw_content, "amount": amount, "isExpense": is_expense,
        "billCategory": bill_category, "merchantName": merchant_name,
        "paymentMethod": payment_method, "note": note, "shopName": shop_name,
        "pickupCode": pickup_code, "expressCompany": express_company,
        "pickupAddress": pickup_address, "infoSections": [],
    }
    new_memory = {k: v for k, v in new_memory.items() if v is not None}

    memories.insert(0, new_memory)
    data["memories"] = memories
    path = _save_data(data)
    return json.dumps({"success": True, "id": memory_id, "message": f"已添加: {title}", "savedTo": path}, ensure_ascii=False, indent=2)


@mcp.tool()
def update_memory(
    memory_id: str,
    title: str | None = None,
    is_completed: bool | None = None,
    note: str | None = None,
    amount: str | None = None,
    bill_category: str | None = None,
    raw_content: str | None = None,
) -> str:
    """
    更新一条记忆。

    Args:
        memory_id: 记忆ID
        title: 新标题
        is_completed: 完成状态
        note: 备注
        amount: 金额
        bill_category: 账单分类
        raw_content: 原始内容
    """
    data = _load_data()
    for m in data.get("memories", []):
        if m.get("id") == memory_id:
            if title is not None: m["title"] = title
            if is_completed is not None: m["isCompleted"] = is_completed
            if note is not None: m["note"] = note
            if amount is not None: m["amount"] = amount
            if bill_category is not None: m["billCategory"] = bill_category
            if raw_content is not None: m["rawContent"] = raw_content
            path = _save_data(data)
            return json.dumps({"success": True, "message": f"已更新: {m.get('title')}", "savedTo": path}, ensure_ascii=False, indent=2)
    return json.dumps({"error": f"未找到ID为 {memory_id} 的记忆"}, ensure_ascii=False)


@mcp.tool()
def delete_memory(memory_id: str) -> str:
    """
    删除一条记忆。

    Args:
        memory_id: 记忆ID
    """
    data = _load_data()
    memories = data.get("memories", [])
    original = len(memories)
    memories = [m for m in memories if m.get("id") != memory_id]
    if len(memories) == original:
        return json.dumps({"error": f"未找到ID为 {memory_id} 的记忆"}, ensure_ascii=False)
    data["memories"] = memories
    path = _save_data(data)
    return json.dumps({"success": True, "message": "已删除", "remainingCount": len(memories), "savedTo": path}, ensure_ascii=False, indent=2)


@mcp.tool()
def toggle_memory_completed(memory_id: str) -> str:
    """
    切换记忆的完成状态。

    Args:
        memory_id: 记忆ID
    """
    data = _load_data()
    for m in data.get("memories", []):
        if m.get("id") == memory_id:
            m["isCompleted"] = not m.get("isCompleted", False)
            path = _save_data(data)
            status = "已完成" if m["isCompleted"] else "未完成"
            return json.dumps({"success": True, "message": f"已标记为{status}", "isCompleted": m["isCompleted"], "savedTo": path}, ensure_ascii=False, indent=2)
    return json.dumps({"error": f"未找到ID为 {memory_id} 的记忆"}, ensure_ascii=False)


@mcp.tool()
def export_memory_image(memory_id: str, output_path: str) -> str:
    """
    导出记忆关联的图片到指定路径。

    Args:
        memory_id: 记忆ID
        output_path: 输出文件路径
    """
    data = _load_data()
    for m in data.get("memories", []):
        if m.get("id") == memory_id:
            image_data = m.get("imageData")
            if not image_data:
                return json.dumps({"error": "该记忆没有关联图片"}, ensure_ascii=False)
            img_bytes = base64.b64decode(image_data)
            with open(output_path, "wb") as f:
                f.write(img_bytes)
            return json.dumps({"success": True, "message": f"图片已导出到 {output_path}", "size": len(img_bytes)}, ensure_ascii=False, indent=2)
    return json.dumps({"error": f"未找到ID为 {memory_id} 的记忆"}, ensure_ascii=False)


# ============================================================
# 入口
# ============================================================

if __name__ == "__main__":
    transport = os.environ.get("MCP_TRANSPORT", "streamable-http")

    if transport == "stdio":
        mcp.run(transport="stdio")
    else:
        import uvicorn
        from starlette.middleware.base import BaseHTTPMiddleware
        from starlette.responses import JSONResponse

        host = os.environ.get("MCP_HOST", "0.0.0.0")
        port = int(os.environ.get("MCP_PORT", "8765"))
        auth_token = os.environ.get("MCP_AUTH_TOKEN", "")

        class TokenAuthMiddleware(BaseHTTPMiddleware):
            async def dispatch(self, request, call_next):
                if auth_token:
                    auth_header = request.headers.get("authorization", "")
                    if auth_header != f"Bearer {auth_token}":
                        return JSONResponse({"error": "Unauthorized"}, status_code=401)
                return await call_next(request)

        if transport == "sse":
            app = mcp.sse_app()
        else:
            app = mcp.streamable_http_app()

        app.add_middleware(TokenAuthMiddleware)

        print(f"🚀 马良神记 MCP Server 启动: http://{host}:{port}/mcp")
        if auth_token:
            print(f"🔑 Token 鉴权已启用")
        else:
            print(f"⚠️  未设置 MCP_AUTH_TOKEN，无鉴权模式")

        uvicorn.run(app, host=host, port=port)
