FROM node:26-alpine

RUN npm install -g @modelcontextprotocol/server-memory@2026.1.26 supergateway@3.4.3

EXPOSE 3000

# --outputTransport streamableHttp  required for MCP streamable HTTP (kagent and most frameworks)
# --stateful                        keeps one persistent stdio child process across HTTP requests
#                                   (stateless mode spawns a new process per request, breaking
#                                    MCP session continuity between initialize and tools/call)
# /data/memory.jsonl                knowledge graph persisted to a mounted volume
CMD ["supergateway", "--port", "3000", "--outputTransport", "streamableHttp", \
     "--stateful", "--stdio", \
     "npx @modelcontextprotocol/server-memory /data/memory.jsonl"]
