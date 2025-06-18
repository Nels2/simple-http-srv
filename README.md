# pServe (simple http server, with token auth)

**pServe** is a lightweight, token‑protected file‑sharing microservice powered by **aiohttp**.  Drop it into any Linux box (or container) and instantly expose a directory tree for authenticated downloads, complete with JSON usage statistics and rotating log files. 
Someone else has probably built better but, this is for my own backup purposes..

---

## Features

| Capability                 | Details                                                                                                                                         |
| -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **Token Auth**          | Every request (except `/stats`) must include a custom `X‑Auth‑Token` header.  Unauthorized attempts are logged and denied with `403 Forbidden`. |
| **Zero‑Copy Streaming** | Files are streamed in 64 KiB chunks to minimise memory usage and support large artefacts.                                                       |
| **Built‑in Metrics**    | `/stats` returns a rolling window of the last 10 downloads plus cumulative counters (`total_downloads`, `total_bytes_served`).                  |
| **Root Jail**           | All paths are resolved against `DOCUMENT_ROOT`; traversal attempts are blocked.                                                                 |
| **Rotating Logs**       | JSON‑like log lines written to `pServe.log`, auto‑rotating at 5 MB × 5 backups.                                                                 |
| **Async**                | Implemented with `aiohttp` for non‑blocking performance.                                                                                        |

---

## Configuration

Edit the constants at the top of `` (or supply env vars / overrides in your fork):

| Variable        | Purpose                                            | Default                            |
| --------------- | -------------------------------------------------- | ---------------------------------- |
| `HOST`          | Bind address                                       | `0.0.0.0`                          |
| `PORT`          | TCP port                                           | `8001`                             |
| `AUTH_HEADER`   | Header name to carry the token                     | `X‑Auth‑Token`                     |
| `AUTH_TOKEN`    | **Set your secret here** (or load from file / env) | ""                                 |
| `DOCUMENT_ROOT` | Absolute path to serve                             | `/mnt/pServe`                      |
| `LOG_FILE`      | Rotating log file destination                      | `/Projects/pServe/logs/pServe.log` |
| `MAX_LOG_SIZE`  | Size threshold before rotation                     | 5 MiB                              |
| `BACKUP_COUNT`  | How many rotated files to keep                     | 5                                  |

> **Tip:** You can export `AUTH_TOKEN` in a wrapper script or Docker `ENV` and read it at runtime to avoid committing secrets.

---

## Installation

```bash
# 1) Clone
git clone https://github.com/<you>/pServe.git
cd pServe

# 2) Create virtual env (optional, recommended)
python3 -m venv venv
source venv/bin/activate

# 3) Install deps
pip install aiohttp
```

---

## Usage

```bash
python pserve.py  # or whatever you renamed the script
```

Console output:

```
YYYY‑MM‑DD HH:MM:SS [INFO] Serving /mnt/pServe on http://0.0.0.0:8001
```

### Downloading a file

```bash
curl -H "X-Auth-Token: <YOUR_TOKEN>" \
     -O http://server:8001/iso/rocky-9.4.iso
```

### Checking stats

```bash
curl http://server:8001/stats | jq
```

Example response:

```json
{
  "total_downloads": 3,
  "total_bytes_served": 4260864000,
  "recent": [
    {
      "file": "iso/rocky-9.4.iso",
      "bytes": 1457784832,
      "client": "192.168.1.42",
      "time": 12.77
    }
  ]
}
```

---

## Endpoint Reference

| Method | Path          | Description                                                                  | Auth Required |
| ------ | ------------- | ---------------------------------------------------------------------------- | ------------- |
| `GET`  | `/{filename}` | Streams the requested file from `DOCUMENT_ROOT`.  Path traversal is blocked. | ✔️            |
| `GET`  | `/stats`      | JSON usage metrics (last 10 downloads + totals).                             | ❌             |

---

## Logging

Log files rotate automatically once they exceed **5 MiB**, retaining up to **5** backups (`pServe.log.1`, `pServe.log.2`, …).  Each line includes timestamp, level, and message, e.g.:

```
2025‑06‑17 21:34:11,986 [INFO] 10.0.0.15 downloaded iso/rocky-9.4.iso (1457784832 bytes) in 12.77s
2025‑06‑17 21:40:08,233 [WARNING] Unauthorized access attempt from 10.0.0.99 to /etc/passwd
```

---

##️ Security Notes

- **TLS:** Serve behind an SSL‑terminating reverse proxy (nginx, Caddy, Traefik) for production use.
- **Header Token:** Rotate tokens periodically and use strong randomness (≥16 bytes).
- **CORS / Range Requests:** Add middleware if you need advanced behaviours.

---
