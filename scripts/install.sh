
#!/usr/bin/env bash
set -euo pipefail

SOURCE="$(cd "$(dirname "$0")/.." && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo $0"
  exit 1
fi

apt-get update

apt-get install -y \
  python3-venv \
  python3-pip \
  git \
  curl \
  rsync \
  qemu-utils \
  python3-websockify

install -d -m 755 /opt/cloudwin

rsync -a --delete \
  --exclude '.git' \
  --exclude '.venv' \
  --exclude '.cloudwin-token' \
  "$SOURCE/" /opt/cloudwin/

python3 -m venv /opt/cloudwin/.venv

/opt/cloudwin/.venv/bin/pip install --upgrade pip

/opt/cloudwin/.venv/bin/pip install \
  -r /opt/cloudwin/requirements.txt

if [[ ! -d /opt/cloudwin/novnc ]]; then
  git clone --depth 1 \
    https://github.com/novnc/noVNC.git \
    /opt/cloudwin/novnc
fi

chown -R root:root /opt/cloudwin
chmod 700 /opt/cloudwin

install -d -m 755 /var/lib/cloudwin/iso

install -m 644 \
  /opt/cloudwin/systemd/cloudwin-web.service \
  /etc/systemd/system/cloudwin-web.service

install -m 644 \
  /opt/cloudwin/systemd/cloudwin-novnc.service \
  /etc/systemd/system/cloudwin-novnc.service

systemctl daemon-reload

echo "CloudWin installation complete!"
