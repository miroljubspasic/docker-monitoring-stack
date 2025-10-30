# Monitoring Platform

A comprehensive Docker-based monitoring stack for infrastructure and application monitoring, metrics collection, and log aggregation.

## Overview

This monitoring platform provides a complete observability solution using industry-standard open-source tools. It includes metrics collection, visualization, log aggregation, and a private Docker registry.

## Services

### Core Monitoring

**Prometheus** - Time-series database and monitoring system
- Collects metrics from exporters and applications
- Provides alerting capabilities
- Accessible via Caddy reverse proxy with basic authentication
- Default hostname: `prometheus-dev.localhost`

**Grafana** - Metrics visualization and dashboards
- Pre-configured with Prometheus data source
- Dashboard provisioning supported
- Default hostname: `grafana-dev.localhost`
- Default credentials: admin / changeme (configure in .env)

**Node Exporter** - System metrics collector
- Exposes hardware and OS metrics
- Monitors CPU, memory, disk, network statistics

**cAdvisor** - Container metrics collector
- Monitors Docker container resource usage
- Provides per-container CPU, memory, network, and filesystem metrics

### Log Management

**Graylog** - Log aggregation and analysis
- Centralized log collection and processing
- Default hostname: `graylog-dev.localhost`
- Supports multiple log input protocols (Syslog, GELF, Beats)

**MongoDB** - Graylog metadata storage
- Stores Graylog configuration and metadata

**OpenSearch** - Log data storage and indexing
- Stores and indexes log data
- Provides search capabilities for Graylog

**DataNode** - Graylog OpenSearch cluster manager
- Manages OpenSearch instances for Graylog 6.x

### Infrastructure

**Caddy** - Reverse proxy and automatic HTTPS
- Automatic TLS certificate management
- Docker service discovery via labels
- HTTP/3 support

**Docker Registry** - Private Docker image registry
- Stores and distributes Docker images
- Basic authentication via htpasswd
- Default hostname: `hub-dev.localhost`

## Prerequisites

- Docker Engine 20.10 or later
- Docker Compose 2.0 or later
- At least 8GB RAM available for containers
- Ports 80, 443, and various service ports available

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd monitoring
```

### 2. Configure environment variables

Copy the example environment file and configure it:

```bash
cp .env.example .env
```

Edit `.env` and configure at minimum:

- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password
- `GRAYLOG_PASSWORD_SECRET` - Generate with: `pwgen -N 1 -s 96`
- `GRAYLOG_ROOT_PASSWORD_SHA2` - Generate with: `echo -n "password" | sha256sum | cut -d" " -f1`
- `OPENSEARCH_ADMIN_PASSWORD` - Generate with: `tr -dc A-Z-a-z-0-9_@#%^-_=+ < /dev/urandom | head -c32`
- `PROMETHEUS_ADMIN_PASSWORD` - Generate with: `docker-compose run --rm --entrypoint caddy caddy hash-password --plaintext 'password'`

### 3. Create required directories

```bash
mkdir -p docker/caddy/{conf,srv,data,config}
mkdir -p docker/registry/{data,certs,auth}
mkdir -p docker/prometheus/{data,secrets}
mkdir -p docker/grafana/provisioning/{dashboards,datasources}
mkdir -p docker/graylog/{mongodb,datanode,data/data,data/journal}
mkdir -p docker/opensearch/data
```

### 4. Configure Prometheus

Copy the example configuration files and edit with your production values:

```bash
cp docker/prometheus/prometheus.yml.example docker/prometheus/prometheus.yml
cp docker/prometheus/fastapi-targets.yml.example docker/prometheus/fastapi-targets.yml
```

Edit the files to replace example hostnames with your actual production servers:
- `docker/prometheus/prometheus.yml` - Configure scrape targets for your infrastructure
- `docker/prometheus/fastapi-targets.yml` - Configure FastAPI application targets (optional)

Note: These files are not tracked in git to protect production endpoints. Always use the .example files as templates.

### 5. Create registry authentication

```bash
docker run --rm --entrypoint htpasswd httpd:2 -Bbn <username> <password> > docker/registry/auth/htpasswd
```

### 6. Start the services

```bash
docker-compose up -d
```

### 7. Verify services are running

```bash
docker-compose ps
```

## Configuration

### Prometheus Configuration

The `prometheus.yml` file is not tracked in git for security reasons. Use `prometheus.yml.example` as a template.

To configure Prometheus, edit `docker/prometheus/prometheus.yml`:
- Scrape targets for your infrastructure
- Alerting rules
- Remote write endpoints
- Authentication credentials

Important notes:
- Production configuration files are in `.gitignore` to protect sensitive endpoints
- Always keep `.example` files updated when making structural changes
- Use separate credentials files in `docker/prometheus/secrets/` for authentication

Example minimal configuration:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
```

### Grafana Dashboards

Place dashboard JSON files in:
```
docker/grafana/provisioning/dashboards/
```

Create a dashboard provider configuration:
```
docker/grafana/provisioning/dashboards/dashboards.yml
```

### Grafana Data Sources

Create data source configuration:
```
docker/grafana/provisioning/datasources/prometheus.yml
```

Example Prometheus datasource:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
```

### Hostnames Configuration

For local development, add these entries to `/etc/hosts`:

```
127.0.0.1 grafana-dev.localhost
127.0.0.1 prometheus-dev.localhost
127.0.0.1 graylog-dev.localhost
127.0.0.1 hub-dev.localhost
```

For production, configure DNS records pointing to your server.

## Service Access

After starting the services, access them at:

- **Grafana**: https://grafana-dev.localhost:8063
- **Prometheus**: https://prometheus-dev.localhost:8063 (requires basic auth)
- **Graylog**: https://graylog-dev.localhost:8063
- **Docker Registry**: https://hub-dev.localhost:8063

Note: Default ports are 8060 (HTTP) and 8063 (HTTPS). Configure via `APP_PORT` and `APP_SECURE_PORT` in `.env`.

## Docker Registry Usage

### Login to registry

```bash
docker login https://hub-dev.localhost:8063
```

### Tag and push images

```bash
docker tag myapp:latest hub-dev.localhost:8063/myapp:latest
docker push hub-dev.localhost:8063/myapp:latest
```

### Pull images

```bash
docker pull hub-dev.localhost:8063/myapp:latest
```

## Log Collection

Graylog accepts logs on these ports:

- **5044/tcp** - Beats (Filebeat, Metricbeat, etc.)
- **5140/tcp,udp** - Syslog
- **5555/tcp,udp** - Raw TCP/UDP
- **12201/tcp,udp** - GELF
- **13301/tcp** - Forwarder data
- **13302/tcp** - Forwarder config

Configure your applications to send logs to the appropriate port.

## Data Persistence

All service data is persisted in the `docker/` directory:

- `docker/prometheus/data` - Prometheus time-series data
- `docker/grafana/` - Grafana database and dashboards (uses Docker volume)
- `docker/graylog/` - Graylog data and journal
- `docker/opensearch/data` - OpenSearch indices
- `docker/registry/data` - Docker registry images
- `docker/mongodb/` - MongoDB data

### Backup Strategy

Regular backups should include:

1. **Configuration files**: All files in `docker/` subdirectories
2. **Prometheus data**: `docker/prometheus/data`
3. **Grafana volume**: `docker volume inspect grafana_data`
4. **OpenSearch data**: `docker/opensearch/data`
5. **Registry images**: `docker/registry/data`

Example backup command:

```bash
tar czf monitoring-backup-$(date +%Y%m%d).tar.gz docker/ .env
```

## Resource Requirements

Minimum resource allocation per service:

- **Prometheus**: 1GB RAM
- **Grafana**: 512MB RAM
- **Graylog**: 2GB RAM
- **OpenSearch**: 2-4GB RAM (configurable via OPENSEARCH_JAVA_OPTS)
- **MongoDB**: 1GB RAM
- **Caddy**: 256MB RAM
- **Registry**: 512MB RAM
- **Node Exporter**: 128MB RAM
- **cAdvisor**: 256MB RAM

Total minimum: 8-10GB RAM

## Logging and Monitoring

All services use JSON file logging with rotation:

- **Max size**: 10MB per log file
- **Max files**: 3 rotated files
- **Total per service**: ~30MB max

View service logs:

```bash
docker-compose logs -f <service-name>
```

View logs for specific service:

```bash
docker logs <container-name> --tail 100 -f
```

## Troubleshooting

### Service won't start

Check logs:
```bash
docker-compose logs <service-name>
```

Check if port is already in use:
```bash
sudo lsof -i :<port-number>
```

### Out of memory errors

Check Docker resources:
```bash
docker stats
```

Adjust memory limits in `docker-compose.yaml` or increase Docker daemon memory allocation.

### OpenSearch won't start

Common issues:
- Insufficient memory: Check OPENSEARCH_JAVA_OPTS in .env
- vm.max_map_count too low: Run `sudo sysctl -w vm.max_map_count=262144`

### Graylog can't connect to OpenSearch

Verify OpenSearch is running:
```bash
curl http://localhost:9200
```

Check Graylog logs:
```bash
docker-compose logs graylog
```

### Registry push fails

Check authentication:
```bash
docker login https://hub-dev.localhost:8063
```

Verify htpasswd file exists:
```bash
cat docker/registry/auth/htpasswd
```

## Maintenance

### Update services

```bash
docker-compose pull
docker-compose up -d
```

### Restart specific service

```bash
docker-compose restart <service-name>
```

### Clean up old data

Prometheus retention (default 15 days) can be configured via command args.

Clean Docker system:
```bash
docker system prune -a
```

### Scale services

For production use, consider:
- Running Prometheus with remote storage
- Clustering OpenSearch for high availability
- Using external MongoDB replica set
- Load balancing Grafana instances

## Security Considerations

- Change all default passwords in `.env`
- Use strong passwords for all services
- Configure firewall rules to restrict access
- Enable HTTPS for all services (handled by Caddy)
- Regularly update service images
- Monitor access logs
- Consider using Docker secrets for sensitive data in production
- Review MongoDB authentication requirements
- Restrict Docker socket access for Caddy

## Network Architecture

Two Docker networks are used:

**monitoring** - Internal network for service communication
- Bridge driver
- All services connect to this network

**proxy** - Internal network for Caddy proxy
- Bridge driver, marked as internal
- Only services exposed via Caddy connect here

## Environment Variables

See `.env.example` for all configurable options. Key variables:

- `APP_PORT` - HTTP port (default: 8060)
- `APP_SECURE_PORT` - HTTPS port (default: 8063)
- `CADDY_DEBUG_LEVEL` - Log level: debug, info, warn, error
- `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` - Grafana credentials
- `PROMETHEUS_ADMIN_PASSWORD` - Prometheus basic auth (bcrypt hash)
- `REGISTRY_HOSTNAME` - Registry hostname
- `OPENSEARCH_JAVA_OPTS` - Java heap size for OpenSearch
- `*_IMAGE` - Docker image versions for all services
- `*_DATA` - Data directory paths (optional, defaults to ./docker)

## License

This project is provided as-is for infrastructure monitoring purposes.

## Support

For issues and questions:
- Review logs using `docker-compose logs`
- Check service documentation for specific components
- Verify configuration in `.env` file
