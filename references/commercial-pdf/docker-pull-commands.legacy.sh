#!/usr/bin/env bash
set -euo pipefail

PLATFORM="${PLATFORM:-linux/amd64}"
TAG="${TAG:-v4.14.4}"
pluginTag="${pluginTag:-v0.3.4}"

echo "Pulling FastGPT related images for platform: ${PLATFORM}"

docker pull --platform "${PLATFORM}" "pgvector/pgvector:0.8.0-pg15"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/mongo:5.0.18"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/redis:7.2-alpine"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-sandbox:${TAG}"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt:${TAG}"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-pro:${TAG}"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-mcp_server:${TAG}"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-plugin:${pluginTag}"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/fastgpt/minio:RELEASE.2025-09-07T16-13-09Z"
docker pull --platform "${PLATFORM}" "registry.cn-hangzhou.aliyuncs.com/labring/aiproxy:v0.2.2"

echo "All images pulled successfully for platform: ${PLATFORM}"
