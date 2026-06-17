# FastGPT Deployment Risk Map

This document turns FastGPT deployment and upgrade pain points into diagnosis layers. It is intentionally source-driven: official FastGPT docs and commercial deployment notes should be checked before automation is written.

## L0: Host Environment

Risks:

- Docker or Docker Compose is missing, too old, or installed under a different command name.
- CPU does not support required instructions for selected images.
- Disk space is insufficient for databases, MinIO objects, Docker layers, and offline image tar files.
- Required ports are blocked by firewall, security group, or an existing service.

Evidence to collect:

```bash
docker -v
docker compose version
docker-compose -v
uname -a
lscpu
df -h
free -h
ss -lntp
```

Known checks:

- FastGPT official Docker docs recommend Docker Compose 2.17 or newer for the automated compose commands.
- Mongo 5 may fail on older CPUs that do not support AVX; Mongo 4.x is the fallback mentioned in official docs and the commercial PDF.
- Newer MinIO images may fail on old CPUs with `CPU does not support x86-64-v2`; the commercial PDF notes an older MinIO image as a workaround.

## L1: Image And Offline Package Integrity

Risks:

- The offline package misses one or more images referenced by `docker-compose.yml`.
- Image tags in pull/save scripts drift from compose.
- Main FastGPT tag is updated but plugin, code sandbox, MCP, OpenSandbox, or AIProxy tags are not updated.
- Customer server cannot access the public registry, but compose still requires pulling missing images.

Evidence to collect:

```bash
docker images
docker compose config
grep -R "image:" docker-compose.yml
```

Rules:

- Maintain an explicit image list for each FastGPT version and deployment flavor.
- Treat provided legacy `docker-pull-commands.sh` and `docker-save-commands.sh` as source samples, not current truth.
- Future scripts should read one image manifest instead of hard-coding image tags in multiple places.

## L2: Foundation Services

Risks:

- Mongo fails to start, replica set is not initialized, or credentials do not match `MONGODB_URI`.
- PostgreSQL or pgvector fails to initialize.
- Redis password or maxmemory settings break service startup.
- MinIO starts but buckets or endpoints are not reachable.

Evidence to collect:

```bash
docker compose ps
docker logs mongo --tail 200
docker logs fastgpt-pg --tail 200
docker logs fastgpt-redis --tail 200
docker logs fastgpt-minio --tail 200
```

Known symptoms:

- `Illegal instruction` in Mongo usually points to CPU instruction mismatch.
- `Operation auth_codes.findOne() buffering timed out after 10000ms` usually means Mongo is unreachable, credentials are wrong, or replica set startup failed.
- `relation "modeldata" does not exist` points to PostgreSQL connection or initialization failure.

## L3: FastGPT Service Layer

Risks:

- `fastgpt-app`, `fastgpt-pro`, plugin, code sandbox, MCP server, OpenSandbox, or AIProxy fail independently.
- Commercial `fastgpt-pro` settings drift from main `fastgpt-app` settings.
- `PRO_URL`, `PLUGIN_BASE_URL`, `CODE_SANDBOX_URL`, or AIProxy values are wrong.
- OpenSandbox dynamic containers remain attached to networks and block cleanup.

Evidence to collect:

```bash
docker logs fastgpt-app --tail 300
docker logs fastgpt-pro --tail 300
docker logs fastgpt-plugin --tail 300
docker logs fastgpt-code-sandbox --tail 300
docker logs fastgpt-opensandbox-server --tail 300
docker network ls
docker network inspect fastgpt_opensandbox
```

Known checks:

- Commercial deployments must keep `fastgpt-app` and `fastgpt-pro` storage, token, and domain settings aligned where the product expects shared behavior.
- Network cleanup should not be part of the default happy path; it belongs in documented recovery steps after confirming the dynamic sandbox containers are stale.

## L4: External Access And Reverse Proxy

Risks:

- Required ports are not exposed to users.
- Nginx or another reverse proxy strips required headers.
- Client IP headers can be spoofed when FastGPT is behind a proxy.
- `FE_DOMAIN`, `FILE_DOMAIN`, or `STORAGE_EXTERNAL_ENDPOINT` are empty or unreachable from the client.

Evidence to collect:

```bash
curl -I http://<host>:3000
curl -I http://<host>:3002
curl -I http://<host>:9000
curl -I http://<host>:3005
```

Known checks:

- Official docs require FastGPT main service, S3 service, and MCP service ports to be reachable for normal Docker deployment.
- Official S3 troubleshooting says signature mismatch is commonly caused by Nginx not passing the right host header; for MinIO/S3 proxying, preserve the host including port.
- If reverse proxying FastGPT, configure trusted proxy settings carefully and do not trust arbitrary client-supplied `X-Forwarded-For`.

## L5: Product Configuration

Risks:

- Root user cannot login because Mongo or config initialization failed.
- Models are not configured, so chat or indexing fails.
- Plugin market access is unavailable in an offline deployment.
- Commercial License domain does not match the deployed access domain.
- Browser page crashes due to invalid model or config object shapes.

Evidence to collect:

```bash
docker logs fastgpt-app --tail 300
docker logs fastgpt-pro --tail 300
```

Known checks:

- Official docs say FastGPT requires at least one language model and one index model.
- From FastGPT v4.14.0, `fastgpt-plugin` is a runtime image and system plugins are installed separately.
- In offline commercial deployments, plugin packages may need to be imported manually instead of fetched from the public marketplace.

## L6: Upgrade And Rollback

Risks:

- Only image tags are changed, but required upgrade initialization scripts are skipped.
- Multiple versions are skipped without running intermediate scripts.
- No backup exists before schema or data migrations.
- New image tags are pulled on the customer server by accident instead of being loaded from the approved offline package.

Evidence to collect:

```bash
docker compose config
docker images
docker compose ps
```

Rules:

- Upgrade runbooks must list image tag changes and required initialization scripts separately.
- Official upgrade docs say FastGPT upgrades usually include changing images and executing upgrade initialization scripts.
- Before cross-version upgrades, back up data and prefer stepping through version-specific upgrade notes.
