#!/usr/bin/env bash
set -euo pipefail

TAG="${TAG:-v4.14.4}"
pluginTag="${pluginTag:-v0.3.4}"

echo "Saving FastGPT related images to tar files..."
mkdir -p images

echo "Saving pgvector image..."
docker save "pgvector/pgvector:0.8.0-pg15" -o "images/pgvector-v0.8.0-pg15.tar"

echo "Saving MongoDB image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/mongo:5.0.18" -o "images/mongo-5.0.18.tar"

echo "Saving Redis image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/redis:7.2-alpine" -o "images/redis-7.2-alpine.tar"

echo "Saving FastGPT Sandbox image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-sandbox:${TAG}" -o "images/fastgpt-sandbox-${TAG}.tar"

echo "Saving FastGPT main image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt:${TAG}" -o "images/fastgpt-${TAG}.tar"

echo "Saving FastGPT Pro image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-pro:${TAG}" -o "images/fastgpt-pro-${TAG}.tar"

echo "Saving FastGPT MCP Server image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-mcp_server:${TAG}" -o "images/fastgpt-mcp_server-${TAG}.tar"

echo "Saving FastGPT Plugin image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/fastgpt-plugin:${pluginTag}" -o "images/fastgpt-plugin-${pluginTag}.tar"

echo "Saving MinIO image..."
docker save "registry.cn-hangzhou.aliyuncs.com/fastgpt/minio:RELEASE.2025-09-07T16-13-09Z" -o "images/minio-RELEASE.2025-09-07T16-13-09Z.tar"

echo "Saving AI Proxy image..."
docker save "registry.cn-hangzhou.aliyuncs.com/labring/aiproxy:v0.2.2" -o "images/aiproxy-v0.2.2.tar"

echo "All images saved to images directory!"
echo "File list:"
ls -lh images/*.tar 2>/dev/null || true
