# Statix ⚡

> **macOS Apple Silicon (M1/M2/M3/M4) ve Intel (x86_64)** mimarileriyle %100 uyumlu, ultra hafif (1.3 MB), menü çubuğunda (üst navbar) çalışan modern sistem kaynak izleme uygulaması.

![Platform](https://img.shields.io/badge/Platform-macOS%2011.0%2B-blue?style=flat-square&logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Universal%202%20(arm64%20%2B%20x86__64)-success?style=flat-square)
![Language](https://img.shields.io/badge/Language-Objective--C%20%2F%20Cocoa%20%2F%20HTML5-orange?style=flat-square)
![Binary Size](https://img.shields.io/badge/Size-1.3%20MB-purple?style=flat-square)

---

## 🎯 Özellikler

### 1. Üst Menü Çubuğu (Status Bar) Entegrasyonu
- **Özel Şablon İkonu:** macOS Açık ve Koyu modlarına otomatik uyum sağlayan dinamik EKG/işlemci ikonu.
- **Canlı Metin Göstergeleri:** Menü çubuğunda ne görmek istediğinizi seçebilirsiniz:
  - `Sadece İkon`
  - `İkon + CPU %` (Örn: `⚡ 14%`)
  - `İkon + CPU & RAM %` (Örn: `⚡ C:14% M:68%`)
  - `İkon + Ağ Hızı` (Örn: `↓ 1.2M/s  ↑ 240K/s`)
- **Çift Tıklama Mantığı:**
  - **Sol Tıklama:** Şık, yarı saydam ve akıcı açılır pencereyi (Dashboard) açar/kapatır.
  - **Sağ Tıklama:** Hızlı özet metrikleri, görünüm modu değişimi, yenileme aralığı ve çıkış seçeneklerini içeren yerel macOS menüsünü açar.

### 2. Canlı Dashboard (Açılır Panel)
- **İşlemci (CPU):**
  - Anlık toplam işlemci kullanım yüzdesi (Kullanıcı, Sistem, Boşta ayrımıyla).
  - Son 35 saniyelik CPU geçmişini gösteren yumuşak bezier eğrili canlı dalga grafiği (Sparkline).
  - Tüm çekirdeklerin (örneğin M1'deki 8 çekirdek) bağımsız anlık yük seviyeleri (C1...C8).
  - İşlemci modeli ve çekirdek sayısı tespiti (Örn: `Apple M1 • 8 Çekirdek`).
- **Bellek (RAM):**
  - Kullanılan ve toplam bellek gösterimi (Örn: `7.2 GB / 8.0 GB - %90`).
  - 4 parçalı renkli segment çubuğu: Kablolu (Wired), Aktif (Active), Sıkıştırılmış (Compressed), Boş (Free).
  - macOS Bellek Baskısı göstergesi (`Normal`, `Dikkat`, `Kritik`).
  - Swap (Takas alanı) bellek kullanımı.
- **Depolama (Disk):**
  - Ana disk (`Macintosh HD`) doluluk oranı ve kalan kullanılabilir boş alan.
- **Ağ Trafiği (Network):**
  - Canlı saniyelik İndirme (Download) ve Yükleme (Upload) hızları.
  - Oturum boyunca alınıp gönderilen toplam veri miktarı.
- **Pil / Güç Durumu:**
  - MacBook modellerinde pil yüzdesi, şarj durumu ve tahmini kalan süre.
  - Masaüstü Mac'lerde (Mac mini, Mac Studio, iMac) otomatik olarak güç kaynağı moduna geçer.
- **En Çok Kaynak Tüketen Süreçler (Top Processes):**
  - İşlemciyi en çok kullanan ilk 5 aktif süreç (Ad, PID, CPU %).
  - Belleği en çok kullanan ilk 5 aktif süreç (Ad, PID, RAM MB).
- **Sistem Bilgisi & Uptime:**
  - Bilgisayar açık kalma süresi (Uptime - gün/saat/dakika).
  - Mimari etiketi (`Apple Silicon (arm64)` veya `Intel (x86_64)`).
  - Tek tıkla macOS **Activity Monitor** (Etkinlik Monitörü) uygulamasını başlatma kısayolu.

---

## 🏗️ Mimari & Universal Binary

Statix, modern Apple ekosistemine tam uyumlu bir **Universal 2** ikili dosyası olarak derlenir:
- **`arm64`:** Apple Silicon (M1, M2, M3, M4) çipli Mac'lerde hiçbir emülasyona (Rosetta) ihtiyaç duymadan yerel çalışır.
- **`x86_64`:** Intel tabanlı tüm Mac'lerde yerel çalışır.
- **Hafiflik:** Ağır Electron/Node.js paketleri yerine macOS'un yerel **Cocoa / AppKit** ve gömülü **WebKit** motorunu kullanır. Bu sayede uygulama boyutu 200+ MB yerine sadece **1.3 MB**'tır ve arka planda neredeyse hiç RAM tüketmez.

---

## 🚀 Kurulum ve Çalıştırma

### Hazır Paketi Çalıştırma:
Uygulama `dist/` klasörü içerisinde kullanıma hazır durumdadır:

```bash
# Doğrudan çalıştırmak için:
open dist/Statix.app

# Uygulamalar (/Applications) klasörüne kurmak için:
cp -R dist/Statix.app /Applications/
```

### Kaynak Koddan Sıfırdan Derleme:

Gereksinimler: macOS ve standart Command Line Tools (`clang`). Ekstra bir kütüphane veya paket yöneticisi gerekmez!

```bash
# 1. Proje dizinine gidin
cd /Users/gazi/Documents/ai-projects/statix

# 2. Universal Binary ve .app paketini derleyin
make dist
# veya: ./build.sh

# 3. Çalıştırın
make run

# 4. Sisteme kurmak isterseniz
make install
```

---

## 🛠️ Proje Dizin Yapısı

```
statix/
├── Makefile                # Tek komutla derleme ve kurulum hedefleri
├── build.sh                # Universal binary derleme & paketleme betiği
├── src/
│   ├── main.m              # Giriş noktası ve NSApplication başlatıcı
│   ├── AppDelegate.h / .m  # NSStatusItem, NSPopover ve yerel menü yönetimi
│   ├── SystemMonitor.h / .m# Çekirdek metrik motoru (Mach, sysctl, statfs, libproc, IOKit)
│   ├── Info.plist          # macOS bundle tanımları (LSUIElement=true)
│   └── web/
│       ├── index.html      # Şık ve modern Dashboard arayüzü
│       ├── style.css       # Cam efekti (Frosted glass), koyu tema ve animasyonlar
│       └── app.js          # Grafik çizimi, metrik güncelleme ve yerel köprü
├── tools/
│   ├── generate_icons.m    # Çoklu çözünürlükte simge çizici
│   └── pack_icns.py        # Apple ICNS paketleyici
├── assets/                 # AppIcon.icns ve menubar şablon ikonları
└── dist/
    ├── Statix.app          # Çalıştırılabilir evrensel macOS uygulaması
    └── Statix-Universal.zip# Dağıtım arşivi
```

---

## ⚙️ Tercihler & İpuçları

- **Açılışta Otomatik Başlatma:**
  - *Sistem Ayarları > Genel > Giriş Öğeleri* bölümüne gidin.
  - `+` butonuna basarak `/Applications/Statix.app` uygulamasını ekleyin.
- **Yenileme Sıklığı:**
  - Dashboard üzerindeki ayar simgesine veya sağ tık menüsüne tıklayarak güncelleme aralığını **1 saniye**, **1.5 saniye** veya **3 saniye** olarak değiştirebilirsiniz.
