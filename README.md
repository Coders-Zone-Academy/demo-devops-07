# Site Reliability Engineering (SRE) demo

This project template is designed to practice monitoring on AWS.

## Installation Tests

instalación de node exporter

```bash
curl http://localhost:9100/metrics
```

habilitar métricas de nginx

```bash
curl http://127.0.0.1:8080/stub_status
```

instalar nginx exporter

```bash
curl http://localhost:9113/metrics
```

instalar prometheus

```bash
curl http://localhost:9090/-/healthy
```

instalar grafana

```bash
http://my-ip:3000
```

## Important Urls

Prometheus

```bash
http://my-ip:9090
```

Grafana

```bash
http://my-ip:3000
```

Predefined Grafana dashboards

```bash
https://grafana.com/grafana/dashboards/
```

## PromQL queries for reliability

SLI

```bash
rate(nginx_http_requests_total[1m])
```

SLO

```bash
rate(nginx_http_requests_total{job="nginx_exporter"}[1m]) >= bool 5
```

EB

```bash
clamp_min(4 - rate(nginx_http_requests_total{job="nginx_exporter"}[1m]), 0)
```

## Generate a high volume of concurrent requests on an Nginx server

```bash
while true; do
  curl http://localhost:8080
  sleep 0.1
done
```
