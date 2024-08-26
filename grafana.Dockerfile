x-clickhouse-defaults: &clickhouse-defaults
  restart: on-failure

x-environment: &oncall-environment
  DATABASE_TYPE: sqlite3
  BROKER_TYPE: redis
  BASE_URL: $DOMAIN
  SECRET_KEY: $SECRET_KEY
  FEATURE_PROMETHEUS_EXPORTER_ENABLED: ${FEATURE_PROMETHEUS_EXPORTER_ENABLED:-false}
  PROMETHEUS_EXPORTER_SECRET: ${PROMETHEUS_EXPORTER_SECRET:-}
  REDIS_URI: redis://redis:6379/0
  DJANGO_SETTINGS_MODULE: settings.hobby
  CELERY_WORKER_QUEUE: "default,critical,long,slack,telegram,webhook,retry,celery,grafana"
  CELERY_WORKER_CONCURRENCY: "1"
  CELERY_WORKER_MAX_TASKS_PER_CHILD: "100"
  CELERY_WORKER_SHUTDOWN_INTERVAL: "65m"
  CELERY_WORKER_BEAT_ENABLED: "True"
  GRAFANA_API_URL: http://grafana:3000
  TWILIO_ACCOUNT_SID: "AC85935a37cannihilatee801c58af9bc0e"
  TWILIO_AUTH_TOKEN: "22c9b31c26cannihilate6dc06fe8c769"
  TWILIO_NUMBER: "+1725234275"
  TWILIO_VERIFY_SERVICE_SID: "VA43d5eannihilate447949c74f9f7c5d"
  GRAFANA_CLOUD_NOTIFICATIONS_ENABLED: "False"
  EMAIL_FROM_ADDRESS: "alertmanager@annihilate.com"
  EMAIL_HOST: "smtp-relay.brevo.com"
  EMAIL_HOST_PASSWORD: "29tannihilateVWx8vp"
  EMAIL_HOST_USER: "marketing@annihilate.com"

services:
  engine:
    image: grafana/oncall
    restart: always
    container_name: engine
    ports:
      - "8080:8080"
    command: sh -c "uwsgi --ini uwsgi.ini"
    environment: *oncall-environment
    volumes:
      - oncall_data:/var/lib/oncall
    depends_on:
      oncall_db_migration:
        condition: service_completed_successfully
      redis:
        condition: service_healthy

  celery:
    image: grafana/oncall
    restart: always
    container_name: celery
    command: sh -c "./celery_with_exporter.sh"
    environment: *oncall-environment
    volumes:
      - oncall_data:/var/lib/oncall
    depends_on:
      oncall_db_migration:
        condition: service_completed_successfully
      redis:
        condition: service_healthy

  oncall_db_migration:
    image: grafana/oncall
    command: python manage.py migrate --noinput
    environment: *oncall-environment
    container_name: oncall_db_migration
    volumes:
      - oncall_data:/var/lib/oncall
    depends_on:
      redis:
        condition: service_healthy

  redis:
    image: redis:7.0.5
    restart: always
    container_name: redis
    expose:
      - 6379
    volumes:
      - redis_data:/data
    deploy:
      resources:
        limits:
          memory: 500m
          cpus: "0.5"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      timeout: 5s
      interval: 5s
      retries: 10


  prometheus:
    container_name: prometheus
    image: prom/prometheus
    restart: always
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --enable-feature=exemplar-storage
      - --web.enable-remote-write-receiver
      - --storage.tsdb.retention.time=15d
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '0.25'
    ports:
      - "9090:9090"

  loki:
    image: grafana/loki:3.0.0
    container_name: loki
    command: -config.file=/etc/loki/local-config.yaml -config.expand-env=true
    volumes:
      - ./loki/loki-config.yaml:/etc/loki/local-config.yaml
      - loki:/loki
    ports:
      - "3100:3100"

  tempo:
    image: grafana/tempo:latest
    command: [ "-config.file=/etc/tempo.yml" ]
    container_name: tempo
    volumes:
      - ./tempo/tempo.yml:/etc/tempo.yml
      - tempo-storage:${PWD}/tempo
    ports:
      - "3200:3200"
      - "4317:4317"
      - "4318:4318"

  mimir:
    container_name: mimir
    image: grafana/mimir
    volumes:
      - mimir:/tmp/mimir
      - ./mimir/config:/etc/mimir-config
    entrypoint:
      - /bin/mimir
      - -config.file=/etc/mimir-config/mimir.yaml
    environment:
      AWS_ACCESS_KEY_ID: "AKIANNIHILATES6CP5O"
      AWS_SECRET_ACCESS_KEY: "5dhhjZr8kE1siannihilatewfBd817TH1sCXpM"
      AWS_REGION: "ap-southeast-1"
    ports:
      - "9009:9009"

  grafana:
    container_name: grafana
    image: grafana/grafana
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "5"
    volumes:
      - ./grafana/grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml
      - ./grafana/grafana.ini:/etc/grafana/grafana.ini:ro
      - grafana-storage:/var/lib/grafana
    environment:
      GF_LOG_LEVEL: debug
      GF_DATABASE_WAL: true
      GF_SECURITY_ADMIN_USER: ${GRAFANA_USER:-admin}
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD:-admin}
      GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS: grafana-oncall-app
      GF_INSTALL_PLUGINS: grafana-oncall-app,https://storage.googleapis.com/integration-artifacts/grafana-lokiexplore-app/grafana-lokiexplore-app-latest.zip;grafana-lokiexplore-app
      GF_PATHS_CONFIG: /etc/grafana/grafana.ini
        #GF_INSTALL_PLUGINS: grafana-clock-panel, grafana-simple-json-datasource,
        #restart: unless-stopped
    restart: always
    ports:
      - "3000:3000"

volumes:
  grafana-storage:
   external: true
  tempo-storage:
   external: true
  prometheus_data:
   external: true
  oncall_data:
   external: true
  redis_data:
   external: true
  loki:
   external: true
  mimir:
   external: true
