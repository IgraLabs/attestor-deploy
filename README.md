# Deploy Attestor with igra-orchestra

Run the attestor alongside an igra-orchestra node. The attestor connects to the local `rpc-provider` service via the shared Docker network.

## Prerequisites

- Docker and Docker Compose installed
- igra-orchestra running with the backend and frontend-w1 profiles:
  ```bash
  # In your igra-orchestra directory
  docker compose --profile backend --profile frontend-w1 up -d
  ```

## Setup

```bash
cd deploy
./setup.sh testnet   # or: ./setup.sh mainnet
```

The script will:

1. Create `.env` from the network-specific template
2. Verify the igra-orchestra Docker network is running
3. Prompt for your attester private key (stored in `secrets/private_key.txt`)
4. Start the attestor container

## Management

```bash
docker compose logs -f              # Follow logs
curl -s localhost:8180 | jq          # Health status
curl -s localhost:9190 | jq          # Metrics
curl -s localhost:9190/prometheus    # Prometheus metrics
docker compose down                 # Stop attestor
```

## Configuration

Edit `.env` after setup to change optional settings:

| Variable              | Default                 | Description                     |
| --------------------- | ----------------------- | ------------------------------- |
| `ATTESTOR_VERSION`    | `2.2.0`                 | Docker image tag                |
| `HEALTH_PORT`         | `8180`                  | Health endpoint port            |
| `METRICS_PORT`        | `9190`                  | Metrics endpoint port           |
| `RUST_LOG`            | `igra_attestation=info` | Log level                       |
| `REORG_SAFETY_BLOCKS` | `30`                    | Blocks to wait before attesting |

## Switching Networks

Remove the existing `.env` and re-run setup:

```bash
rm .env
./setup.sh mainnet
```
