#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE="docker-compose.yml"
OUTPUT_DIR=""
PROFILE="community"
TAIL_LINES="300"
COLLECT_LOGS="1"

usage() {
  cat <<'EOF'
Usage: scripts/diagnose.sh [options]

Collect read-only FastGPT deployment diagnostics.

Options:
  --compose-file <path>  Compose file path. Default: docker-compose.yml
  --output <path>        Output directory. Default: diagnostics/<timestamp>
  --profile <name>       Deployment profile: community or commercial. Default: community
  --tail <lines>         Log lines per container. Default: 300
  --no-logs              Skip docker logs collection
  --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --compose-file)
      COMPOSE_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --tail)
      TAIL_LINES="${2:-}"
      shift 2
      ;;
    --no-logs)
      COLLECT_LOGS="0"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${OUTPUT_DIR}" ]]; then
  OUTPUT_DIR="diagnostics/$(date '+%Y-%m-%dT%H-%M-%S')"
fi

mkdir -p \
  "${OUTPUT_DIR}/host" \
  "${OUTPUT_DIR}/docker" \
  "${OUTPUT_DIR}/compose" \
  "${OUTPUT_DIR}/logs" \
  "${OUTPUT_DIR}/checks"

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

capture() {
  local output_file="$1"
  local exit_code=0
  shift

  if ! command_exists "$1"; then
    printf 'command not found: %s\n' "$1" > "${output_file}"
    return 0
  fi

  set +e
  "$@" > "${output_file}" 2>&1
  exit_code=$?
  set -e

  if [[ "${exit_code}" -ne 0 ]]; then
    {
      printf '\n[diagnose] command failed with exit code %s:\n' "${exit_code}"
      printf '%q ' "$@"
      printf '\n'
    } >> "${output_file}"
  fi
}

redact_stream() {
  sed -E \
    -e 's#(Authorization:[[:space:]]*Bearer[[:space:]]+)[^[:space:]]+#\1<redacted:bearer-token>#g' \
    -e 's#sk-[A-Za-z0-9_-]+#sk-<redacted>#g' \
    -e 's#mongodb://([^:@/]+):([^@/]+)@#mongodb://<redacted>:<redacted>@#g' \
    -e 's#redis://([^:@/]+):([^@/]+)@#redis://<redacted>:<redacted>@#g' \
    -e 's#postgres(ql)?://([^:@/]+):([^@/]+)@#postgres\1://<redacted>:<redacted>@#g' \
    -e 's#(ROOT_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:ROOT_KEY>#g' \
    -e 's#(DEFAULT_ROOT_PSW[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:DEFAULT_ROOT_PSW>#g' \
    -e 's#(TOKEN_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:TOKEN_KEY>#g' \
    -e 's#(FILE_TOKEN_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:FILE_TOKEN_KEY>#g' \
    -e 's#(AES256_SECRET_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:AES256_SECRET_KEY>#g' \
    -e 's#(PLUGIN_TOKEN[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:PLUGIN_TOKEN>#g' \
    -e 's#(CODE_SANDBOX_TOKEN[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:CODE_SANDBOX_TOKEN>#g' \
    -e 's#(AIPROXY_API_TOKEN[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:AIPROXY_API_TOKEN>#g' \
    -e 's#(ADMIN_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:ADMIN_KEY>#g' \
    -e 's#(STORAGE_ACCESS_KEY_ID[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:STORAGE_ACCESS_KEY_ID>#g' \
    -e 's#(STORAGE_SECRET_ACCESS_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:STORAGE_SECRET_ACCESS_KEY>#g' \
    -e 's#(MINIO_ROOT_USER[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:MINIO_ROOT_USER>#g' \
    -e 's#(MINIO_ROOT_PASSWORD[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:MINIO_ROOT_PASSWORD>#g' \
    -e 's#(OPENAI_BASE_URL[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:OPENAI_BASE_URL>#g' \
    -e 's#(CHAT_API_KEY[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:CHAT_API_KEY>#g' \
    -e 's#([Ll]icense[[:space:]_A-Za-z-]*[:=][[:space:]]*)[^[:space:]]+#\1<redacted:license>#g'
}

capture_redacted() {
  local output_file="$1"
  local tmp_file="${output_file}.tmp"
  shift

  capture "${tmp_file}" "$@"
  redact_stream < "${tmp_file}" > "${output_file}"
  rm -f "${tmp_file}"
}

capture "${OUTPUT_DIR}/host/date.txt" date
capture "${OUTPUT_DIR}/host/uname.txt" uname -a
capture "${OUTPUT_DIR}/host/cpu.txt" lscpu
capture "${OUTPUT_DIR}/host/disk.txt" df -h
capture "${OUTPUT_DIR}/host/memory.txt" free -h
capture "${OUTPUT_DIR}/host/ports.txt" ss -lntp

capture "${OUTPUT_DIR}/docker/version.txt" docker -v
capture "${OUTPUT_DIR}/docker/compose-version.txt" docker compose version
capture "${OUTPUT_DIR}/docker/compose-legacy-version.txt" docker-compose -v
capture "${OUTPUT_DIR}/docker/ps.txt" docker compose -f "${COMPOSE_FILE}" ps
capture "${OUTPUT_DIR}/docker/ps-all.txt" docker ps -a
capture "${OUTPUT_DIR}/docker/images.txt" docker images
capture "${OUTPUT_DIR}/docker/networks.txt" docker network ls

if [[ -f "${COMPOSE_FILE}" ]]; then
  capture_redacted "${OUTPUT_DIR}/compose/config.redacted.yml" docker compose -f "${COMPOSE_FILE}" config
  grep -n "image:" "${OUTPUT_DIR}/compose/config.redacted.yml" > "${OUTPUT_DIR}/compose/images.txt" 2>/dev/null || true
  grep -nE "STORAGE_|FE_DOMAIN|FILE_DOMAIN|PRO_URL|PLUGIN_BASE_URL|AIPROXY_API_ENDPOINT" \
    "${OUTPUT_DIR}/compose/config.redacted.yml" > "${OUTPUT_DIR}/compose/important-env.redacted.txt" 2>/dev/null || true
else
  printf 'compose file not found: %s\n' "${COMPOSE_FILE}" > "${OUTPUT_DIR}/compose/config.redacted.yml"
  : > "${OUTPUT_DIR}/compose/images.txt"
  : > "${OUTPUT_DIR}/compose/important-env.redacted.txt"
fi

containers=(
  mongo
  fastgpt-pg
  fastgpt-redis
  fastgpt-minio
  fastgpt-app
  fastgpt-pro
  fastgpt-plugin
  fastgpt-code-sandbox
  fastgpt-mcp-server
  fastgpt-aiproxy
  fastgpt-opensandbox-server
)

if [[ "${COLLECT_LOGS}" == "1" ]]; then
  for container in "${containers[@]}"; do
    capture_redacted "${OUTPUT_DIR}/logs/${container}.log" docker logs "${container}" --tail "${TAIL_LINES}"
  done
else
  printf 'log collection skipped by --no-logs\n' > "${OUTPUT_DIR}/logs/README.txt"
fi

cat > "${OUTPUT_DIR}/checks/storage.md" <<EOF
# 对象存储检查

本版本只收集配置和日志，不主动请求业务对象。

人工检查：

- FastGPT 容器能否访问 \`STORAGE_S3_ENDPOINT\`。
- 用户浏览器能否访问 \`STORAGE_EXTERNAL_ENDPOINT\`。
- 反向代理是否保留带端口的 \`Host\`。
EOF

cat > "${OUTPUT_DIR}/checks/external-access.md" <<EOF
# 外部访问检查

本版本不主动扫描端口。

人工检查：

- FastGPT 主服务端口。
- 商业版 Pro/Admin 端口。
- MinIO/S3 endpoint。
- MCP server 端口。
EOF

cat > "${OUTPUT_DIR}/checks/model-path.md" <<EOF
# 模型链路检查

本版本不调用模型 API。

人工检查顺序：

1. 直接测试上游模型 endpoint。
2. 通过 OneAPI 或 AIProxy 测试。
3. 在 FastGPT 中测试。
4. 对比 FastGPT 日志中的请求和响应。
EOF

cat > "${OUTPUT_DIR}/summary.md" <<EOF
# FastGPT 诊断摘要

profile: ${PROFILE}
compose_file: ${COMPOSE_FILE}
output_dir: ${OUTPUT_DIR}
tail_lines: ${TAIL_LINES}
logs_collected: ${COLLECT_LOGS}

## L0 服务器基础环境

status: unknown

evidence:

- \`host/date.txt\`
- \`host/uname.txt\`
- \`host/cpu.txt\`
- \`host/disk.txt\`
- \`host/memory.txt\`
- \`host/ports.txt\`

## L1 镜像与离线包完整性

status: unknown

evidence:

- \`docker/images.txt\`
- \`compose/config.redacted.yml\`
- \`compose/images.txt\`

## L2 基础服务

status: unknown

evidence:

- \`docker/ps.txt\`
- \`logs/mongo.log\`
- \`logs/fastgpt-pg.log\`
- \`logs/fastgpt-redis.log\`
- \`logs/fastgpt-minio.log\`

## L3 FastGPT 服务层

status: unknown

evidence:

- \`logs/fastgpt-app.log\`
- \`logs/fastgpt-pro.log\`
- \`logs/fastgpt-plugin.log\`
- \`logs/fastgpt-code-sandbox.log\`
- \`logs/fastgpt-mcp-server.log\`
- \`logs/fastgpt-aiproxy.log\`

## L4 外部访问与反向代理

status: unknown

evidence:

- \`host/ports.txt\`
- \`checks/external-access.md\`
- \`checks/storage.md\`

## L5 业务配置

status: unknown

evidence:

- \`compose/important-env.redacted.txt\`
- \`checks/model-path.md\`

## L6 升级与回滚

status: unknown

evidence:

- \`docker/images.txt\`
- \`compose/images.txt\`

## 下一步

- 先查看 \`docker/ps.txt\` 判断容器是否运行。
- 如果基础服务异常，优先查看 L2 日志。
- 如果商业版后台异常，优先查看 \`logs/fastgpt-pro.log\` 和 \`compose/important-env.redacted.txt\`。
- 如果文件或图片不可访问，优先查看 \`checks/storage.md\` 和对象存储相关配置。
EOF

printf 'Diagnostics written to %s\n' "${OUTPUT_DIR}"
