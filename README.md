# FastHTTP Smart Ansible Orchestrator

Paket ini memasang Docker Engine resmi dan menjalankan aplikasi Go FastHTTP pada banyak VM secara terpusat melalui Ansible.

Konfigurasi default:

| VM | IP | Container | Port host |
|---|---|---:|---|
| FastHTTP-Backend-01 | 10.221.67.69 | 4 | 8081–8084 |
| FastHTTP-Backend-02 | 10.221.67.148 | 4 | 8081–8084 |
| FastHTTP-Backend-03 | 10.221.67.124 | 4 | 8081–8084 |
| FastHTTP-Backend-04 | 10.221.67.68 | 4 | 8081–8084 |

Total default: **16 container FastHTTP**.

## 1. Cara kerja

- `install-ansible-system.sh` hanya menyiapkan Ansible Controller.
- `config/hosts.yml` adalah satu file utama untuk host, IP, user SSH, port, jumlah container, dan CPU.
- SSH keyless disiapkan manual karena user awal VM dapat berbeda: `ubuntu`, `debian`, `root`, `cloud-user`, dan lainnya.
- `fasthttpctl` menjadi antarmuka operasi terpusat.
- Playbook memasang Docker, membangun image Go, menjalankan container, dan memverifikasi HTTP 200.
---
##Full Rangkuman deployment
Disini Menggunakan FastHTTP-Backend-01 sebagai Deployer
```bash
#Jalankan installer
chmod +x install-ansible-system.sh fasthttpctl
./install-ansible-system.sh

# Konfigurasi user SSH
nano config/hosts.yml

# Setup keyless SSH manual
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_fasthttp
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.69
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.148
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.124
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.68

# Uji Ansible
./fasthttpctl ping \
  --private-key ~/.ssh/id_ed25519_fasthttp

# Jalankan deployment
./fasthttpctl deploy \
  --private-key ~/.ssh/id_ed25519_fasthttp
# Jika user membutuhkan password sudo
./fasthttpctl deploy \
  --private-key ~/.ssh/id_ed25519_fasthttp \
  --ask-become-pass

#----
# Periksa status:
./fasthttpctl status \
  --private-key ~/.ssh/id_ed25519_fasthttp

# Periksa statistik
./fasthttpctl stats \
  --private-key ~/.ssh/id_ed25519_fasthttp

```
Untuk lebih lengkapnya ikuti panduan di bawah
---

## 2. Persyaratan

### Ansible Controller

- Ubuntu/Debian dengan `apt-get`;
- Python 3.10 atau lebih baru;
- akses internet ke PyPI dan Ansible Galaxy;
- konektivitas TCP/22 ke seluruh VM;
- konektivitas TCP/8081–8084 untuk verifikasi dari controller.
- Menngunakan Flavor setiap backend(rekomendasi GP.8C16G).
- Menggunakan minimal 2 - 4 backen atau lebih.

### Managed host

- Ubuntu atau Debian;
- Python 3 tersedia pada `/usr/bin/python3`;
- user SSH memiliki akses `sudo`, atau gunakan root;
- akses internet ke repository Docker, Docker Hub, dan Go module proxy;
- port 8081–8084 belum dipakai aplikasi lain.

## 3. Download Config

```bash
git clone https://github.com/ica4me/deploy-golang-fasthttp.git fasthttp-ansible-smart
cd fasthttp-ansible-smart
chmod +x install-ansible-system.sh fasthttpctl
```

## 4. Instal Ansible Controller

```bash
./install-ansible-system.sh
```

Boleh pula dijalankan dengan:

```bash
sudo ./install-ansible-system.sh
```

Installer mendeteksi Python dan memilih versi Ansible yang kompatibel:

| Python controller | Paket Ansible |
|---|---|
| Python 3.10 | Ansible 10.7.0 |
| Python 3.11 | Ansible 12.3.0 |
| Python 3.12+ | Ansible 14.2.0 |

Dengan demikian error berikut tidak terjadi lagi pada Python 3.10:

```text
No matching distribution found for ansible<14,>=11
```

Installer tidak membuat SSH key, tidak menyalin key, dan tidak menjalankan deployment.

Periksa hasil:

```bash
./fasthttpctl version
./fasthttpctl inventory
```

## 5. Atur host dan user SSH

Edit satu file:

```bash
nano config/hosts.yml
```

Default global:

```yaml
all:
  vars:
    ansible_user: ubuntu
    ansible_python_interpreter: /usr/bin/python3
    ansible_become: true
    ansible_become_method: sudo
```

Gunakan salah satu pola berikut.

### Semua host memakai user ubuntu

```yaml
ansible_user: ubuntu
ansible_become: true
```

### Semua host memakai root

```yaml
ansible_user: root
ansible_become: false
```

### User berbeda untuk host tertentu

```yaml
FastHTTP-Backend-01:
  ansible_host: 10.221.67.69
  ansible_user: ubuntu

FastHTTP-Backend-02:
  ansible_host: 10.221.67.148
  ansible_user: debian
```

## 6. Persiapan keyless SSH manual

### Buat key baru

Jalankan sebagai user yang akan menjalankan Ansible:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_fasthttp
```

### Salin ke setiap VM

Untuk image Ubuntu:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.69
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.148
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.124
ssh-copy-id -i ~/.ssh/id_ed25519_fasthttp.pub ubuntu@10.221.67.68
```

Untuk Debian, ganti `ubuntu@` menjadi `debian@`. Untuk root, gunakan `root@` hanya bila kebijakan SSH mengizinkan.

### Uji login

```bash
ssh -i ~/.ssh/id_ed25519_fasthttp ubuntu@10.221.67.69
```

Jika user memerlukan password sudo, gunakan `--ask-become-pass` saat menjalankan playbook.

### Alternatif: gunakan ssh-agent

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519_fasthttp
```

Sesudah itu opsi `--private-key` tidak diperlukan.

## 7. Uji koneksi Ansible

Dengan key eksplisit:

```bash
./fasthttpctl ping --private-key ~/.ssh/id_ed25519_fasthttp
```

Dengan ssh-agent atau key default:

```bash
./fasthttpctl ping
```

Jika sudo meminta password:

```bash
./fasthttpctl ping --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl deploy --private-key ~/.ssh/id_ed25519_fasthttp --ask-become-pass
```

Hasil yang diharapkan:

```text
FastHTTP-Backend-01 | SUCCESS => {"ping": "pong"}
```

## 8. Deploy seluruh backend

```bash
./fasthttpctl deploy --private-key ~/.ssh/id_ed25519_fasthttp
```

Playbook akan:

1. memvalidasi Ubuntu/Debian dan konfigurasi;
2. memasang Docker Engine dari repository resmi;
3. membuat source FastHTTP di `/opt/fasthttp-backend`;
4. membuat dependency Go dengan `go mod tidy`;
5. membangun image `local/fasthttp-backend:1.0.0`;
6. menjalankan empat container per host;
7. memetakan port 8081–8084 ke port internal 8080;
8. menerapkan CPU limit atau CPU sharing secara otomatis;
9. menguji setiap endpoint lokal.

Verifikasi dari controller:

```bash
./fasthttpctl verify --private-key ~/.ssh/id_ed25519_fasthttp
```

## 9. Kebijakan CPU adaptif

Default:

```yaml
backend_container_count: 4
desired_cpus_per_container: 2.0
cpu_shares_when_oversubscribed: 1024
```

- Host dengan minimal 8 vCPU: setiap container mendapat batas maksimum 2 vCPU.
- Host dengan kurang dari 8 vCPU: hard limit dihilangkan; empat container berbagi CPU menggunakan `cpu_shares`.
- `cpu_shares` adalah bobot relatif ketika CPU sibuk, bukan reservasi CPU.

## 10. Operasi terpusat

```bash
./fasthttpctl status --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl stats --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl logs 1 --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl restart --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl stop --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl start --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl verify --private-key ~/.ssh/id_ed25519_fasthttp
```

Hanya satu host:

```bash
./fasthttpctl deploy \
  --limit FastHTTP-Backend-01 \
  --private-key ~/.ssh/id_ed25519_fasthttp
```

Hapus aplikasi dan container, tetapi pertahankan Docker:

```bash
./fasthttpctl remove --private-key ~/.ssh/id_ed25519_fasthttp
```

## 11. Uji endpoint manual

```bash
curl -i http://10.221.67.69:8081/
curl -i http://10.221.67.69:8082/
curl -i http://10.221.67.69:8083/
curl -i http://10.221.67.69:8084/
```

Contoh respons:

```text
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
X-Backend-Node: FastHTTP-Backend-01
X-Backend-Instance: backend-1

200 OK | node=FastHTTP-Backend-01 | instance=backend-1
```

## 12. Mengganti IP atau menambah host

Hanya edit:

```text
config/hosts.yml
```

Ganti IP:

```yaml
FastHTTP-Backend-02:
  ansible_host: 10.221.67.250
```

Tambah host:

```yaml
FastHTTP-Backend-05:
  ansible_host: 10.221.67.200
  ansible_user: debian
```

Pasang SSH key ke host baru, lalu:

```bash
./fasthttpctl ping --limit FastHTTP-Backend-05 --private-key ~/.ssh/id_ed25519_fasthttp
./fasthttpctl deploy --limit FastHTTP-Backend-05 --private-key ~/.ssh/id_ed25519_fasthttp
```

## 13. Firewall dan OpenStack Security Group

Izinkan minimum:

| Arah | Port | Sumber |
|---|---:|---|
| ingress | TCP/22 | IP controller |
| ingress | TCP/8081–8084 | load balancer/client yang sah |
| egress | TCP/443 | repository dan registry |
| egress | TCP/UDP 53 | DNS |

Pastikan port aplikasi tidak dipublikasikan ke internet kecuali memang diperlukan.

## 14. Troubleshooting

### Python controller masih salah

```bash
python3 --version
./.venv/bin/python --version
./fasthttpctl version
```

Reset virtual environment:

```bash
rm -rf .venv
./install-ansible-system.sh
```

Gunakan interpreter tertentu:

```bash
ANSIBLE_PYTHON_BIN=/usr/bin/python3.11 ./install-ansible-system.sh
```

### SSH gagal

```bash
ssh -vvv -i ~/.ssh/id_ed25519_fasthttp ubuntu@10.221.67.69
nc -zv 10.221.67.69 22
```

Pastikan `ansible_user` di `config/hosts.yml` sesuai.

### Sudo gagal

Gunakan:

```bash
./fasthttpctl deploy --ask-become-pass --private-key ~/.ssh/id_ed25519_fasthttp
```

Atau konfigurasi passwordless sudo sesuai kebijakan organisasi.

### Build Go gagal

```bash
curl -I https://proxy.golang.org
curl -I https://registry-1.docker.io
```

Dockerfile sudah menjalankan:

```dockerfile
COPY go.mod main.go ./
RUN go mod tidy && go mod download
```

Ini mencegah error `missing go.sum entry`.

### Port bentrok

Pada target:

```bash
sudo ss -lntp | grep -E ':8081|:8082|:8083|:8084'
```

Ubah `backend_first_port` di `config/hosts.yml` bila perlu.

### Lihat status Docker

```bash
sudo systemctl status docker
sudo docker ps -a
sudo docker logs fasthttp-1
```

## 15. Struktur proyek

```text
fasthttp-ansible-smart/
├── install-ansible-system.sh
├── fasthttpctl
├── ansible.cfg
├── requirements.yml
├── site.yml
├── config/
│   └── hosts.yml
├── playbooks/
├── roles/
│   ├── docker_engine/
│   └── fasthttp_backend/
└── scripts/
```
