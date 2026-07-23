#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"
VENV="$PROJECT_DIR/.venv"

log(){ printf '\n\033[1;32m[+]\033[0m %s\n' "$*"; }
warn(){ printf '\n\033[1;33m[!]\033[0m %s\n' "$*"; }
die(){ printf '\n\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f config/hosts.yml ]] || die "config/hosts.yml tidak ditemukan"
command -v apt-get >/dev/null 2>&1 || die "Installer otomatis ini mendukung controller Ubuntu/Debian (apt-get)."

if [[ $EUID -eq 0 ]]; then
  SUDO=""
  OWNER_USER="${SUDO_USER:-root}"
else
  command -v sudo >/dev/null 2>&1 || die "sudo tidak tersedia. Jalankan sebagai root."
  SUDO="sudo"
  OWNER_USER="$USER"
fi

log "Memasang paket dasar controller"
$SUDO apt-get update
$SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  python3 python3-venv python3-pip openssh-client curl unzip ca-certificates

PYTHON_BIN="${ANSIBLE_PYTHON_BIN:-$(command -v python3)}"
PY_MAJOR="$($PYTHON_BIN -c 'import sys; print(sys.version_info.major)')"
PY_MINOR="$($PYTHON_BIN -c 'import sys; print(sys.version_info.minor)')"
PY_VERSION="$($PYTHON_BIN -c 'import platform; print(platform.python_version())')"
[[ "$PY_MAJOR" -eq 3 ]] || die "Python 3 diperlukan. Terdeteksi: $PY_VERSION"

# Pilih paket Ansible yang kompatibel dengan Python controller.
if (( PY_MINOR >= 12 )); then
  ANSIBLE_SPEC="ansible==14.2.0"
elif (( PY_MINOR == 11 )); then
  ANSIBLE_SPEC="ansible==12.3.0"
elif (( PY_MINOR == 10 )); then
  ANSIBLE_SPEC="ansible==10.7.0"
else
  die "Python $PY_VERSION terlalu lama. Gunakan Python 3.10 atau lebih baru."
fi

log "Python controller: $PY_VERSION"
log "Paket kompatibel yang dipilih: $ANSIBLE_SPEC"

# Hapus venv lama bila dibuat dengan interpreter berbeda atau rusak.
if [[ -d "$VENV" ]]; then
  OLD_VER=""
  [[ -x "$VENV/bin/python" ]] && OLD_VER="$($VENV/bin/python -c 'import platform; print(platform.python_version())' 2>/dev/null || true)"
  if [[ "$OLD_VER" != "$PY_VERSION" ]]; then
    warn "Menghapus virtual environment lama (Python ${OLD_VER:-tidak diketahui})."
    rm -rf "$VENV"
  fi
fi

log "Membuat virtual environment"
"$PYTHON_BIN" -m venv "$VENV"
"$VENV/bin/python" -m pip install --upgrade "pip<27" wheel packaging

log "Memasang Ansible"
"$VENV/bin/pip" install --upgrade "$ANSIBLE_SPEC"

log "Memasang collection Ansible"
"$VENV/bin/ansible-galaxy" collection install -r requirements.yml --force

log "Memvalidasi instalasi"
"$VENV/bin/ansible" --version
"$VENV/bin/ansible-galaxy" collection list community.docker
"$VENV/bin/ansible-inventory" --graph
"$VENV/bin/ansible-playbook" site.yml --syntax-check

chmod +x fasthttpctl scripts/list_hosts.py install-ansible-system.sh
if [[ $EUID -eq 0 && "$OWNER_USER" != root ]]; then
  chown -R "$OWNER_USER":"$(id -gn "$OWNER_USER")" "$PROJECT_DIR"
fi

cat <<'INFO'

============================================================
INSTALASI ANSIBLE SELESAI
============================================================

Installer ini sengaja TIDAK membuat atau menyalin SSH key dan TIDAK
menjalankan deployment. Lanjutkan secara manual:

1. Edit user SSH dan host/IP di:
     config/hosts.yml

2. Buat atau pilih SSH key sendiri, lalu pasang ke masing-masing host.
   Contoh:
     ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_fasthttp
     ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@IP_TARGET

3. Uji SSH manual:
     ssh -i ~/.ssh/id_ed25519_fasthttp ubuntu@IP_TARGET

4. Uji Ansible dengan key pilihan Anda:
     ./fasthttpctl ping --private-key ~/.ssh/id_ed25519_fasthttp

5. Deploy:
     ./fasthttpctl deploy --private-key ~/.ssh/id_ed25519_fasthttp

Bila private key sudah menjadi default ~/.ssh/id_ed25519 atau telah
terdaftar di ssh-agent, opsi --private-key tidak diperlukan.
INFO
