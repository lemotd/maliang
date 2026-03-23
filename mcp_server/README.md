# 马良神记 MCP Server

让支持 MCP 协议的 AI 软件读写马良神记的数据。

## 快速启动

```bash
cd mcp_server

# 安装依赖
pip install mcp uvicorn starlette

# 启动（指定数据文件和 Token）
MALIANG_DATA_FILE=data.maliang MCP_AUTH_TOKEN=your_token python maliang_mcp_server.py
```

Server 默认监听 `http://0.0.0.0:8765/mcp`。

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `MALIANG_DATA_FILE` | `.maliang` 数据文件路径 | 自动查找当前目录 |
| `MCP_PORT` | 监听端口 | `8765` |
| `MCP_HOST` | 监听地址 | `0.0.0.0` |
| `MCP_AUTH_TOKEN` | Bearer Token（为空则不鉴权） | 空 |
| `MCP_TRANSPORT` | 传输模式：`streamable-http` / `sse` / `stdio` | `streamable-http` |

## AI 客户端配置

在 AI 软件的 MCP 配置中添加：

```json
{
  "mcpServers": {
    "马良神记": {
      "type": "streamable-http",
      "url": "http://your-server:8765/mcp",
      "headers": {
        "Authorization": "Bearer your_token"
      }
    }
  }
}
```

## 公网部署

推荐使用 nginx 反向代理 + Let's Encrypt 证书，或使用 ngrok/cloudflared 隧道。

```bash
# ngrok 示例
ngrok http 8765
```

然后将 ngrok 给出的 https URL 填入 AI 客户端配置。
