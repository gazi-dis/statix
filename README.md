# Statix ⚡

> **macOS Apple Silicon (M1/M2/M3/M4) ve Intel (x86_64)** mimarileriyle %100 uyumlu, ultra hafif (1.3 MB), menü çubuğunda (üst navbar) çalışan modern sistem kaynak ve sıcaklık izleme uygulaması.

![Platform](https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue?style=flat-square&logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Universal%202%20(arm64%20%2B%20x86__64)-success?style=flat-square)
![Language](https://img.shields.io/badge/Language-Objective--C%20%2F%20Cocoa%20%2F%20HTML5-orange?style=flat-square)
![Binary Size](https://img.shields.io/badge/Size-1.3%20MB-purple?style=flat-square)
![Package](https://img.shields.io/badge/Package-DMG%20Installer-green?style=flat-square)

---

## 🎯 Yeni Eklenen Özellikler

### 1. 🌡️ İşlemci (CPU) Sıcaklık Takibi
- **Apple Silicon (M1/M2/M3/M4) Desteği:** Dahili `IOHIDEventSystemClient` ile performans çekirdekleri (`pACC`), verimlilik çekirdekleri (`eACC`) ve `SoC Die` sıcaklıklarını 0.1°C hassasiyetle okur.
- **Intel (x86_64) Desteği:** `AppleSMC` çekirdek sürücüsü üzerinden `TC0P`, `TC0D`, `TC0E`, `TCXC` anahtarlarıyla doğrudan işlemci paket sıcaklığını okur.
- **Birim Seçeneği:** Ayarlar ekranından **Celsius (°C)** veya **Fahrenheit (°F)** olarak değiştirilebilir.
- **Menü Çubuğu Modları:** Menü çubuğunda doğrudan sıcaklığı görebilirsiniz:
  - `İkon + Sıcaklık` (Örn: `⚡ 31°C`)
  - `İkon + CPU & Sıcaklık` (Örn: `⚡ 12% 31°C`)

### 2. 🚀 Açılışta Otomatik Başlatma (Launch at Login)
- **Varsayılan Olarak Açık:** Statix ilk açıldığında otomatik olarak macOS oturum açılış öğelerine eklenir.
- **Ayar Ekranından Değiştirilebilir:** Popover üzerindeki Ayarlar çekmecesinden veya sağ tık menüsünden tek tıkla açık/kapalı konuma getirilebilir.
- **Apple Standartlarına Uyumlu:** macOS 13+ (Ventura, Sonoma, Sequoia) için modern `SMAppService`, eski macOS sürümleri için ise `LaunchAgent` altyapısını kullanır.

### 3. 💿 DMG Kurulum Paketi (Statix-Universal.dmg)
- Standart macOS sürükle-bırak (drag-and-drop) yükleme paketi `dist/Statix-Universal.dmg` oluşturulmuştur.
- DMG çift tıklandığında açılan pencereden `Statix.app` doğrudan `Applications` (Uygulamalar) klasörüne sürüklenebilir.

---

## 📊 Genel Özellikler

### Üst Menü Çubuğu (Status Bar):
- **Özel Şablon İkon:** Koyu ve açık menü çubuğuna otomatik adapte olan EKG / işlemci simgesi.
- **Sol Tıklama:** Şık, yarı saydam cam efektli (frosted glass) **Dashboard** açılır penceresini gösterir.
- **Sağ Tıklama:** Hızlı özet metrikleri, görünüm modları, açılış tercihi ve çıkış butonunu içeren yerel macOS menüsünü açar.

### Canlı Dashboard:
- **İşlemci (CPU):** Kullanım %, Sıcaklık (°C/°F), Kullanıcı / Sistem / Boşta oranları, son 35 saniyenin dalga grafiği (Sparkline), her bir çekirdeğin bağımsız canlı yük seviyesi (C1–C8).
- **Bellek (RAM):** Kullanılan / Toplam GB, renkli 4 parçalı segment çubuğu (Kablolu, Aktif, Sıkıştırılmış, Boş), bellek baskısı (`Normal`, `Dikkat`, `Kritik`) ve Swap bellek.
- **Depolama (Disk):** Ana disk doluluk oranı ve kalan kullanılabilir boş alan.
- **Ağ Trafiği:** Canlı saniyelik İndirme (Download) ve Yükleme (Upload) hızları ile toplam oturum verisi.
- **Pil / Güç:** Şarj durumu, pil seviyesi ve kalan süre (Masaüstü Mac'lerde otomatik güç adaptörü moduna geçer).
- **En Çok Tüketen Süreçler:** CPU ve RAM tüketen ilk 5 aktif süreç (Ad, PID, Kullanım miktarı).
- **Sistem Bilgisi & Uptime:** Açık kalma süresi ve Activity Monitor kısayolu.

---

## 🚀 Kurulum ve Çalıştırma

### 1. DMG Paketi ile Kurulum (Önerilen):
`dist/Statix-Universal.dmg` dosyasını açıp uygulamayı `Applications` klasörüne sürükleyin:

```bash
open dist/Statix-Universal.dmg
```

### 2. Doğrudan Çalıştırma:
```bash
open dist/Statix.app
```

### 3. Kaynak Koddan Derleme:
```bash
# Universal binary ve DMG üretimi
make dmg
# veya: ./build.sh
```

---

## 📂 Dizin Yapısı

```
statix/
├── Makefile                # make dist, make dmg, make run, make install
├── build.sh                # Evrensel (Universal 2) derleme betiği
├── src/
│   ├── main.m              # NSApplication başlatıcı
│   ├── AppDelegate.h / .m  # Durum çubuğu, açılır pencere, menü ve açılış ayarları
│   ├── SystemMonitor.h / .m# IOHID + AppleSMC sıcaklık ve sistem metrik motoru
│   ├── Info.plist          # macOS bundle tanımları (LSUIElement=true)
│   └── web/
│       ├── index.html      # Sıcaklık rozetli ve açılış ayarlı arayüz
│       ├── style.css       # Cam efekti, Apple stili toggle switch ve koyu tema
│       └── app.js          # Canlı grafik, sıcaklık birimi dönüştürücü ve ayar yönetimi
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
