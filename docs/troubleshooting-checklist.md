# Troubleshooting Checklist

Use this checklist before writing or running automation. It is organized as a practical operator flow.

## 1. Confirm Scope

- Deployment type: community or commercial.
- Deployment mode: online or offline.
- Vector database: PgVector, Milvus, Zilliz, OceanBase, or SeekDB.
- FastGPT version and image source.
- Whether the issue is install, startup, access, model, storage, plugin, sandbox, or upgrade.

## 2. Collect Basic Evidence

```bash
date
docker -v
docker compose version
docker-compose -v
docker compose ps
docker ps -a
docker images
df -h
free -h
```

Save the output before changing anything.

## 3. Check Compose Consistency

```bash
docker compose config
grep -n "image:" docker-compose.yml
grep -n "STORAGE_EXTERNAL_ENDPOINT\|FE_DOMAIN\|FILE_DOMAIN\|PRO_URL\|PLUGIN_BASE_URL\|AIPROXY_API_ENDPOINT" docker-compose.yml
```

Look for:

- Missing images in offline packages.
- Unexpected latest tags.
- Loopback addresses such as `localhost` or `127.0.0.1` where clients or containers need a reachable host.
- Commercial `fastgpt-pro` settings that do not match `fastgpt-app` where they should.

## 4. Check Foundation Services

```bash
docker logs mongo --tail 200
docker logs fastgpt-pg --tail 200
docker logs fastgpt-redis --tail 200
docker logs fastgpt-minio --tail 200
```

Common diagnosis:

- Mongo `Illegal instruction`: CPU cannot run the selected Mongo image.
- Mongo buffering timeout from FastGPT: Mongo is unavailable, credentials are wrong, or replica set did not initialize.
- PostgreSQL `relation "modeldata" does not exist`: PG connection or initialization failed.
- MinIO/S3 bucket errors: check endpoint, path-style mode, credentials, and reverse proxy host headers.

## 5. Check FastGPT Services

```bash
docker logs fastgpt-app --tail 300
docker logs fastgpt-pro --tail 300
docker logs fastgpt-plugin --tail 300
docker logs fastgpt-code-sandbox --tail 300
docker logs fastgpt-mcp-server --tail 200
docker logs fastgpt-aiproxy --tail 200
```

Look for:

- Invalid JSON config errors.
- Database connection errors.
- Model provider errors.
- Plugin or sandbox healthcheck failures.
- Commercial License or domain mismatch hints.

## 6. Check Object Storage From Both Sides

Operator questions:

- Can the FastGPT containers reach `STORAGE_S3_ENDPOINT`?
- Can the user's browser reach `STORAGE_EXTERNAL_ENDPOINT`?
- Does Nginx preserve the `Host` header with port when proxying MinIO/S3?
- Are public and private bucket names correct and distinct unless policy has been deliberately designed?

Useful commands:

```bash
curl -I <STORAGE_EXTERNAL_ENDPOINT>
docker exec fastgpt-app env | grep STORAGE_
docker exec fastgpt-pro env | grep STORAGE_
```

## 7. Check External Access

```bash
curl -I http://<host>:3000
curl -I http://<host>:3002
curl -I http://<host>:3005
curl -I http://<host>:9000
```

Commercial deployments usually care about:

- `3000`: FastGPT main service.
- `3002`: FastGPT Pro/Admin service, based on the commercial PDF compose example.
- `3005` or configured MCP mapping: MCP server if exposed.
- `9000`: MinIO/S3 endpoint used by clients.

Always confirm actual ports from the active `docker-compose.yml`; do not trust old notes blindly.

## 8. Check Model Path

Follow the official order:

1. Test the upstream model endpoint directly with curl.
2. Test through OneAPI or AIProxy.
3. Test inside FastGPT.
4. Check FastGPT logs for the actual request body when available.

Common diagnosis:

- Indexing has no progress: vector model is missing or disabled.
- Chat works but API test fails: compare streaming vs non-streaming mode.
- Tool workflows fail: verify both the model provider and proxy support tool calls.
- Domestic server reports connection errors to overseas APIs: use reachable proxy or local model service.

## 9. Upgrade-Specific Checks

Before upgrade:

- Back up Mongo, PostgreSQL, Redis if needed, MinIO data, and compose/config files.
- Record current image list.
- Read the official version notes for every version being crossed.

During upgrade:

- Change image tags deliberately.
- Load offline images before `docker compose up -d`.
- Run required initialization scripts separately and record output.

After upgrade:

- Verify containers are running.
- Verify login, model configuration, knowledge base upload, plugin usage, and commercial admin access.

## 10. Evidence Package For Support

When escalation is needed, prepare:

- FastGPT version and deployment type.
- Sanitized `docker-compose.yml`.
- Sanitized `config.json`.
- `docker compose ps`.
- Logs for the failing containers.
- Screenshots or browser console errors for frontend crashes.
- Reproduction steps.
