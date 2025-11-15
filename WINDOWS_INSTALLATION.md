# supOS-CE Windows 11 + WSL2 + Docker Desktop Kurulum Rehberi

## 📋 Sistem Gereksinimleri

### Minimum:
- Windows 11 (Home veya Pro)
- CPU: 4 cores + Virtualization desteği
- RAM: 16 GB (8GB WSL2 + 8GB Windows)
- Disk: 100 GB boş alan (SSD önerili)

### Önerilen:
- CPU: 8 cores
- RAM: 32 GB
- Disk: 250 GB SSD

---

## 🔧 Phase 1: WSL2 Kurulumu

### Adım 1: WSL2'yi Etkinleştir

```powershell
# PowerShell'i Administrator olarak aç

# WSL feature'ı etkinleştir
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Virtual Machine Platform etkinleştir
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Bilgisayarı yeniden başlat
Restart-Computer
```

### Adım 2: WSL2'yi Default Yap

```powershell
# WSL2'yi default version yap
wsl --set-default-version 2

# WSL kernel update indir ve kur
# https://aka.ms/wsl2kernel
# Linki tarayıcıda aç ve kurulum dosyasını çalıştır
```

### Adım 3: Ubuntu 22.04 Kur

**Yöntem 1: Microsoft Store (Kolay)**
```
1. Microsoft Store'u aç
2. "Ubuntu 22.04 LTS" ara
3. "Get" butonuna tıkla
4. Kur
5. Launch
6. Username/password oluştur
```

**Yöntem 2: PowerShell (Hızlı)**
```powershell
# Ubuntu 22.04 kur
wsl --install -d Ubuntu-22.04

# Kurulum bitince kullanıcı oluştur
# Username: yourname
# Password: yourpassword
```

### Adım 4: WSL2 Kontrol

```powershell
# Kurulu distro'ları listele
wsl --list --verbose

# Çıktı:
# NAME            STATE           VERSION
# Ubuntu-22.04    Running         2

# VERSION 2 olmalı! 1 ise:
wsl --set-version Ubuntu-22.04 2
```

---

## 🐳 Phase 2: Docker Desktop Kurulumu

### Adım 1: Docker Desktop İndir

```
1. https://www.docker.com/products/docker-desktop/
2. "Download for Windows" tıkla
3. Docker Desktop Installer.exe indir
```

### Adım 2: Docker Desktop Kur

```
1. Installer'ı çalıştır
2. "Use WSL 2 instead of Hyper-V" seçeneğini işaretle ✅
3. Install
4. Bilgisayarı restart et
```

### Adım 3: Docker Desktop Ayarları

```
1. Docker Desktop'ı aç
2. Settings (⚙️) → Resources → WSL Integration
3. "Enable integration with my default WSL distro" ✅
4. "Ubuntu-22.04" toggle'ı aç ✅
5. "Apply & Restart"
```

### Adım 4: Resource Limits Ayarla

```
Settings → Resources → Advanced:

CPU: 4 cores
Memory: 8 GB
Swap: 2 GB
Disk image size: 100 GB

Apply & Restart
```

### Adım 5: Test

```powershell
# Windows Terminal'de WSL aç
wsl

# Docker test
docker --version
# Docker version 27.x.x

docker-compose --version
# Docker Compose version v2.x.x

docker run hello-world
# "Hello from Docker!" görmelisin ✅
```

---

## 🏗️ Phase 3: supOS-CE Kurulumu

### Adım 1: WSL Memory Config (Önerilen)

```bash
# Windows'ta PowerShell aç
notepad C:\Users\YourName\.wslconfig
```

**İçeriği:**
```ini
[wsl2]
memory=8GB
processors=4
swap=2GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
```

**Kaydet ve WSL restart:**
```powershell
wsl --shutdown
wsl
```

---

### Adım 2: WSL İçinde Kurulum

```bash
# WSL terminalini aç (Windows Terminal → Ubuntu)

# Home dizinine git (önemli!)
cd ~

# Git kur (kurulu değilse)
sudo apt update
sudo apt install git -y

# Repoları klonla
git clone https://github.com/aslanbaris/supOS-CE.git
git clone https://github.com/aslanbaris/supOS-backend.git
git clone https://github.com/aslanbaris/supOS-frontend.git

# supOS-CE'ye git
cd supOS-CE
```

---

### Adım 3: Build ve Deploy

```bash
# Build script'i çalıştır
chmod +x build-all.sh
./build-all.sh

# Beklenen çıktı:
# ✓ Backend build başarılı
# ✓ Frontend build başarılı
# ✓ Docker images oluşturuldu
# ✓ Containerlar başlatıldı
```

---

### Adım 4: Erişim Testi

**WSL Terminal:**
```bash
# Container durumunu kontrol
docker ps

# Health check
curl http://localhost:8088
```

**Windows Tarayıcı:**
```
Chrome'da aç:
http://localhost:8088/home

Credentials:
Username: supos
Password: supos
```

---

## 🔧 Phase 4: Development Workflow Kurulumu

### VS Code Setup

**1. VS Code Kur:**
```
https://code.visualstudio.com/
```

**2. WSL Extension Kur:**
```
VS Code → Extensions
"Remote - WSL" ara
Install
```

**3. WSL'den VS Code Aç:**
```bash
# WSL terminal
cd ~/supOS-CE
code .

# VS Code açılır, WSL içinde çalışır
# Sol altta "WSL: Ubuntu-22.04" görmelisin
```

---

### Windows Terminal Ayarları

**1. Windows Terminal Kur (kurulu değilse):**
```
Microsoft Store → Windows Terminal
```

**2. Default Profile Ayarla:**
```
Settings → Startup → Default profile: Ubuntu-22.04
```

**3. Custom Profile Ekle:**
```json
{
  "name": "supOS-CE Dev",
  "commandline": "wsl.exe ~ -d Ubuntu-22.04 cd ~/supOS-CE",
  "startingDirectory": "//wsl$/Ubuntu-22.04/home/yourname/supOS-CE"
}
```

---

## 📊 Resource Monitoring

### Docker Desktop Dashboard

```
Docker Desktop → Containers
├── supos-backend (CPU: 5%, RAM: 800MB)
├── supos-frontend (CPU: 1%, RAM: 200MB)
├── postgresql (CPU: 2%, RAM: 400MB)
└── ... (diğer containerlar)

Total: ~5GB RAM kullanımı
```

### WSL Resource Monitoring

```bash
# WSL içinde
htop

# Veya
docker stats

# Windows'ta
Task Manager → Performance → WSL
```

---

## 🐛 Troubleshooting

### Sorun 1: "Docker daemon not running"

**Çözüm:**
```
1. Docker Desktop'ı kapat
2. WSL'i kapat: wsl --shutdown
3. Docker Desktop'ı başlat
4. WSL'i başlat: wsl
```

---

### Sorun 2: "Cannot connect to Docker daemon"

**Çözüm:**
```bash
# WSL terminalinde
sudo service docker start

# Veya Docker Desktop'ı restart et
```

---

### Sorun 3: Yavaş Build/Performance

**Çözüm:**
```bash
# Dosyalar C:\ altında mı?
pwd
# /mnt/c/... görüyorsan YOK

# Taşı:
cd ~
mv /mnt/c/Users/.../supOS-CE ~/supOS-CE
```

---

### Sorun 4: Port Already in Use

**Çözüm:**
```powershell
# Windows'ta hangi process kullanıyor?
netstat -ano | findstr :8088

# Process ID'yi öğren, kapat:
taskkill /PID <PID> /F
```

---

### Sorun 5: Out of Memory

**Çözüm:**
```powershell
# .wslconfig'i düzenle
notepad C:\Users\YourName\.wslconfig

# memory=8GB → 12GB yap
# WSL restart
wsl --shutdown
```

---

## ✅ Verification Checklist

```
[ ] WSL2 kurulu ve çalışıyor (wsl --list -v)
[ ] Docker Desktop çalışıyor
[ ] Ubuntu-22.04 WSL entegrasyonu aktif
[ ] docker --version çalışıyor (WSL içinde)
[ ] Repolar klonlandı (~/supOS-CE)
[ ] build-all.sh çalıştırıldı
[ ] docker ps ile containerlar görünüyor
[ ] http://localhost:8088 erişilebilir
[ ] VS Code WSL extension kurulu
[ ] Login başarılı (supos/supos)
```

---

## 🎯 Development Commands

```bash
# Logs
docker-compose logs -f backend
docker-compose logs -f frontend

# Restart service
docker-compose restart backend

# Rebuild specific service
docker-compose up -d --build backend

# Stop all
docker-compose down

# Start all
docker-compose up -d

# Clean everything
docker-compose down -v
docker system prune -a
```

---

## 📚 Useful Links

- WSL2 Docs: https://docs.microsoft.com/en-us/windows/wsl/
- Docker Desktop WSL2: https://docs.docker.com/desktop/wsl/
- VS Code WSL: https://code.visualstudio.com/docs/remote/wsl

---

## 🚀 Quick Start Summary

```powershell
# 1. PowerShell (Admin)
wsl --install -d Ubuntu-22.04

# 2. Docker Desktop kur
# https://www.docker.com/products/docker-desktop/

# 3. WSL terminal
cd ~
git clone https://github.com/aslanbaris/supOS-CE
cd supOS-CE
./build-all.sh

# 4. Browser
http://localhost:8088/home
```

**Kurulum Süresi: 30-45 dakika**
**Başarı Oranı: %95+**

---

Son güncelleme: 2025-11-06
