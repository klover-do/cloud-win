import os
import secrets
import subprocess
from pathlib import Path
from flask import Flask, jsonify, render_template, request, abort

BASE = Path(__file__).resolve().parent
TOKEN_FILE = BASE / ".cloudwin-token"
VM_NAME = os.environ.get("VM_NAME", "cloudwin")

app = Flask(__name__, static_folder="novnc", static_url_path="/novnc")

def get_token():
    if not TOKEN_FILE.exists():
        TOKEN_FILE.write_text(secrets.token_urlsafe(32))
        TOKEN_FILE.chmod(0o600)
    return TOKEN_FILE.read_text().strip()

def run_virsh(*args):
    return subprocess.run(
        ["/usr/bin/virsh", *args],
        capture_output=True,
        text=True,
        timeout=20
    )

@app.before_request
def local_only():
    if request.remote_addr not in ("127.0.0.1", "::1"):
        abort(403)
    if request.method in ("POST", "PUT", "DELETE"):
        if request.headers.get("X-CloudWin-Token") != get_token():
            abort(403)

@app.get("/")
def index():
    return render_template("index.html", token=get_token())

@app.get("/api/status")
def status():
    result = run_virsh("domstate", VM_NAME)
    state = result.stdout.strip() if result.returncode == 0 else "not-created"
    return jsonify(name=VM_NAME, state=state, ok=result.returncode == 0)

@app.post("/api/start")
def start():
    result = run_virsh("start", VM_NAME)
    return jsonify(
        ok=result.returncode == 0,
        output=(result.stdout + result.stderr).strip()
    ), (200 if result.returncode == 0 else 400)

@app.post("/api/shutdown")
def shutdown():
    result = run_virsh("shutdown", VM_NAME)
    return jsonify(
        ok=result.returncode == 0,
        output=(result.stdout + result.stderr).strip()
    ), (200 if result.returncode == 0 else 400)

@app.get("/health")
def health():
    return jsonify(ok=True, service="cloudwin-web")
