from aiohttp import web
import os
import time
import logging
from logging.handlers import RotatingFileHandler

# CONFIG
HOST = "0.0.0.0"
PORT = 8001
AUTH_HEADER = "X-Auth-Token"
AUTH_TOKEN = "" # Define your token here, or another file.

DOCUMENT_ROOT = os.path.abspath("/mnt/pServe") # define root path to serve files from
LOG_FILE = "/Projects/pServe/logs/pServe.log"
MAX_LOG_SIZE = 5 * 1024 * 1024  # 5MB max log file size
BACKUP_COUNT = 5

# === STATS STORAGE ===
stats = {
    "total_downloads": 0,
    "total_bytes_served": 0,
    "recent": []
}

# LOGGING SETUP 
log_formatter = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s")
log_handler = RotatingFileHandler(LOG_FILE, maxBytes=MAX_LOG_SIZE, backupCount=BACKUP_COUNT)
log_handler.setFormatter(log_formatter)

logging.basicConfig(level=logging.INFO, handlers=[log_handler, logging.StreamHandler()])


# MIDDLEWARE AUTH
@web.middleware
async def auth_middleware(request, handler):
    if request.path == "/stats":
        return await handler(request)

    token = request.headers.get(AUTH_HEADER)
    if token != AUTH_TOKEN:
        client_ip = request.remote
        logging.warning(f"Unauthorized access attempt from {client_ip} to {request.path}")
        return web.Response(status=403, text="403 Forbidden: Invalid Token")
    return await handler(request)


# FILE HANDLES
async def handle_file(request):
    rel_path = request.match_info.get('filename', '')
    full_path = os.path.join(DOCUMENT_ROOT, rel_path)

    if not os.path.abspath(full_path).startswith(DOCUMENT_ROOT):
        return web.Response(status=403, text="403 Forbidden: Path Traversal Detected")

    if not os.path.isfile(full_path):
        return web.Response(status=404, text="404 Not Found")

    start_time = time.time()
    file_size = os.path.getsize(full_path)
    client_ip = request.remote

    response = web.StreamResponse()
    response.content_type = 'application/octet-stream'
    response.headers['Content-Disposition'] = f'attachment; filename="{os.path.basename(full_path)}"'
    await response.prepare(request)

    with open(full_path, 'rb') as f:
        chunk_size = 64 * 1024
        while chunk := f.read(chunk_size):
            await response.write(chunk)
    await response.write_eof()

    duration = time.time() - start_time

    # Update stats
    stats["total_downloads"] += 1
    stats["total_bytes_served"] += file_size
    stats["recent"].append({
        "file": rel_path,
        "bytes": file_size,
        "client": client_ip,
        "time": round(duration, 2)
    })
    if len(stats["recent"]) > 10:
        stats["recent"] = stats["recent"][-10:]

    logging.info(f"{client_ip} downloaded {rel_path} ({file_size} bytes) in {duration:.2f}s")

    return response

# STATS ENDPOINT ROUTE
async def handle_stats(request):
    return web.json_response(stats)

# APP SETUP
app = web.Application(middlewares=[auth_middleware])
app.router.add_get('/{filename:.*}', handle_file)
app.router.add_get('/stats', handle_stats)

if __name__ == '__main__':
    logging.info(f"Serving {DOCUMENT_ROOT} on http://{HOST}:{PORT}")
    web.run_app(app, host=HOST, port=PORT)
