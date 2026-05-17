# Dockerized Django Project

## Services

- `web` - Django application on Python 3.14
- `db` - PostgreSQL database
- `nginx` - reverse proxy available at `http://localhost`

## Run Locally

```bash
docker compose up -d
```

## Check Services

```bash
docker compose ps
docker compose logs web
```

```text
http://localhost
```

## Stop Project

```bash
docker compose down
```
