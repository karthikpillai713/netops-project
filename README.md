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

Grafana requires a Prometheus data source configured with the URL `http://prometheus:9090`.

### Import the Grafana Dashboard

The NETOPS monitoring dashboard is included in this repository at:

`grafana/dashboards/netops-dashboard.json`

To import it:

1. Start the NETOPS environment using `docker compose up -d --build`.
2. Open Grafana at `http://localhost:3000` and sign in.
3. Navigate to **Connections → Data sources** and configure Prometheus with the URL `http://prometheus:9090`. Click **Save & test**.
4. Navigate to **Dashboards → New → Import**.
5. Upload `grafana/dashboards/netops-dashboard.json`.
6. If prompted, select the Prometheus data source and complete the import.

**Note:** The dashboard was exported using Grafana's newer resource-style JSON format (`apiVersion`, `kind`, `metadata`, `spec`). Import compatibility may depend on the Grafana version. If the import interface rejects this file, export a classic dashboard JSON from Grafana or use the supported resource import method.

The dashboard contains six panels covering API health, Nginx availability, HTTP request rate, response latency, and HTTP 5xx errors.

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

## Phase 2 — Linux Server Networking & Troubleshooting

Phase 2 extends NETOPS beyond Docker containers into Linux server administration, network troubleshooting, service management, firewall configuration, and incident recovery.

The lab uses two Ubuntu Server virtual machines running on Microsoft Hyper-V.

### Infrastructure

| Component | Configuration |
|---|---|
| Virtualization | Microsoft Hyper-V |
| Operating System | Ubuntu Server |
| VM 1 | netops-server-1 |
| VM 2 | netops-server-2 |
| Virtual Network | Hyper-V Default Switch |
| Web Server | Nginx |
| Backend | Python HTTP application managed by systemd |
| Firewall | UFW |
| Remote Administration | OpenSSH |

The Hyper-V Default Switch provides virtual networking and NAT connectivity. VM addresses are assigned dynamically and may change.

### Linux Networking Diagnostics

Practiced essential Linux networking commands:

- `ip -br addr` — Inspect network interfaces and IP addresses.
- `ip route` — Examine routing tables and default gateways.
- `ping` — Test ICMP connectivity.
- `getent hosts` and `dig` — Investigate DNS resolution.
- `ss -tulnp` — Identify listening TCP and UDP ports.
- `curl` — Test HTTP endpoints and response codes.
- `tcpdump` — Capture and analyze network packets.

These tools were used to investigate connectivity between virtual machines, services, and network interfaces.

### Nginx Reverse Proxy

Configured Nginx on Ubuntu Server 1 to forward HTTP requests to a Python backend.

```text
Client
   |
   | HTTP :80
   v
Nginx Reverse Proxy
   |
   | HTTP 127.0.0.1:8000
   v
Python Backend
   |
   v
/health
```

The backend runs as a systemd-managed service.

### Firewall Troubleshooting

Configured UFW to manage inbound traffic and performed controlled firewall troubleshooting exercises.

The lab included examining firewall rules, testing allowed and blocked connections, and restoring connectivity after simulated failures.

### Packet Analysis

Used `tcpdump` to observe TCP traffic during normal operation and connectivity failures.

Investigated TCP connection establishment and SYN retransmissions during firewall-related connectivity problems.

### Incident Simulation — HTTP 502 Bad Gateway

Simulated an application outage by stopping the backend service while leaving Nginx running.

Observed:

- Nginx remained active.
- The backend service became unavailable.
- HTTP requests returned `502 Bad Gateway`.
- Network diagnostic checks identified the service failure.

Recovered the application by restarting the backend service and verifying that HTTP requests returned `200 OK`.

### Automated Bash Diagnostics

Created a 92-line Bash troubleshooting script:

`scripts/network-diagnostics.sh`

The script performs six automated checks:

1. External network connectivity.
2. DNS resolution.
3. Local TCP connectivity to Nginx.
4. HTTP health endpoint availability.
5. Nginx systemd service status.
6. Backend systemd service status.

It displays PASS/FAIL results, summarizes the number of successful and failed checks, and returns an appropriate exit code.

**Healthy state:**

```text
Passed: 6
Failed: 0
Overall Status: HEALTHY
Exit Code: 0
```

**Simulated backend outage:**

```text
Passed: 4
Failed: 2
Overall Status: UNHEALTHY
Exit Code: 1
```

The script is intended to run on the Ubuntu Server 1 lab environment, where the required services are configured.

### Skills Demonstrated

Linux networking, DNS troubleshooting, TCP/IP, Nginx, systemd, UFW, tcpdump, Bash scripting, SSH, SCP, incident investigation, and service recovery.


## Project Status

## Project Status

- **Phase 1 — Docker Networking and Observability:** Completed.
- **Phase 2 — Linux Server Networking and Troubleshooting:** Completed.
- **Phase 3 — AWS VPC Networking and Cloud Troubleshooting:** Planned.

## Author

[GitHub — karthikpillai713](https://github.com/karthikpillai713)
