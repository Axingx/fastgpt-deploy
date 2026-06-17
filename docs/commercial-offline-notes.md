# Commercial Offline Deployment Notes

These notes summarize the local commercial PDF and attachment scripts provided by the user. They are not a replacement for the official commercial deployment guide.

## Source Material Reviewed

- Local PDF: `/Users/axing/Downloads/FastGPT商业版命令行部署教程.pdf`
- Local legacy script: `/Users/axing/Downloads/docker-pull-commands.sh`
- Local legacy script: `/Users/axing/Downloads/docker-save-commands.sh`

The PDF itself is not committed because this repository is intended to be public.

## Commercial Edition Differences

The commercial deployment adds a `fastgpt-pro` service alongside the main `fastgpt-app` service.

Important shared settings:

- MongoDB connection.
- PostgreSQL or vector database connection.
- Redis connection.
- Object storage settings.
- Plugin URL and token.
- Code sandbox URL and token.
- AIProxy endpoint and token.
- File token and encryption-related keys.
- External domain settings such as `FE_DOMAIN` and `FILE_DOMAIN`.

Important commercial-only concerns:

- `PRO_URL` must point from `fastgpt-app` to the Pro service.
- Commercial admin access needs to be verified separately from the main FastGPT UI.
- First deployment requires License activation.
- License signing depends on the current domain, so the deployment domain should be confirmed before requesting the License.

## Offline Delivery Model

Current business reality:

1. Build or export the Docker image package on a local computer.
2. Upload the package through the customer-provided upload tool.
3. Load images on the customer server.
4. Start services on the customer server.
5. Run acceptance checks.

Implications:

- Customer startup must not rely on pulling images from the public internet.
- The package must include a manifest and checksums.
- The package must include load and healthcheck steps.
- Version tags must be locked per package.

## Legacy Script Findings

The downloaded `docker-pull-commands.sh` and `docker-save-commands.sh` default to:

- `TAG=v4.14.4`
- `pluginTag=v0.3.4`
- `aiproxy:v0.2.2`
- `fastgpt-sandbox:${TAG}`

The commercial PDF compose example points to newer and different services, including:

- `fastgpt:v4.14.24`
- `fastgpt-pro:v4.14.24`
- `fastgpt-plugin:v0.6.0`
- `fastgpt-code-sandbox:v4.14.12`
- `fastgpt-mcp_server:v4.14.12`
- OpenSandbox related images
- volume manager
- `aiproxy:v0.6.0`

Conclusion:

- Keep the downloaded scripts only as legacy references.
- Future scripts must read a versioned image manifest.
- Do not assume every component uses the same FastGPT version tag.

## Commercial Offline Acceptance Checks

Minimum checks after deployment:

- Main UI opens.
- Pro/Admin UI opens.
- Root login works.
- License activation page or status behaves as expected.
- MinIO/S3 endpoint is reachable from the user's browser.
- Knowledge base file upload works.
- Knowledge base indexing starts.
- A configured chat model can respond.
- A configured vector model can index.
- Plugin runtime is healthy.
- Code sandbox is healthy if workflows require it.
- AIProxy can call at least one configured model provider.

## Questions To Resolve Before Automation

- Which commercial version should be the first supported baseline?
- Should customer packages include plugin `.pkg` files for fully offline installation?
- Should MinIO be exposed directly, proxied through Nginx, or replaced with customer-provided object storage?
- Should the package support both `docker compose` and legacy `docker-compose` command styles?
- What evidence should be required before running destructive recovery commands such as network pruning?
