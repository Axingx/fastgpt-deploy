# FastGPT 升级后数据卷恢复 Runbook

这份 runbook 适用于 FastGPT Docker Compose 升级后，持久化挂载从宿主机目录变为 Docker named volume，导致页面看起来像“数据丢失”的场景。

典型变化：

```yaml
# 旧版
volumes:
  - ./pg/data:/var/lib/postgresql/data
  - ./mongo/data:/data/db
  - ./fastgpt-minio:/data

# 新版
volumes:
  - fastgpt-pg:/var/lib/postgresql/data
  - fastgpt-mongo:/data/db
  - fastgpt-minio:/data
```

注意：`fastgpt-volume-manager` 是新版用于管理沙箱或会话类 Docker volume 的服务，不负责迁移 PostgreSQL、MongoDB 或 MinIO 历史数据。

## 1. 安全边界

不要执行：

```bash
docker compose down -v
docker-compose down -v
```

`-v` 会删除 named volume。恢复时只停止容器，不删除 volume。

先进入 compose 所在目录：

```bash
cd /path/to/fastgpt
COMPOSE_FILE=docker-compose.pg.yml
```

如果环境只支持旧命令，后续把 `docker compose` 替换成 `docker-compose`。

## 2. 停止服务

恢复数据前，先停止 FastGPT 业务服务和数据库服务，避免复制过程中有写入。

```bash
docker-compose -f "$COMPOSE_FILE" stop
```

## 3. 恢复 PostgreSQL 向量数据

确认旧 PG 数据目录存在：

```bash
du -sh ./pg/data
ls -la ./pg/data | head
test -f ./pg/data/PG_VERSION && cat ./pg/data/PG_VERSION
```

获取新版容器实际挂载的 PG volume 名称：

```bash
PG_VOL=$(docker inspect fastgpt-pg --format '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}')
echo "PG_VOL=$PG_VOL"
test -n "$PG_VOL"
```

清空新 volume 并复制旧数据：

```bash
docker run --rm \
  -v "$PWD/pg/data":/from:ro \
  -v "$PG_VOL":/to \
  registry.cn-hangzhou.aliyuncs.com/fastgpt/pgvector:0.8.0-pg15 \
  sh -c 'rm -rf /to/* /to/.[!.]* /to/..?* 2>/dev/null || true; cp -a /from/. /to/'
```

验证 volume 里有 PG 数据：

```bash
docker run --rm -v "$PG_VOL":/data registry.cn-hangzhou.aliyuncs.com/fastgpt/pgvector:0.8.0-pg15 \
  sh -c 'ls -la /data | head; echo "PG_VERSION=$(cat /data/PG_VERSION)"'
```

启动 PG 并验证：

```bash
docker-compose -f "$COMPOSE_FILE" up -d fastgpt-vector

docker logs --tail=100 fastgpt-pg
docker exec fastgpt-pg pg_isready -U username -d postgres
docker exec fastgpt-pg psql -U username -d postgres -c '\dt+'
docker exec fastgpt-pg psql -U username -d postgres -c 'select count(*) from public.modeldata;'
```

如果 `modeldata` 有行数，说明 PG 向量数据已经恢复。示例中恢复后 `public.modeldata` 有 3 万多条向量。

## 4. 恢复 MongoDB 数据

确认旧 Mongo 数据目录存在：

```bash
du -sh ./mongo/data
ls -la ./mongo/data | head
test -f ./mongo/data/WiredTiger && echo "MongoDB data dir looks valid"
```

获取新版容器实际挂载的 Mongo volume 名称：

```bash
MONGO_VOL=$(docker inspect fastgpt-mongo --format '{{range .Mounts}}{{if eq .Destination "/data/db"}}{{.Name}}{{end}}{{end}}')
echo "MONGO_VOL=$MONGO_VOL"
test -n "$MONGO_VOL"
```

清空新 volume 并复制旧数据：

```bash
docker run --rm \
  -v "$PWD/mongo/data":/from:ro \
  -v "$MONGO_VOL":/to \
  registry.cn-hangzhou.aliyuncs.com/fastgpt/mongo:5.0.32 \
  sh -c 'rm -rf /to/* /to/.[!.]* /to/..?* 2>/dev/null || true; cp -a /from/. /to/'
```

验证 volume 里有 Mongo 数据：

```bash
docker run --rm -v "$MONGO_VOL":/data registry.cn-hangzhou.aliyuncs.com/fastgpt/mongo:5.0.32 \
  sh -c 'ls -la /data | head; test -f /data/WiredTiger && echo "MongoDB WiredTiger exists"'
```

启动 Mongo：

```bash
docker-compose -f "$COMPOSE_FILE" up -d fastgpt-mongo
docker logs --tail=100 fastgpt-mongo
```

验证 Mongo 可连接：

```bash
docker exec fastgpt-mongo mongo \
  -u myusername \
  -p mypassword \
  --authenticationDatabase admin \
  --eval 'db.adminCommand("ping")'
```

## 5. 修复 Mongo replica set 主机名

如果旧数据里 replica set 成员是旧服务名，例如 `mongo:27017`，但新版 compose 服务名是 `fastgpt-mongo`，Mongo 会进入 `REMOVED` 状态。

典型日志：

```text
HostNotFound: Could not find address for mongo:27017
No host described in new configuration
Replica set state transition: REMOVED
not master and slaveOk=false
```

先停止依赖 Mongo 的业务服务，只保留 Mongo 运行：

```bash
docker-compose -f "$COMPOSE_FILE" stop fastgpt-app fastgpt-plugin
docker-compose -f "$COMPOSE_FILE" up -d fastgpt-mongo
```

查看当前副本集配置：

```bash
docker exec fastgpt-mongo mongo \
  -u myusername \
  -p mypassword \
  --authenticationDatabase admin \
  --eval 'rs.conf()'
```

如果看到 `host: "mongo:27017"`，执行 reconfig：

```bash
docker exec fastgpt-mongo mongo \
  -u myusername \
  -p mypassword \
  --authenticationDatabase admin \
  --eval '
cfg = rs.conf();
cfg.members[0].host = "fastgpt-mongo:27017";
cfg.version = cfg.version + 1;
printjson(rs.reconfig(cfg, { force: true }));
'
```

等待并验证 PRIMARY：

```bash
sleep 10

docker exec fastgpt-mongo mongo \
  -u myusername \
  -p mypassword \
  --authenticationDatabase admin \
  --eval 'rs.status().myState; rs.isMaster().ismaster; rs.conf().members'
```

正常应看到：

```text
1
true
fastgpt-mongo:27017
```

验证知识库元数据：

```bash
docker exec fastgpt-mongo mongo \
  -u myusername \
  -p mypassword \
  --authenticationDatabase admin \
  fastgpt \
  --eval '
db.getCollectionNames()
  .filter(c => /dataset|team|user|collection|data/i.test(c))
  .forEach(c => print(c + ": " + db.getCollection(c).count()))
'
```

## 6. 恢复 MinIO 对象数据

如果 PG 和 Mongo 都有数据，但打开知识库文件详情时报 S3 或 MinIO 404，通常是 MinIO 对象数据没有恢复。

典型 app 日志：

```text
url: /api/core/dataset/collection/detail?id=...
error: NotFound: Unknown
at async getObjectMetadata
httpStatusCode: 404
```

本项目遇到的历史 MinIO 目录是：

```text
./fastgpt-minio/
```

新版 compose 使用：

```yaml
fastgpt-minio:
  volumes:
    - fastgpt-minio:/data
```

获取新版 MinIO volume 名称：

```bash
MINIO_VOL=$(docker inspect fastgpt-minio --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Name}}{{end}}{{end}}')
echo "MINIO_VOL=$MINIO_VOL"
test -n "$MINIO_VOL"
```

确认旧 MinIO 数据目录存在：

```bash
du -sh ./fastgpt-minio
ls -la ./fastgpt-minio | head
find ./fastgpt-minio -maxdepth 2 -type d | head -50
```

查看当前 named volume：

```bash
docker run --rm -v "$MINIO_VOL":/data alpine \
  sh -c 'du -sh /data; find /data -maxdepth 2 -type d | head -50'
```

停止依赖 MinIO 的服务：

```bash
docker-compose -f "$COMPOSE_FILE" stop fastgpt-app fastgpt-plugin fastgpt-minio
```

把旧 MinIO 数据复制到 named volume。这里使用合并复制，不清空目标，避免误删新版已创建的 bucket 或元数据。

```bash
docker run --rm \
  -v "$PWD/fastgpt-minio":/from:ro \
  -v "$MINIO_VOL":/to \
  alpine sh -c 'cp -a /from/. /to/'
```

启动并验证：

```bash
docker-compose -f "$COMPOSE_FILE" up -d fastgpt-minio
sleep 10

docker-compose -f "$COMPOSE_FILE" up -d fastgpt-app fastgpt-plugin

docker logs --tail=100 fastgpt-minio
docker logs --tail=200 fastgpt-app | grep -iE "s3|storage|minio|NotFound|error"
```

如果 404 消失，知识库文件详情、PDF 预览和切片详情恢复，说明 MinIO 数据恢复成功。

## 7. 最终启动和验收

启动全部服务：

```bash
docker-compose -f "$COMPOSE_FILE" up -d
docker-compose -f "$COMPOSE_FILE" ps
```

检查 app 和 plugin：

```bash
docker logs --tail=100 fastgpt-app
docker logs --tail=100 fastgpt-plugin
```

检查 app 是否连接到数据库和向量库：

```bash
docker logs --tail=200 fastgpt-app | grep -iE "MongoDB connected|Postgres pool connected|Postgres vector initialization completed|error|fail"
```

业务验收：

- 能登录原账号或预期 root 账号。
- 知识库列表存在。
- 知识库集合和切片文本存在。
- 文件详情和预览不再出现对象存储 404。
- 知识库检索或对话能命中历史内容。

## 8. 快速判断表

| 现象 | 优先判断 | 常用验证 |
| --- | --- | --- |
| Mongo ping 正常，但查集合报 `not master and slaveOk=false` | replica set host 仍是旧服务名 | `rs.conf()`、`rs.status().myState` |
| plugin 报 Mongoose buffering timeout | Mongo 不可用或不是 PRIMARY | `docker logs fastgpt-mongo`、`rs.status()` |
| PG 有 `modeldata` 且 `count(*) > 0` | PG 向量数据已恢复 | `select count(*) from public.modeldata;` |
| 页面看不到文件详情，app 日志 `getObjectMetadata` 404 | MinIO 对象数据缺失 | 查 `./fastgpt-minio` 和 `fastgpt-minio` named volume |
| 知识库元数据存在但检索异常 | 再查模型配置、向量模型、队列和版本升级脚本 | app 日志和官方升级说明 |

## 9. 版本风险

PostgreSQL 和 MongoDB 不建议跨主版本直接复制数据目录。

- PG 数据目录里的 `PG_VERSION` 必须和目标镜像主版本一致。
- MongoDB 要遵循官方兼容升级路径，避免跨大版本直接复用数据文件。
- 如果主版本不一致，优先使用 dump/restore 或官方升级工具，不要直接 `cp -a` 数据目录。
