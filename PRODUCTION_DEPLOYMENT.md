# ============================================================================
# PRODUCTION DEPLOYMENT GUIDE
# ============================================================================

## Complete Production Setup Instructions

### Prerequisites
- Docker & Docker Compose installed
- PostgreSQL database (managed or self-hosted)
- Git for version control
- Linux server (Ubuntu 20.04+ recommended) or containerized deployment

---

## PHASE 1: ENVIRONMENT SETUP

### 1. Create Production Environment Files

Create `.env.production` in root directory:
```bash
# Application
ENVIRONMENT=production
SECRET_KEY=<generate-with: python -c "import secrets; print(secrets.token_urlsafe(32))">

# Database (PostgreSQL recommended)
DATABASE_URL=postgresql://music_user:strong_password@db.example.com:5432/music_downloader

# Frontend
VITE_API_URL=https://api.yourdomain.com
VITE_WS_URL=wss://api.yourdomain.com

# CORS - List all frontend origins
ALLOWED_ORIGINS=https://app.yourdomain.com,https://yourdomain.com

# API Configuration
MAX_CONCURRENT_DOWNLOADS=5
DOWNLOAD_TIMEOUT=600

# Logging
LOG_LEVEL=WARNING

# API Keys
JAMENDO_CLIENT_ID=<get-from-jamendo>
```

### 2. Database Setup (PostgreSQL)

```bash
# Connect to PostgreSQL server
psql -U postgres

# Create database
CREATE DATABASE music_downloader;

# Create user with permissions
CREATE USER music_user WITH PASSWORD 'strong_password';
ALTER ROLE music_user SET client_encoding TO 'utf8';
ALTER ROLE music_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE music_user SET default_transaction_deferrable TO on;
ALTER ROLE music_user SET default_time_zone TO 'UTC';

# Grant permissions
GRANT ALL PRIVILEGES ON DATABASE music_downloader TO music_user;
\c music_downloader
GRANT ALL ON SCHEMA public TO music_user;

# Exit
\q
```

### 3. Setup SSL Certificates

Using Let's Encrypt and Certbot:
```bash
sudo apt-get install certbot python3-certbot-nginx

# Get certificate
sudo certbot certonly --nginx -d api.yourdomain.com

# Auto-renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

---

## PHASE 2: BUILD & DEPLOYMENT

### Option A: Docker Compose Deployment (RECOMMENDED)

Create `docker-compose.prod.yml`:
```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: music_downloader
      POSTGRES_USER: music_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U music_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build:
      context: .
      dockerfile: Dockerfile.backend
    environment:
      ENVIRONMENT: production
      DATABASE_URL: postgresql://music_user:${DB_PASSWORD}@postgres:5432/music_downloader
      ALLOWED_ORIGINS: ${ALLOWED_ORIGINS}
      LOG_LEVEL: WARNING
    ports:
      - "8000:8000"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: always
    volumes:
      - downloads:/app/downloads
      - logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    build:
      context: .
      dockerfile: Dockerfile.frontend
    environment:
      VITE_API_URL: ${VITE_API_URL}
      VITE_WS_URL: ${VITE_WS_URL}
    ports:
      - "3000:80"
    depends_on:
      - backend
    restart: always

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.prod.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    depends_on:
      - backend
      - frontend
    restart: always

volumes:
  postgres_data:
  downloads:
  logs:
```

Deploy:
```bash
docker-compose -f docker-compose.prod.yml up -d
docker-compose -f docker-compose.prod.yml logs -f backend
```

### Option B: Kubernetes Deployment

Create `k8s/backend-deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: music-downloader-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: music-downloader-backend
  template:
    metadata:
      labels:
        app: music-downloader-backend
    spec:
      containers:
      - name: backend
        image: your-registry/music-downloader-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: music-downloader-secrets
              key: database-url
        - name: ENVIRONMENT
          value: "production"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /api/health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: music-downloader-backend-service
spec:
  selector:
    app: music-downloader-backend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer
```

Deploy:
```bash
kubectl create secret generic music-downloader-secrets \
  --from-literal=database-url=$DATABASE_URL

kubectl apply -f k8s/
```

---

## PHASE 3: MONITORING & LOGGING

### Setup Prometheus + Grafana

```yaml
# docker-compose additions
prometheus:
  image: prom/prometheus:latest
  volumes:
    - ./prometheus.yml:/etc/prometheus/prometheus.yml
    - prometheus_data:/prometheus
  ports:
    - "9090:9090"

grafana:
  image: grafana/grafana:latest
  environment:
    GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
  ports:
    - "3001:3000"
  volumes:
    - grafana_data:/var/lib/grafana
```

### Setup ELK Stack (Elasticsearch, Logstash, Kibana)

```yaml
elasticsearch:
  image: docker.elastic.co/elasticsearch/elasticsearch:8.0.0
  environment:
    - discovery.type=single-node
    - xpack.security.enabled=false
  volumes:
    - elasticsearch_data:/usr/share/elasticsearch/data

logstash:
  image: docker.elastic.co/logstash/logstash:8.0.0
  volumes:
    - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf

kibana:
  image: docker.elastic.co/kibana/kibana:8.0.0
  ports:
    - "5601:5601"
```

---

## PHASE 4: SECURITY HARDENING

### 1. Firewall Configuration

```bash
# UFW (Ubuntu Firewall)
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5432/tcp  # PostgreSQL (internal only)
```

### 2. Fail2Ban Installation

```bash
sudo apt-get install fail2ban

# Configure /etc/fail2ban/jail.local
[sshd]
enabled = true
maxretry = 5

[recidive]
enabled = true
```

### 3. Security Scanning

```bash
# OWASP ZAP scanning
docker run -t owasp/zap2docker-stable zap-baseline.py \
  -t https://api.yourdomain.com

# Trivy container scanning
trivy image your-registry/music-downloader-backend:latest
```

---

## PHASE 5: BACKUP & DISASTER RECOVERY

### Database Backups

```bash
# Daily backup script
#!/bin/bash
BACKUP_DIR="/backups/postgres"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

pg_dump \
  postgresql://music_user:$DB_PASSWORD@localhost/music_downloader \
  > $BACKUP_DIR/backup_$TIMESTAMP.sql

# Compress
gzip $BACKUP_DIR/backup_$TIMESTAMP.sql

# Upload to S3
aws s3 cp $BACKUP_DIR/backup_$TIMESTAMP.sql.gz s3://backups/music-downloader/
```

Add to crontab:
```bash
# Run daily at 2 AM
0 2 * * * /scripts/backup-db.sh
```

---

## PHASE 6: MONITORING & ALERTING

### Health Check Configuration

Create `/app/health_check.sh`:
```bash
#!/bin/bash

API_URL="https://api.yourdomain.com/api/health"
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $API_URL)

if [ $RESPONSE != "200" ]; then
    # Alert (send to Slack, PagerDuty, etc.)
    curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK \
      -H 'Content-Type: application/json' \
      -d "{\"text\": \"API health check failed: $RESPONSE\"}"
fi
```

Schedule with cron:
```bash
*/5 * * * * /app/health_check.sh
```

---

## PHASE 7: PERFORMANCE OPTIMIZATION

### Caching Strategy

```python
# In main.py - add Redis caching
from redis import Redis
from fastapi_cache2 import FastAPICache2
from fastapi_cache2.backends.redis import RedisBackend

redis = Redis.from_url("redis://redis:6379")
FastAPICache2.init(RedisBackend(redis), prefix="music-downloader")

# Cache downloads list for 60 seconds
from fastapi_cache2.decorator import cache

@app.get("/api/downloads")
@cache(expire=60)
async def get_downloads(db: Session = Depends(get_db)):
    # ... implementation
```

### CDN Configuration

```nginx
# nginx.conf
upstream backend {
    server backend:8000;
}

server {
    listen 443 ssl http2;
    server_name api.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## PHASE 8: CI/CD PIPELINE

See GITHUB_ACTIONS_SETUP.md for complete GitHub Actions workflow

---

## RUNBOOK: COMMON OPERATIONS

### Scale Backend Services
```bash
docker-compose -f docker-compose.prod.yml up -d --scale backend=5
```

### Database Migration
```bash
docker-compose -f docker-compose.prod.yml exec backend \
  alembic upgrade head
```

### View Logs
```bash
docker-compose -f docker-compose.prod.yml logs -f --tail=100 backend
```

### Emergency Rollback
```bash
docker-compose -f docker-compose.prod.yml down
docker pull your-registry/music-downloader-backend:previous-version
docker-compose -f docker-compose.prod.yml up -d
```

### Database Recovery
```bash
# Restore from backup
psql postgresql://music_user:password@localhost/music_downloader \
  < /backups/backup_20240101_020000.sql
```

---

## INCIDENT RESPONSE

### API Down
1. Check Docker logs: `docker-compose logs backend`
2. Verify database connection
3. Check disk space on server
4. Review recent deployments in git history
5. Rollback if needed
6. File incident report

### High Memory Usage
1. Check current memory: `free -h`
2. Identify large processes: `ps aux --sort=-%mem`
3. Check for memory leaks in logs
4. Restart service if needed: `docker-compose restart backend`
5. Implement caching/pagination if recurring

### Database Locks
1. Connect to database: `psql music_downloader`
2. List locks: `SELECT * FROM pg_locks;`
3. Kill blocking query: `SELECT pg_terminate_backend(pid);`
4. Check slow query log
5. Optimize affected queries

---

## SUCCESS CRITERIA

- [ ] All health checks pass
- [ ] API responds in <200ms
- [ ] Database queries <100ms average
- [ ] Zero errors in logs for 24 hours
- [ ] All security scans pass
- [ ] Backup/restore tested successfully
- [ ] Monitoring alerts configured
- [ ] Load testing shows >1000 concurrent users
- [ ] Disaster recovery tested
- [ ] Documentation complete
