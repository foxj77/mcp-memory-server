FROM node:26-alpine

RUN npm install -g @modelcontextprotocol/server-memory@2026.1.26 supergateway@3.4.3

EXPOSE 3000

# server-memory reads its storage path from MEMORY_FILE_PATH only — argv is ignored.
# Set the default here so operators who run the image without an explicit env var still
# get persistence to the expected /data mount point.
ENV MEMORY_FILE_PATH=/data/memory.jsonl

# --outputTransport streamableHttp  required for MCP streamable HTTP (kagent and most frameworks)
# --stateful                        keeps one persistent stdio child process across HTTP requests
#                                   (stateless mode spawns a new process per request, breaking
#                                    MCP session continuity between initialize and tools/call)
CMD ["supergateway", "--port", "3000", "--outputTransport", "streamableHttp", \
     "--stateful", "--stdio", \
     "npx @modelcontextprotocol/server-memory"]
