# Statix ⚡

> **macOS Apple Silicon (M1/M2/M3/M4) ve Intel (x86_64)** mimarileriyle %100 uyumlu, ultra hafif (1.4 MB), menü çubuğunda (üst navbar) çalışan modern sistem kaynak, sıcaklık ve network port izleme/yönetim uygulaması.

![Platform](https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue?style=flat-square&logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Universal%202%20(arm64%20%2B%20x86__64)-success?style=flat-square)
![Language](https://img.shields.io/badge/Language-Objective--C%20%2F%20Cocoa%20%2F%20HTML5-orange?style=flat-square)
![Binary Size](https://img.shields.io/badge/Size-1.4%20MB-purple?style=flat-square)
![Package](https://img.shields.io/badge/Package-DMG%20Installer-green?style=flat-square)

---

## 🎯 Yeni Eklenen Gelişmiş Özellikler

### 1. 🔌 Ağ Port Yöneticisi & Tek Tıkla Süreç Sonlandırma (Kill Process)
- **Problem:** Bir geliştirici olarak `3000`, `8080`, `5432` gibi bir portta proje başlatmak istediğinizde, arka planda unutulmuş başka bir süreç portu işgal eder ve terminalde `lsof -i :3000` ve `kill -9 <PID>` yazmak zorunda kalırsınız.
- **Çözüm (Statix Port Yöneticisi):**
  - Sistemde dinlenen (LISTEN modundaki) tüm TCP portlarını anlık listeler.
  - Her port için **Port Numarası** (`:3000`), **Süreç Adı** (`node`, `python3`, `docker`), **PID** ve dinleme adresini gösterir.
  - **Canlı Arama & Filtreleme:** Arama kutusuna sadece `3000` veya `node` yazarak portu anında bulun.
  - **Tek Tıkla Sonlandırma (Kill):** İlgili portun yanındaki `Sonlandır` butonuna basarak portu işgal eden süreci anında öldürün ve portu serbest bırakın!

### 2. ℹ️ Hakkında (About) Ekranı & İletişim
- Proje ve geliştirici bilgilerini içeren özel sekme:
  - **GitHub Deposu:** [https://github.com/gazi-dis/statix](https://github.com/gazi-dis/statix) (Tek tıkla tarayıcıda açılır)
  - **Geliştirici İletişim E-Postası:** [gazidis60@gmail.com](mailto:gazidis60@gmail.com) (Tek tıkla mail istemcisini açar)
  - **Sistem Özeti:** Donanım çipi, mimari, macOS sürümü ve çalışma süresi.

### 3. 🌡️ İşlemci (CPU) Sıcaklık Takibi
- **Apple Silicon (M1/M2/M3/M4):** `IOHIDEventSystemClient` ile performans (`pACC`), verimlilik (`eACC`) ve `SoC Die` sıcaklıklarını 0.1°C hassasiyetle okur.
- **Intel (x86_64):** `AppleSMC` üzerinden `TC0P`, `TC0D`, `TC0E`, `TCXC` anahtarlarıyla doğrudan işlemci sıcaklığını okur.
- **Birim:** Ayarlardan **°C** veya **°F** seçilebilir.
- **Menü Çubuğu Modları:** `İkon + Sıcaklık` veya `İkon + CPU & Sıcaklık` olarak üst barda görüntülenebilir.

### 4. 🚀 Açılışta Otomatik Başlatma (Launch at Login)
- Varsayılan olarak açık gelir; ayarlar panelinden veya menü çubuğundaki sağ tık menüsünden tek tıkla kapatılıp açılabilir.

### 5. 💿 DMG Kurulum Paketi
- Standart sürükle-bırak yükleyicisi [Statix-Universal.dmg](dist/Statix-Universal.dmg) olarak hazırdır.

---

## 🧭 Uygulama İçi Sekmeler

| Sekme | Açıklama |
| :--- | :--- |
| **📊 Sistem** | CPU kullanım %, dalga grafiği (Sparkline), çekirdek yükleri, sıcaklık, 4 parçalı RAM göstergesi, Disk doluluğu, anlık indirme/yükleme ağ hızları, pil durumu ve en çok tüketen 5 süreç. |
| **🔌 Portlar** | Dinlenen aktif TCP portları, arama/filtreleme çubuğu ve tek tıkla portu işgal eden süreci sonlandırma (Kill Process) butonu. |
| **ℹ️ Hakkında** | Proje GitHub adresi, geliştirici e-posta bilgisi, sistem mimari bilgileri ve lisans. |

---

## 🚀 Kurulum ve Çalıştırma

### 1. DMG Paketi ile Kurulum (Önerilen):
```bash
open dist/Statix-Universal.dmg
```
Açılan pencereden `Statix.app` dosyasını `Applications` klasörüne sürükleyin.

### 2. Doğrudan Çalıştırma:
```bash
open dist/Statix.app
```

### 3. Kaynak Koddan Derleme:
```bash
# DMG üretimi:
make dmg

# Doğrudan derleyip çalıştırmak için:
make run
```

---

## 📂 Dizin Yapısı

```
statix/
├── Makefile                # make dist, make dmg, make run, make install
├── build.sh                # Evrensel (Universal 2) derleme betiği
├── src/
│   ├── main.m              # NSApplication başlatıcı
│   ├── AppDelegate.h / .m  # Durum çubuğu, açılır pencere, menü ve süreç sonlandırma yönetimi
│   ├── SystemMonitor.h / .m# IOHID + AppleSMC sıcaklık, sistem metrikleri ve lsof port tarayıcı
│   ├── Info.plist          # macOS bundle tanımları (LSUIElement=true)
│   └── web/
│       ├── index.html      # Çok sekmeli (Sistem, Portlar, Hakkında) görsel arayüz
│       ├── style.css       # Cam efekti, Apple stili toggle switch, port kartları ve butonlar
│       └── app.js          # Port yönetimi, süreç sonlandırma onayı, sıcaklık ve grafik kontrolü
├── tools/
│   ├── create_dmg.sh       # DMG kurulum paketi oluşturucu
│   ├── generate_icons.m    # Çoklu çözünürlük simge çizici
│   └── pack_icns.py        # Apple ICNS paketleyici
├── assets/                 # AppIcon.icns ve menubar ikonları
└── dist/
    ├── Statix-Universal.dmg# Drag-and-drop macOS DMG yükleyici
    ├── Statix-Universal.zip# Taşınabilir Zip arşivi
    └── Statix.app          # Çalıştırılabilir Universal macOS uygulaması
```
