# NETOPS — Network Troubleshooting & Observability Platform

A Docker-based networking and observability lab designed to simulate, detect, investigate, and recover from application and reverse-proxy failures.

NETOPS demonstrates practical DevOps skills in container networking, DNS resolution, TCP connectivity, reverse proxy configuration, Bash automation, monitoring, alerting, and continuous integration.

## Architecture

```text
                  Client / Browser
                         |
                   localhost:8080
                         |
                  Nginx Reverse Proxy
                         |
                    FastAPI App
                    (Port 8000)
                         |
                   /health /metrics
                         |
                    Prometheus
                         |
                      Grafana

Blackbox Exporter ---> Nginx /health
        |
     Prometheus ---> Alert Rules

GitHub Actions ---> Tests + Configuration Validation
```

All application services communicate through a Docker Compose bridge network using service-name DNS resolution.

## Technology Stack

| Category | Technologies |
|---|---|
| Backend | Python, FastAPI, Uvicorn |
| Reverse Proxy | Nginx |
| Containers | Docker, Docker Compose |
| Networking | Docker Bridge, DNS, TCP, HTTP |
| Monitoring | Prometheus, Grafana |
| Availability Probes | Prometheus Blackbox Exporter |
| Automation | Bash |
| Testing | pytest, HTTPX |
| CI | GitHub Actions |

## Key Features

### Network Diagnostics API

- DNS resolution using Python sockets
- TCP port connectivity testing
- Application health checks
- Prometheus-compatible application metrics

### Reverse Proxy and Docker Networking

- Nginx routes HTTP requests to FastAPI
- Internal service discovery through Docker DNS
- Container networking through a dedicated bridge network
- Localhost-bound ports for development access

### Monitoring and Alerting

- Prometheus scrapes application metrics
- Blackbox Exporter probes Nginx HTTP availability
- Grafana visualizes application health, request rates, latency, and errors
- Prometheus alert rules detect API and reverse-proxy outages

### Incident Response

- Bash script checks DNS, TCP, HTTP, and container health
- Automated incident reports capture container status, network information, and logs
- Controlled outage simulations demonstrate failure detection and recovery

### Continuous Integration

GitHub Actions automatically:

1. Installs Python dependencies
2. Runs FastAPI tests
3. Validates Docker Compose configuration
4. Validates Prometheus configuration and alert rules

## Getting Started

### Prerequisites

- Docker Engine with Docker Compose
- Git
- Bash-compatible terminal

### Clone

```bash
git clone https://github.com/karthikpillai713/netops-project.git
cd netops-project
```

### Start the Platform

```bash
docker compose up -d --build
docker compose ps
```

### Access Services

| Service | URL |
|---|---|
| FastAPI through Nginx | http://localhost:8080 |
| FastAPI health endpoint | http://localhost:8080/health |
| FastAPI documentation | http://localhost:8080/docs |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |

Grafana requires initial setup of the Prometheus data source at `http://prometheus:9090`. The dashboard is configured separately.

## Network Diagnostics

Run the Bash diagnostic script:

```bash
bash scripts/network-check.sh example.com 443
```

The script checks DNS resolution, TCP connectivity, HTTP application health, and Docker container status.

Generate an incident report:

```bash
bash scripts/incident-report.sh
```

Reports are saved locally under `logs/incidents/`.

## Simulating an Nginx Outage

Stop the reverse proxy:

```bash
docker stop netops-nginx
```

Observe the failed HTTP health check:

```bash
curl -i http://localhost:8080/health
```

Prometheus Blackbox Exporter should report:

```promql
probe_success{job="netops-nginx"}
```

Expected value during the outage: `0`.

After the configured alert duration, `NETOPSReverseProxyDown` should enter the firing state.

Restore service:

```bash
docker start netops-nginx
```

Verify recovery:

```bash
curl -i http://localhost:8080/health
```

Expected result: HTTP 200 with `{"status":"healthy"}`.

## Prometheus Queries

API availability:

```promql
up{job="netops-api"}
```

Nginx availability:

```promql
probe_success{job="netops-nginx"}
```

HTTP request rate:

```promql
sum(rate(http_requests_total{job="netops-api"}[1m]))
```

Nginx probe duration:

```promql
probe_duration_seconds{job="netops-nginx"}
```

## Automated Testing

```bash
python -m pytest -v
```

The project includes five automated API tests.

## Security Notes

NETOPS is intended as a local development and troubleshooting lab. Diagnostic endpoints capable of resolving hosts or testing TCP connections should not be exposed publicly without appropriate access controls and restrictions.

## Project Status

**Phase 1 — Docker Networking and Observability:** Implemented.

Future expansion includes Linux virtual-machine networking, advanced troubleshooting scenarios, and AWS VPC networking.

## Author

[GitHub — karthikpillai713](https://github.com/karthikpillai713)
