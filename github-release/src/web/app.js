// Statix UI Controller
(function() {
  'use strict';

  // State
  let currentStats = null;
  let currentMainTab = 'dashboard'; // 'dashboard', 'ports', 'about'
  let activeProcTab = 'cpu'; // 'cpu' or 'ram'
  let currentUnit = 'C';
  let currentLang = 'en';
  let loadedPorts = [];
  let pendingKillTimeout = null;
  const sparklineHistory = new Array(35).fill(0);

  // Internationalization Dictionary (en, tr, de, es, fr)
  const i18n = {
    en: {
      tab_system: 'System',
      tab_ports: 'Ports',
      tab_about: 'About',
      settings_title: 'App Preferences',
      lbl_language: 'Language:',
      lbl_launch_at_login: 'Launch at Login:',
      lbl_menubar_display: 'Menu Bar Display:',
      lbl_temp_unit: 'Temperature Unit:',
      lbl_refresh_interval: 'Refresh Interval:',
      mode_cpu: 'Icon + CPU %',
      mode_cpu_temp: 'Icon + CPU & Temp',
      mode_temp: 'Icon + Temp',
      mode_cpu_ram: 'Icon + CPU & RAM %',
      mode_net: 'Icon + Net Speed',
      mode_icon: 'Icon Only',
      card_cpu: 'CPU',
      lbl_user: 'User:',
      lbl_system: 'System:',
      lbl_idle: 'Idle:',
      card_ram: 'MEMORY (RAM)',
      lbl_used: 'Used:',
      lbl_total: 'Total:',
      lbl_pressure: 'Pressure:',
      lbl_wired: 'Wired',
      lbl_active: 'Active',
      lbl_compressed: 'Compressed',
      lbl_free: 'Free',
      card_storage: 'STORAGE',
      card_network: 'NETWORK',
      lbl_session: 'Session:',
      battery_title: 'Battery Level',
      card_top_processes: 'TOP PROCESSES',
      th_app: 'Application / Process',
      th_pid: 'PID',
      th_usage: 'Usage',
      proc_loading: 'Scanning processes...',
      proc_waiting: 'Awaiting data...',
      search_ports_placeholder: 'Filter port or process... (e.g. 3000, node)',
      ports_scanning: 'Scanning active ports...',
      ports_empty_query: 'No listening ports matching your filter.',
      ports_empty_none: 'No listening ports currently.',
      btn_kill: 'Kill',
      btn_kill_confirm: 'Confirm?',
      btn_kill_killing: 'Terminating...',
      btn_kill_tooltip: 'Terminate process holding this port',
      toast_kill_success: (port, pid) => `Port :${port} (PID ${pid}) released successfully.`,
      toast_kill_error: (err) => `Error: ${err || 'Failed to terminate process.'}`,
      about_desc: 'Ultra-lightweight, native system resource and network port manager for macOS Apple Silicon (M1/M2/M3/M4) and Intel.',
      about_section_project: 'PROJECT & CONTACT',
      about_github_title: 'GitHub Repository',
      about_email_title: 'Developer Contact',
      about_btn_open: 'Open ↗',
      about_btn_email: 'Email ✉️',
      about_section_system: 'SYSTEM SUMMARY',
      about_k_cpu: 'Processor',
      about_k_arch: 'Architecture',
      about_k_os: 'Operating System',
      about_k_uptime: 'Uptime',
      about_footer_text: 'Statix is an Open Source Project • MIT License • 2026',
      footer_uptime_lbl: 'Uptime:',
      cores_suffix: 'Cores',
      disk_free_suffix: 'Free',
      battery_charging: 'Charging',
      battery_discharging: 'On Battery',
      battery_ac: 'AC Connected',
      battery_time_left: (hrs, mins) => ` (${hrs > 0 ? hrs + 'h ' : ''}${mins}m left)`,
      pressure_normal: 'Normal',
      pressure_warning: 'Warning',
      pressure_critical: 'Critical',
      temp_tooltip: (avg, max, unit) => `Avg: ${avg}°${unit} | Max: ${max}°${unit}`
    },
    tr: {
      tab_system: 'Sistem',
      tab_ports: 'Portlar',
      tab_about: 'Hakkında',
      settings_title: 'Uygulama Tercihleri',
      lbl_language: 'Dil:',
      lbl_launch_at_login: 'Girişte Otomatik Başlat:',
      lbl_menubar_display: 'Menü Çubuğu Görünümü:',
      lbl_temp_unit: 'Sıcaklık Birimi:',
      lbl_refresh_interval: 'Yenileme Sıklığı:',
      mode_cpu: 'İkon + CPU %',
      mode_cpu_temp: 'İkon + CPU & Sıcaklık',
      mode_temp: 'İkon + Sıcaklık',
      mode_cpu_ram: 'İkon + CPU & RAM %',
      mode_net: 'İkon + Ağ Hızı',
      mode_icon: 'Sadece İkon',
      card_cpu: 'İŞLEMCİ (CPU)',
      lbl_user: 'Kullanıcı:',
      lbl_system: 'Sistem:',
      lbl_idle: 'Boşta:',
      card_ram: 'BELLEK (RAM)',
      lbl_used: 'Kullanılan:',
      lbl_total: 'Toplam:',
      lbl_pressure: 'Baskı:',
      lbl_wired: 'Kablolu',
      lbl_active: 'Aktif',
      lbl_compressed: 'Sıkıştırılmış',
      lbl_free: 'Boş',
      card_storage: 'DEPOLAMA',
      card_network: 'AĞ TRAFİĞİ',
      lbl_session: 'Oturum:',
      battery_title: 'Pil Seviyesi',
      card_top_processes: 'EN ÇOK KAYNAK TÜKETENLER',
      th_app: 'Uygulama / Süreç',
      th_pid: 'PID',
      th_usage: 'Kullanım',
      proc_loading: 'Süreçler taranıyor...',
      proc_waiting: 'Veri bekleniyor...',
      search_ports_placeholder: 'Port veya süreç filtrele... (örn: 3000, node)',
      ports_scanning: 'Aktif portlar taranıyor...',
      ports_empty_query: 'Aramanıza uygun dinlenen port bulunamadı.',
      ports_empty_none: 'Şu anda dinlenen aktif port bulunmuyor.',
      btn_kill: 'Sonlandır',
      btn_kill_confirm: 'Emin misin?',
      btn_kill_killing: 'Sonlandırılıyor...',
      btn_kill_tooltip: 'Portu işgal eden süreci durdur',
      toast_kill_success: (port, pid) => `Port :${port} (PID ${pid}) başarıyla serbest bırakıldı.`,
      toast_kill_error: (err) => `Hata: ${err || 'Süreç sonlandırılamadı.'}`,
      about_desc: 'macOS Apple Silicon (M1/M2/M3/M4) ve Intel işlemciler için ultra hafif, yerel sistem ve port yönetim aracı.',
      about_section_project: 'PROJE & İLETİŞİM',
      about_github_title: 'GitHub Deposu',
      about_email_title: 'Geliştirici İletişim',
      about_btn_open: 'Aç ↗',
      about_btn_email: 'E-posta ✉️',
      about_section_system: 'SİSTEM ÖZETİ',
      about_k_cpu: 'İşlemci',
      about_k_arch: 'Mimari',
      about_k_os: 'İşletim Sistemi',
      about_k_uptime: 'Açık Kalma',
      about_footer_text: 'Statix Açık Kaynaklı Bir Projedir • MIT Lisansı • 2026',
      footer_uptime_lbl: 'Açık Kalma:',
      cores_suffix: 'Çekirdek',
      disk_free_suffix: 'Boş',
      battery_charging: 'Şarj Oluyor',
      battery_discharging: 'Pilde',
      battery_ac: 'Adaptör Bağlı',
      battery_time_left: (hrs, mins) => ` (${hrs > 0 ? hrs + 's ' : ''}${mins}dk kaldı)`,
      pressure_normal: 'Normal',
      pressure_warning: 'Uyarı',
      pressure_critical: 'Kritik',
      temp_tooltip: (avg, max, unit) => `Ortalama: ${avg}°${unit} | Maks: ${max}°${unit}`
    },
    de: {
      tab_system: 'System',
      tab_ports: 'Ports',
      tab_about: 'Über',
      settings_title: 'Einstellungen',
      lbl_language: 'Sprache:',
      lbl_launch_at_login: 'Beim Login starten:',
      lbl_menubar_display: 'Menüleisten-Anzeige:',
      lbl_temp_unit: 'Temperatureinheit:',
      lbl_refresh_interval: 'Aktualisierungsintervall:',
      mode_cpu: 'Symbol + CPU %',
      mode_cpu_temp: 'Symbol + CPU & Temp',
      mode_temp: 'Symbol + Temp',
      mode_cpu_ram: 'Symbol + CPU & RAM %',
      mode_net: 'Symbol + Netztempo',
      mode_icon: 'Nur Symbol',
      card_cpu: 'PROZESSOR (CPU)',
      lbl_user: 'Benutzer:',
      lbl_system: 'System:',
      lbl_idle: 'Leerlauf:',
      card_ram: 'SPEICHER (RAM)',
      lbl_used: 'Verwendet:',
      lbl_total: 'Gesamt:',
      lbl_pressure: 'Druck:',
      lbl_wired: 'Reserviert',
      lbl_active: 'Aktiv',
      lbl_compressed: 'Komprimiert',
      lbl_free: 'Frei',
      card_storage: 'FESTPLATTE',
      card_network: 'NETZWERK',
      lbl_session: 'Sitzung:',
      battery_title: 'Batteriestand',
      card_top_processes: 'TOP PROZESSE',
      th_app: 'App / Prozess',
      th_pid: 'PID',
      th_usage: 'Nutzung',
      proc_loading: 'Prozesse werden gescannt...',
      proc_waiting: 'Warten auf Daten...',
      search_ports_placeholder: 'Port oder Prozess filtern... (z.B. 3000, node)',
      ports_scanning: 'Aktive Ports werden gescannt...',
      ports_empty_query: 'Keine Ports passend zu Ihrer Suche.',
      ports_empty_none: 'Aktuell keine lauschenden Ports vorhanden.',
      btn_kill: 'Beenden',
      btn_kill_confirm: 'Bestätigen?',
      btn_kill_killing: 'Wird beendet...',
      btn_kill_tooltip: 'Diesen Prozess beenden',
      toast_kill_success: (port, pid) => `Port :${port} (PID ${pid}) erfolgreich freigegeben.`,
      toast_kill_error: (err) => `Fehler: ${err || 'Prozess konnte nicht beendet werden.'}`,
      about_desc: 'Ultraschlanker nativer Systemressourcen- und Port-Manager für macOS Apple Silicon (M1–M4) und Intel.',
      about_section_project: 'PROJEKT & KONTAKT',
      about_github_title: 'GitHub-Repository',
      about_email_title: 'Entwicklerkontakt',
      about_btn_open: 'Öffnen ↗',
      about_btn_email: 'E-Mail ✉️',
      about_section_system: 'SYSTEMÜBERSICHT',
      about_k_cpu: 'Prozessor',
      about_k_arch: 'Architektur',
      about_k_os: 'Betriebssystem',
      about_k_uptime: 'Betriebszeit',
      about_footer_text: 'Statix ist ein Open-Source-Projekt • MIT-Lizenz • 2026',
      footer_uptime_lbl: 'Betriebszeit:',
      cores_suffix: 'Kerne',
      disk_free_suffix: 'Frei',
      battery_charging: 'Wird geladen',
      battery_discharging: 'Batteriebetrieb',
      battery_ac: 'Netzteil angeschlossen',
      battery_time_left: (hrs, mins) => ` (${hrs > 0 ? hrs + ' Std ' : ''}${mins} Min verbleibend)`,
      pressure_normal: 'Normal',
      pressure_warning: 'Warnung',
      pressure_critical: 'Kritisch',
      temp_tooltip: (avg, max, unit) => `Mittel: ${avg}°${unit} | Max: ${max}°${unit}`
    },
    es: {
      tab_system: 'Sistema',
      tab_ports: 'Puertos',
      tab_about: 'Acerca de',
      settings_title: 'Preferencias',
      lbl_language: 'Idioma:',
      lbl_launch_at_login: 'Abrir al iniciar sesión:',
      lbl_menubar_display: 'Vista de barra de menús:',
      lbl_temp_unit: 'Unidad de temperatura:',
      lbl_refresh_interval: 'Intervalo de actualización:',
      mode_cpu: 'Icono + CPU %',
      mode_cpu_temp: 'Icono + CPU & Temp',
      mode_temp: 'Icono + Temp',
      mode_cpu_ram: 'Icono + CPU & RAM %',
      mode_net: 'Icono + Vel. Red',
      mode_icon: 'Solo icono',
      card_cpu: 'PROCESADOR (CPU)',
      lbl_user: 'Usuario:',
      lbl_system: 'Sistema:',
      lbl_idle: 'Inactivo:',
      card_ram: 'MEMORIA (RAM)',
      lbl_used: 'Usado:',
      lbl_total: 'Total:',
      lbl_pressure: 'Presión:',
      lbl_wired: 'Fija',
      lbl_active: 'Activa',
      lbl_compressed: 'Comprimida',
      lbl_free: 'Libre',
      card_storage: 'ALMACENAMIENTO',
      card_network: 'RED',
      lbl_session: 'Sesión:',
      battery_title: 'Nivel de Batería',
      card_top_processes: 'PROCESOS PRINCIPALES',
      th_app: 'Aplicación / Proceso',
      th_pid: 'PID',
      th_usage: 'Uso',
      proc_loading: 'Escaneando procesos...',
      proc_waiting: 'Esperando datos...',
      search_ports_placeholder: 'Filtrar puerto o proceso... (ej. 3000, node)',
      ports_scanning: 'Escaneando puertos activos...',
      ports_empty_query: 'No se encontraron puertos con ese filtro.',
      ports_empty_none: 'No hay puertos en escucha actualmente.',
      btn_kill: 'Finalizar',
      btn_kill_confirm: '¿Confirmar?',
      btn_kill_killing: 'Terminando...',
      btn_kill_tooltip: 'Detener el proceso que ocupa este puerto',
      toast_kill_success: (port, pid) => `Puerto :${port} (PID ${pid}) liberado con éxito.`,
      toast_kill_error: (err) => `Error: ${err || 'No se pudo terminar el proceso.'}`,
      about_desc: 'Gestor nativo y ultraligero de recursos del sistema y puertos para macOS Apple Silicon (M1–M4) e Intel.',
      about_section_project: 'PROYECTO & CONTACTO',
      about_github_title: 'Repositorio GitHub',
      about_email_title: 'Contacto de Desarrollador',
      about_btn_open: 'Abrir ↗',
      about_btn_email: 'Correo ✉️',
      about_section_system: 'RESUMEN DEL SISTEMA',
      about_k_cpu: 'Procesador',
      about_k_arch: 'Arquitectura',
      about_k_os: 'Sistema Operativo',
      about_k_uptime: 'Tiempo encendido',
      about_footer_text: 'Statix es un proyecto de código abierto • Licencia MIT • 2026',
      footer_uptime_lbl: 'Tiempo encendido:',
      cores_suffix: 'Núcleos',
      disk_free_suffix: 'Libre',
      battery_charging: 'Cargando',
      battery_discharging: 'En batería',
      battery_ac: 'Conectado a CA',
      battery_time_left: (hrs, mins) => ` (${hrs > 0 ? hrs + 'h ' : ''}${mins}m restante)`,
      pressure_normal: 'Normal',
      pressure_warning: 'Aviso',
      pressure_critical: 'Crítico',
      temp_tooltip: (avg, max, unit) => `Prom: ${avg}°${unit} | Máx: ${max}°${unit}`
    },
    fr: {
      tab_system: 'Système',
      tab_ports: 'Ports',
      tab_about: 'À propos',
      settings_title: 'Préférences',
      lbl_language: 'Langue :',
      lbl_launch_at_login: 'Lancer au démarrage :',
      lbl_menubar_display: 'Affichage barre de menus :',
      lbl_temp_unit: 'Unité de température :',
      lbl_refresh_interval: 'Intervalle de rafraîchissement :',
      mode_cpu: 'Icône + CPU %',
      mode_cpu_temp: 'Icône + CPU & Temp',
      mode_temp: 'Icône + Temp',
      mode_cpu_ram: 'Icône + CPU & RAM %',
      mode_net: 'Icône + Vitesse réseau',
      mode_icon: 'Icône seule',
      card_cpu: 'PROCESSEUR (CPU)',
      lbl_user: 'Utilisateur :',
      lbl_system: 'Système :',
      lbl_idle: 'Inactif :',
      card_ram: 'MÉMOIRE (RAM)',
      lbl_used: 'Utilisée :',
      lbl_total: 'Total :',
      lbl_pressure: 'Pression :',
      lbl_wired: 'Réservée',
      lbl_active: 'Active',
      lbl_compressed: 'Compressée',
      lbl_free: 'Libre',
      card_storage: 'STOCKAGE',
      card_network: 'RÉSEAU',
      lbl_session: 'Session :',
      battery_title: 'Niveau de batterie',
      card_top_processes: 'PROCESSUS PRINCIPAUX',
      th_app: 'Application / Processus',
      th_pid: 'PID',
      th_usage: 'Usage',
      proc_loading: 'Analyse des processus...',
      proc_waiting: 'En attente de données...',
      search_ports_placeholder: 'Filtrer un port ou un processus... (ex. 3000, node)',
      ports_scanning: 'Analyse des ports actifs...',
      ports_empty_query: 'Aucun port correspondant à votre recherche.',
      ports_empty_none: 'Aucun port actif en écoute.',
      btn_kill: 'Arrêter',
      btn_kill_confirm: 'Confirmer ?',
      btn_kill_killing: 'Arrêt en cours...',
      btn_kill_tooltip: 'Arrêter le processus occupant ce port',
      toast_kill_success: (port, pid) => `Port :${port} (PID ${pid}) libéré avec succès.`,
      toast_kill_error: (err) => `Erreur : ${err || "Impossible d'arrêter le processus."}`,
      about_desc: 'Gestionnaire système et de ports réseau ultra-léger et natif pour macOS Apple Silicon (M1–M4) et Intel.',
      about_section_project: 'PROJET & CONTACT',
      about_github_title: 'Dépôt GitHub',
      about_email_title: 'Contact développeur',
      about_btn_open: 'Ouvrir ↗',
      about_btn_email: 'E-mail ✉️',
      about_section_system: 'RÉSUMÉ DU SYSTÈME',
      about_k_cpu: 'Processeur',
      about_k_arch: 'Architecture',
      about_k_os: 'Système d\'exploitation',
      about_k_uptime: 'Temps d\'activité',
      about_footer_text: 'Statix est un projet Open Source • Licence MIT • 2026',
      footer_uptime_lbl: 'Temps d\'activité :',
      cores_suffix: 'Cœurs',
      disk_free_suffix: 'Libre',
      battery_charging: 'En charge',
      battery_discharging: 'Sur batterie',
      battery_ac: 'Adaptateur branché',
      battery_time_left: (hrs, mins) => ` (${hrs > 0 ? hrs + 'h ' : ''}${mins}m restant)`,
      pressure_normal: 'Normal',
      pressure_warning: 'Avertissement',
      pressure_critical: 'Critique',
      temp_tooltip: (avg, max, unit) => `Moy : ${avg}°${unit} | Max : ${max}°${unit}`
    }
  };

  // Translation helper
  function t(key, ...args) {
    const dict = i18n[currentLang] || i18n.en;
    const val = dict[key] !== undefined ? dict[key] : (i18n.en[key] !== undefined ? i18n.en[key] : key);
    if (typeof val === 'function') {
      return val(...args);
    }
    return val;
  }

  function setLanguage(lang) {
    if (!i18n[lang]) lang = 'en';
    currentLang = lang;
    if (el.selectLang) {
      el.selectLang.value = lang;
    }

    // Translate DOM elements marked with data-i18n
    document.querySelectorAll('[data-i18n]').forEach(elem => {
      const key = elem.getAttribute('data-i18n');
      const val = t(key);
      if (val) {
        elem.textContent = val;
      }
    });

    // Translate inputs & tooltips
    if (el.portSearchInput) {
      el.portSearchInput.placeholder = t('search_ports_placeholder');
    }

    // Refresh views if data is present
    if (currentStats) {
      window.onSystemStatsUpdate(currentStats, currentUnit);
    }
    if (currentMainTab === 'ports') {
      renderPorts();
    }
  }

  // Formatters
  function formatBytes(bytes, decimals = 1) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
  }

  function formatSpeed(bytesPerSec) {
    if (!bytesPerSec || bytesPerSec <= 0) return '0 B/s';
    if (bytesPerSec < 1024) return Math.round(bytesPerSec) + ' B/s';
    if (bytesPerSec < 1024 * 1024) return (bytesPerSec / 1024).toFixed(1) + ' KB/s';
    return (bytesPerSec / (1024 * 1024)).toFixed(1) + ' MB/s';
  }

  function convertTemp(celsius, unit) {
    if (unit === 'F') {
      return (celsius * 9.0 / 5.0) + 32.0;
    }
    return celsius;
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // DOM Elements Cache
  const el = {
    // Header & Nav
    sysChip: document.getElementById('sysChip'),
    archBadge: document.getElementById('archBadge'),
    uptimeText: document.getElementById('uptimeText'),
    mainTabs: document.querySelectorAll('.main-tab'),
    viewDashboard: document.getElementById('viewDashboard'),
    viewPorts: document.getElementById('viewPorts'),
    viewAbout: document.getElementById('viewAbout'),
    portsBadge: document.getElementById('portsBadge'),

    // Settings
    btnSettings: document.getElementById('btnSettings'),
    settingsDrawer: document.getElementById('settingsDrawer'),
    selectLang: document.getElementById('selectLang'),
    toggleLaunchAtLogin: document.getElementById('toggleLaunchAtLogin'),
    selectMode: document.getElementById('selectMode'),
    unitControl: document.getElementById('unitControl'),
    intervalControl: document.getElementById('intervalControl'),
    btnActivityMonitor: document.getElementById('btnActivityMonitor'),
    btnQuit: document.getElementById('btnQuit'),

    // CPU
    cpuTotalPercent: document.getElementById('cpuTotalPercent'),
    cpuProgressBar: document.getElementById('cpuProgressBar'),
    cpuUserPercent: document.getElementById('cpuUserPercent'),
    cpuSystemPercent: document.getElementById('cpuSystemPercent'),
    cpuIdlePercent: document.getElementById('cpuIdlePercent'),
    cpuSparkline: document.getElementById('cpuSparkline'),
    coresContainer: document.getElementById('coresContainer'),
    cpuTempBadge: document.getElementById('cpuTempBadge'),
    cpuTempVal: document.getElementById('cpuTempVal'),

    // RAM
    ramPercentText: document.getElementById('ramPercentText'),
    ramSegWired: document.getElementById('ramSegWired'),
    ramSegActive: document.getElementById('ramSegActive'),
    ramSegCompressed: document.getElementById('ramSegCompressed'),
    ramSegFree: document.getElementById('ramSegFree'),
    ramUsedVal: document.getElementById('ramUsedVal'),
    ramTotalVal: document.getElementById('ramTotalVal'),
    ramPressureBadge: document.getElementById('ramPressureBadge'),
    swapPill: document.getElementById('swapPill'),

    // Disk
    diskPercent: document.getElementById('diskPercent'),
    diskProgressBar: document.getElementById('diskProgressBar'),
    diskFreeText: document.getElementById('diskFreeText'),
    diskTotalText: document.getElementById('diskTotalText'),

    // Network
    netDownSpeed: document.getElementById('netDownSpeed'),
    netUpSpeed: document.getElementById('netUpSpeed'),
    netTotalText: document.getElementById('netTotalText'),

    // Battery
    batteryCard: document.getElementById('batteryCard'),
    batteryTitle: document.getElementById('batteryTitle'),
    batterySub: document.getElementById('batterySub'),
    batteryPercent: document.getElementById('batteryPercent'),
    batteryProgressBar: document.getElementById('batteryProgressBar'),

    // Processes
    tabCpu: document.getElementById('tabCpu'),
    tabRam: document.getElementById('tabRam'),
    procMetricHeader: document.getElementById('procMetricHeader'),
    procTableBody: document.getElementById('procTableBody'),

    // Ports
    portSearchInput: document.getElementById('portSearchInput'),
    btnClearSearch: document.getElementById('btnClearSearch'),
    btnRefreshPorts: document.getElementById('btnRefreshPorts'),
    portsList: document.getElementById('portsList'),
    toastBanner: document.getElementById('toastBanner'),

    // About
    btnOpenGithub: document.getElementById('btnOpenGithub'),
    btnOpenEmail: document.getElementById('btnOpenEmail'),
    aboutCpu: document.getElementById('aboutCpu'),
    aboutArch: document.getElementById('aboutArch'),
    aboutOS: document.getElementById('aboutOS'),
    aboutUptime: document.getElementById('aboutUptime')
  };

  // Sparkline Setup
  const ctx = el.cpuSparkline ? el.cpuSparkline.getContext('2d') : null;

  function drawSparkline() {
    if (!ctx) return;
    const canvas = el.cpuSparkline;
    const w = canvas.width;
    const h = canvas.height;

    ctx.clearRect(0, 0, w, h);
    if (sparklineHistory.length < 2) return;

    const step = w / (sparklineHistory.length - 1);

    // Area fill
    ctx.beginPath();
    ctx.moveTo(0, h);

    for (let i = 0; i < sparklineHistory.length; i++) {
      const val = Math.min(100, Math.max(0, sparklineHistory[i]));
      const y = h - (val / 100) * (h - 6) - 3;
      if (i === 0) {
        ctx.lineTo(0, y);
      } else {
        const prevVal = sparklineHistory[i - 1];
        const prevY = h - (prevVal / 100) * (h - 6) - 3;
        const cx = (i - 0.5) * step;
        ctx.bezierCurveTo(cx, prevY, cx, y, i * step, y);
      }
    }

    ctx.lineTo(w, h);
    ctx.closePath();

    const gradient = ctx.createLinearGradient(0, 0, 0, h);
    gradient.addColorStop(0, 'rgba(56, 189, 248, 0.45)');
    gradient.addColorStop(1, 'rgba(56, 189, 248, 0.02)');
    ctx.fillStyle = gradient;
    ctx.fill();

    // Line stroke
    ctx.beginPath();
    for (let i = 0; i < sparklineHistory.length; i++) {
      const val = Math.min(100, Math.max(0, sparklineHistory[i]));
      const y = h - (val / 100) * (h - 6) - 3;
      if (i === 0) {
        ctx.moveTo(0, y);
      } else {
        const prevVal = sparklineHistory[i - 1];
        const prevY = h - (prevVal / 100) * (h - 6) - 3;
        const cx = (i - 0.5) * step;
        ctx.bezierCurveTo(cx, prevY, cx, y, i * step, y);
      }
    }
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 1.8;
    ctx.shadowColor = 'rgba(56, 189, 248, 0.8)';
    ctx.shadowBlur = 4;
    ctx.stroke();
    ctx.shadowBlur = 0;
  }

  // Host bridge
  function sendNative(action, payload = {}) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.statix) {
      window.webkit.messageHandlers.statix.postMessage(Object.assign({ action: action }, payload));
    } else {
      console.log('[Statix Native Mock]', action, payload);
    }
  }

  // Tab Switching
  window.switchMainTab = function(tabName) {
    currentMainTab = tabName;
    el.mainTabs.forEach(b => {
      b.classList.toggle('active', b.dataset.tab === tabName);
    });

    el.viewDashboard.style.display = tabName === 'dashboard' ? 'flex' : 'none';
    el.viewPorts.style.display = tabName === 'ports' ? 'flex' : 'none';
    el.viewAbout.style.display = tabName === 'about' ? 'block' : 'none';

    if (tabName === 'ports') {
      sendNative('getPorts');
    }
  };

  el.mainTabs.forEach(btn => {
    btn.addEventListener('click', () => {
      window.switchMainTab(btn.dataset.tab);
    });
  });

  // Config loaded from native host
  window.onConfigLoaded = function(cfg) {
    if (!cfg) return;
    if (cfg.language) {
      setLanguage(cfg.language);
    } else {
      setLanguage('en');
    }
    if (cfg.launchAtLogin !== undefined && el.toggleLaunchAtLogin) {
      el.toggleLaunchAtLogin.checked = !!cfg.launchAtLogin;
    }
    if (cfg.mode && el.selectMode) {
      el.selectMode.value = cfg.mode;
    }
    if (cfg.unit) {
      currentUnit = cfg.unit;
      el.unitControl.querySelectorAll('button').forEach(b => {
        b.classList.toggle('active', b.dataset.unit === cfg.unit);
      });
    }
    if (cfg.interval && el.intervalControl) {
      el.intervalControl.querySelectorAll('button').forEach(b => {
        const diff = Math.abs(parseFloat(b.dataset.interval) - cfg.interval);
        b.classList.toggle('active', diff < 0.2);
      });
    }
  };

  window.onLaunchAtLoginChanged = function(enabled) {
    if (el.toggleLaunchAtLogin) {
      el.toggleLaunchAtLogin.checked = !!enabled;
    }
  };

  // Main system metrics update
  window.onSystemStatsUpdate = function(stats, unit) {
    if (!stats) return;
    currentStats = stats;
    if (unit) currentUnit = unit;

    // 1. System Info
    if (stats.system) {
      const cores = stats.cpu ? `${stats.cpu.physicalCores} ${t('cores_suffix')}` : '';
      el.sysChip.textContent = `${stats.cpu?.brand || 'Apple Silicon'} • ${cores}`;
      el.sysChip.title = `${stats.system.hostname} (${stats.system.osVersion})`;
      el.archBadge.textContent = stats.system.architecture || 'Apple Silicon';
      el.uptimeText.textContent = stats.system.uptime || '0h';

      // Update about screen fields
      if (el.aboutCpu) el.aboutCpu.textContent = `${stats.cpu?.brand || 'Apple'} (${stats.cpu?.physicalCores || 8} ${t('cores_suffix')})`;
      if (el.aboutArch) el.aboutArch.textContent = stats.system.architecture || 'Universal';
      if (el.aboutOS) el.aboutOS.textContent = stats.system.osVersion || 'macOS';
      if (el.aboutUptime) el.aboutUptime.textContent = stats.system.uptime || '-';
    }

    // 2. CPU & Temperature
    if (stats.cpu) {
      const total = stats.cpu.totalPercent || 0;
      el.cpuTotalPercent.textContent = total.toFixed(1) + '%';
      el.cpuProgressBar.style.width = Math.min(100, total) + '%';
      el.cpuUserPercent.textContent = (stats.cpu.userPercent || 0).toFixed(1) + '%';
      el.cpuSystemPercent.textContent = (stats.cpu.systemPercent || 0).toFixed(1) + '%';
      el.cpuIdlePercent.textContent = (stats.cpu.idlePercent || 0).toFixed(1) + '%';

      // Sparkline
      sparklineHistory.shift();
      sparklineHistory.push(total);
      if (currentMainTab === 'dashboard') {
        drawSparkline();
      }

      // Per-core meters
      if (stats.cpu.coresPercent && Array.isArray(stats.cpu.coresPercent)) {
        renderCores(stats.cpu.coresPercent);
      }
    }

    // Temperature display
    if (stats.temperature && stats.temperature.hasTemp) {
      el.cpuTempBadge.style.display = 'flex';
      const dispTemp = convertTemp(stats.temperature.cpuTemp, currentUnit);
      const maxTemp = convertTemp(stats.temperature.cpuTempMax, currentUnit);
      el.cpuTempVal.textContent = `${dispTemp.toFixed(1)}°${currentUnit}`;
      el.cpuTempBadge.title = t('temp_tooltip', dispTemp.toFixed(1), maxTemp.toFixed(1), currentUnit);
    } else {
      el.cpuTempBadge.style.display = 'none';
    }

    // 3. RAM
    if (stats.ram && stats.ram.totalBytes > 0) {
      const total = stats.ram.totalBytes;
      const used = stats.ram.usedBytes || 0;
      const usedPct = ((used / total) * 100);

      el.ramPercentText.textContent = usedPct.toFixed(1) + '%';
      el.ramUsedVal.textContent = formatBytes(used);
      el.ramTotalVal.textContent = formatBytes(total);

      // Segments
      const wiredPct = ((stats.ram.wiredBytes || 0) / total) * 100;
      const activePct = ((stats.ram.activeBytes || 0) / total) * 100;
      const compressedPct = ((stats.ram.compressedBytes || 0) / total) * 100;
      const freePct = Math.max(0, 100 - (wiredPct + activePct + compressedPct));

      el.ramSegWired.style.width = wiredPct + '%';
      el.ramSegActive.style.width = activePct + '%';
      el.ramSegCompressed.style.width = compressedPct + '%';
      el.ramSegFree.style.width = freePct + '%';

      // Pressure badge
      const pressure = (stats.ram.pressure || 'Normal');
      let presKey = 'pressure_normal';
      if (pressure.toLowerCase() === 'warning') presKey = 'pressure_warning';
      if (pressure.toLowerCase() === 'critical') presKey = 'pressure_critical';
      el.ramPressureBadge.textContent = t(presKey);
      el.ramPressureBadge.className = 'badge';
      if (pressure.toLowerCase() === 'warning') el.ramPressureBadge.classList.add('warning');
      if (pressure.toLowerCase() === 'critical') el.ramPressureBadge.classList.add('critical');

      // Swap
      if (stats.ram.swapUsedBytes > 0) {
        el.swapPill.textContent = 'Swap: ' + formatBytes(stats.ram.swapUsedBytes);
        el.swapPill.style.display = 'inline-block';
      } else {
        el.swapPill.textContent = 'Swap: 0 MB';
      }
    }

    // 4. Disk
    if (stats.disk) {
      const diskPct = stats.disk.usedPercent || 0;
      el.diskPercent.textContent = diskPct.toFixed(1) + '%';
      el.diskProgressBar.style.width = Math.min(100, diskPct) + '%';
      el.diskFreeText.textContent = formatBytes(stats.disk.freeBytes) + ' ' + t('disk_free_suffix');
      el.diskTotalText.textContent = '/ ' + formatBytes(stats.disk.totalBytes);
    }

    // 5. Network
    if (stats.network) {
      el.netDownSpeed.textContent = formatSpeed(stats.network.downloadSpeed);
      el.netUpSpeed.textContent = formatSpeed(stats.network.uploadSpeed);

      const totalTraffic = (stats.network.totalBytesIn || 0) + (stats.network.totalBytesOut || 0);
      el.netTotalText.textContent = formatBytes(totalTraffic);
    }

    // 6. Battery
    if (stats.battery && stats.battery.hasBattery) {
      el.batteryCard.style.display = 'flex';
      el.batteryPercent.textContent = stats.battery.percent + '%';
      el.batteryProgressBar.style.width = stats.battery.percent + '%';

      let stateText = t('battery_discharging');
      const st = (stats.battery.state || '').toLowerCase();
      if (st.includes('charg') || st.includes('şarj') || st.includes('laden')) {
        stateText = t('battery_charging');
      } else if (st.includes('ac') || st.includes('adaptör') || st.includes('netz') || st.includes('branch')) {
        stateText = t('battery_ac');
      }

      el.batterySub.textContent = stateText;
      if (stats.battery.timeRemaining > 0) {
        const hrs = Math.floor(stats.battery.timeRemaining / 60);
        const mins = stats.battery.timeRemaining % 60;
        el.batterySub.textContent += t('battery_time_left', hrs, mins);
      }
    } else {
      el.batteryCard.style.display = 'none';
    }

    // 7. Top Processes
    if (currentMainTab === 'dashboard') {
      renderProcesses();
    }
  };

  function renderCores(cores) {
    if (!el.coresContainer) return;
    if (el.coresContainer.children.length !== cores.length) {
      el.coresContainer.innerHTML = '';
      el.coresContainer.style.gridTemplateColumns = `repeat(${cores.length}, 1fr)`;
      
      for (let i = 0; i < cores.length; i++) {
        const item = document.createElement('div');
        item.className = 'core-item';
        item.innerHTML = `
          <div class="core-meter">
            <div class="core-meter-fill" id="coreFill${i}" style="height: 0%"></div>
          </div>
          <span class="core-label">C${i+1}</span>
        `;
        el.coresContainer.appendChild(item);
      }
    }

    for (let i = 0; i < cores.length; i++) {
      const fill = document.getElementById(`coreFill${i}`);
      if (fill) {
        const pct = Math.min(100, Math.max(0, cores[i]));
        fill.style.height = pct + '%';
      }
    }
  }

  function renderProcesses() {
    if (!currentStats || !currentStats.processes) return;
    
    const list = activeProcTab === 'cpu' 
      ? (currentStats.processes.topCpu || []) 
      : (currentStats.processes.topRam || []);

    el.procMetricHeader.textContent = activeProcTab === 'cpu' ? 'CPU %' : t('card_ram');

    if (list.length === 0) {
      el.procTableBody.innerHTML = `<tr><td colspan="3" class="proc-loading">${t('proc_waiting')}</td></tr>`;
      return;
    }

    let html = '';
    list.forEach(p => {
      const valStr = activeProcTab === 'cpu' 
        ? `${p.cpu.toFixed(1)}%` 
        : `${p.ramMB} MB`;

      html += `
        <tr>
          <td>
            <span class="proc-name" title="${escapeHtml(p.name)}">${escapeHtml(p.name)}</span>
          </td>
          <td class="proc-pid">${p.pid}</td>
          <td class="proc-metric">${valStr}</td>
        </tr>
      `;
    });

    el.procTableBody.innerHTML = html;
  }

  // ==========================================================================
  // PORT MANAGER LOGIC
  // ==========================================================================

  window.onPortsLoaded = function(ports) {
    loadedPorts = Array.isArray(ports) ? ports : [];
    if (el.portsBadge) {
      el.portsBadge.textContent = loadedPorts.length;
    }
    renderPorts();
  };

  function renderPorts() {
    if (!el.portsList) return;
    const query = (el.portSearchInput.value || '').trim().toLowerCase();

    let filtered = loadedPorts;
    if (query) {
      filtered = loadedPorts.filter(p => {
        const portStr = String(p.port);
        const pidStr = String(p.pid);
        const cmd = (p.command || '').toLowerCase();
        const addr = (p.address || '').toLowerCase();
        const path = (p.path || '').toLowerCase();
        return portStr.includes(query) || pidStr.includes(query) || cmd.includes(query) || addr.includes(query) || path.includes(query);
      });
    }

    if (filtered.length === 0) {
      el.portsList.innerHTML = `
        <div class="ports-empty">
          ${query ? t('ports_empty_query') : t('ports_empty_none')}
        </div>
      `;
      return;
    }

    let html = '';
    filtered.forEach(p => {
      const tooltip = p.path ? `${escapeHtml(p.command)} (${escapeHtml(p.path)})` : escapeHtml(p.command);
      html += `
        <div class="port-card" data-pid="${p.pid}" data-port="${p.port}">
          <div class="port-card-left">
            <div class="port-badge">:${p.port}</div>
            <div class="port-card-meta">
              <div class="port-cmd-row">
                <span class="port-cmd" title="${tooltip}">${escapeHtml(p.command)}</span>
                <span class="port-pid">PID: ${p.pid}</span>
              </div>
              <div class="port-addr" title="${escapeHtml(p.address)}">${escapeHtml(p.address)}</div>
            </div>
          </div>
          <button class="btn-kill" data-pid="${p.pid}" data-port="${p.port}" data-cmd="${escapeHtml(p.command)}" title="${t('btn_kill_tooltip')}">
            ${t('btn_kill')}
          </button>
        </div>
      `;
    });

    el.portsList.innerHTML = html;

    // Attach kill listeners
    el.portsList.querySelectorAll('.btn-kill').forEach(btn => {
      btn.addEventListener('click', handleKillButtonClick);
    });
  }

  function handleKillButtonClick(e) {
    const btn = e.currentTarget;
    const pid = parseInt(btn.dataset.pid, 10);
    const port = parseInt(btn.dataset.port, 10);
    const cmd = btn.dataset.cmd;

    if (!btn.classList.contains('confirm')) {
      // First click: Request confirmation
      btn.classList.add('confirm');
      btn.textContent = t('btn_kill_confirm');

      if (pendingKillTimeout) clearTimeout(pendingKillTimeout);
      pendingKillTimeout = setTimeout(() => {
        btn.classList.remove('confirm');
        btn.textContent = t('btn_kill');
      }, 3500);
    } else {
      // Confirmed click: Execute kill
      btn.classList.remove('confirm');
      btn.textContent = t('btn_kill_killing');
      btn.disabled = true;

      sendNative('killProcess', { pid: pid, port: port, command: cmd });
    }
  }

  window.onProcessKilled = function(res) {
    if (!res) return;
    const toast = el.toastBanner;
    if (!toast) return;

    toast.style.display = 'block';
    if (res.success) {
      toast.className = 'toast-banner toast-success';
      toast.textContent = `✅ ${t('toast_kill_success', res.port, res.pid)}`;
    } else {
      toast.className = 'toast-banner toast-error';
      toast.textContent = `❌ ${t('toast_kill_error', res.error)}`;
    }

    setTimeout(() => {
      toast.style.display = 'none';
    }, 4000);
  };

  // Search input events
  if (el.portSearchInput) {
    el.portSearchInput.addEventListener('input', () => {
      const val = el.portSearchInput.value.trim();
      el.btnClearSearch.style.display = val.length > 0 ? 'block' : 'none';
      renderPorts();
    });
  }

  if (el.btnClearSearch) {
    el.btnClearSearch.addEventListener('click', () => {
      el.portSearchInput.value = '';
      el.btnClearSearch.style.display = 'none';
      renderPorts();
    });
  }

  if (el.btnRefreshPorts) {
    el.btnRefreshPorts.addEventListener('click', () => {
      el.btnRefreshPorts.style.transform = 'rotate(180deg)';
      setTimeout(() => { el.btnRefreshPorts.style.transform = 'none'; }, 300);
      sendNative('getPorts');
    });
  }

  // ==========================================================================
  // ABOUT LINKS
  // ==========================================================================
  if (el.btnOpenGithub) {
    el.btnOpenGithub.addEventListener('click', () => {
      sendNative('openURL', { url: 'https://github.com/gazi-dis/statix' });
    });
  }

  if (el.btnOpenEmail) {
    el.btnOpenEmail.addEventListener('click', () => {
      sendNative('openURL', { url: 'mailto:gazidis60@gmail.com' });
    });
  }

  // Event Listeners for dashboard
  el.tabCpu.addEventListener('click', () => {
    activeProcTab = 'cpu';
    el.tabCpu.classList.add('active');
    el.tabRam.classList.remove('active');
    renderProcesses();
  });

  el.tabRam.addEventListener('click', () => {
    activeProcTab = 'ram';
    el.tabRam.classList.add('active');
    el.tabCpu.classList.remove('active');
    renderProcesses();
  });

  el.btnSettings.addEventListener('click', () => {
    el.settingsDrawer.classList.toggle('open');
  });

  if (el.selectLang) {
    el.selectLang.addEventListener('change', (e) => {
      const newLang = e.target.value;
      setLanguage(newLang);
      sendNative('setLanguage', { language: newLang });
    });
  }

  el.toggleLaunchAtLogin.addEventListener('change', (e) => {
    sendNative('setLaunchAtLogin', { enabled: e.target.checked });
  });

  el.selectMode.addEventListener('change', (e) => {
    sendNative('setMode', { mode: e.target.value });
  });

  el.unitControl.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => {
      el.unitControl.querySelectorAll('button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const unit = btn.dataset.unit;
      currentUnit = unit;
      sendNative('setTempUnit', { unit: unit });
    });
  });

  el.intervalControl.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => {
      el.intervalControl.querySelectorAll('button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const val = parseFloat(btn.dataset.interval);
      sendNative('setInterval', { interval: val });
    });
  });

  el.btnActivityMonitor.addEventListener('click', () => {
    sendNative('openActivityMonitor');
  });

  el.btnQuit.addEventListener('click', () => {
    sendNative('quit');
  });

  // Initial draw & initial config
  drawSparkline();
  sendNative('getConfig');

})();
