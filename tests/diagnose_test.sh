#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
WORK_DIR="${TMP_DIR}/work"
OUT_DIR="${TMP_DIR}/diagnostics"
mkdir -p "${FAKE_BIN}" "${WORK_DIR}"

cat > "${WORK_DIR}/docker-compose.yml" <<'YAML'
services:
  fastgpt-app:
    image: registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt:v4.14.24
YAML

cat > "${FAKE_BIN}/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-v" ]]; then
  echo "Docker version 27.0.0, build test"
  exit 0
fi

if [[ "${1:-}" == "compose" ]]; then
  shift
  if [[ "${1:-}" == "version" ]]; then
    echo "Docker Compose version v2.40.3"
    exit 0
  fi

  compose_file=""
  if [[ "${1:-}" == "-f" ]]; then
    compose_file="${2:-}"
    shift 2
  fi

  case "${1:-}" in
    ps)
      echo "NAME                  STATUS"
      echo "fastgpt-app           running"
      echo "fastgpt-pro           running"
      ;;
    config)
      cat <<'YAML'
services:
  fastgpt-app:
    environment:
      ROOT_KEY: real-root-key
      DEFAULT_ROOT_PSW: real-root-password
      MONGODB_URI: mongodb://myusername:mypassword@mongo:27017/fastgpt?authSource=admin
      STORAGE_SECRET_ACCESS_KEY: minio-secret
      OPENAI_BASE_URL: https://api.example.com/v1
YAML
      ;;
    *)
      echo "unexpected docker compose command: ${compose_file} $*" >&2
      exit 2
      ;;
  esac
  exit 0
fi

case "${1:-}" in
  ps)
    echo "CONTAINER ID   NAMES          STATUS"
    echo "abc123         fastgpt-app    Up 2 minutes"
    ;;
  images)
    echo "REPOSITORY                                             TAG"
    echo "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt     v4.14.24"
    ;;
  network)
    if [[ "${2:-}" == "ls" ]]; then
      echo "NETWORK ID   NAME"
      echo "net123       fastgpt"
    else
      echo "unexpected docker network command: $*" >&2
      exit 2
    fi
    ;;
  logs)
    container="${2:-}"
    echo "${container} started"
    echo "Authorization: Bearer secret-bearer-token"
    echo "model key sk-testsecret123"
    ;;
  *)
    echo "unexpected docker command: $*" >&2
    exit 2
    ;;
esac
SH

cat > "${FAKE_BIN}/docker-compose" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-v" ]]; then
  echo "docker-compose version 1.29.2"
  exit 0
fi

echo "unexpected docker-compose command: $*" >&2
exit 2
SH

chmod +x "${FAKE_BIN}/docker" "${FAKE_BIN}/docker-compose"

PATH="${FAKE_BIN}:${PATH}" "${ROOT_DIR}/scripts/diagnose.sh" \
  --compose-file "${WORK_DIR}/docker-compose.yml" \
  --output "${OUT_DIR}" \
  --profile commercial \
  --tail 25

test -f "${OUT_DIR}/summary.md"
test -f "${OUT_DIR}/host/date.txt"
test -f "${OUT_DIR}/docker/version.txt"
test -f "${OUT_DIR}/docker/ps.txt"
test -f "${OUT_DIR}/compose/config.redacted.yml"
test -f "${OUT_DIR}/logs/fastgpt-app.log"
test -f "${OUT_DIR}/logs/fastgpt-pro.log"

grep -q "profile: commercial" "${OUT_DIR}/summary.md"
grep -q "compose_file: ${WORK_DIR}/docker-compose.yml" "${OUT_DIR}/summary.md"
grep -q "<redacted:ROOT_KEY>" "${OUT_DIR}/compose/config.redacted.yml"
grep -q "<redacted:DEFAULT_ROOT_PSW>" "${OUT_DIR}/compose/config.redacted.yml"
grep -q "mongodb://<redacted>:<redacted>@mongo:27017/fastgpt?authSource=admin" "${OUT_DIR}/compose/config.redacted.yml"
grep -q "<redacted:STORAGE_SECRET_ACCESS_KEY>" "${OUT_DIR}/compose/config.redacted.yml"
grep -q "Authorization: Bearer <redacted:bearer-token>" "${OUT_DIR}/logs/fastgpt-app.log"
grep -q "sk-<redacted>" "${OUT_DIR}/logs/fastgpt-app.log"

if grep -R "real-root-key\|real-root-password\|mypassword\|minio-secret\|secret-bearer-token\|sk-testsecret123" "${OUT_DIR}" >/dev/null; then
  echo "diagnostic output contains unredacted secrets" >&2
  exit 1
fi
