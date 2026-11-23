// Statix UI Controller
(function() {
  'use strict';

  // State
  let currentStats = null;
  let activeProcTab = 'cpu'; // 'cpu' or 'ram'
  let currentUnit = 'C';
  const sparklineHistory = new Array(35).fill(0);

  // Helper formatters
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

  // DOM Elements
  const el = {
    sysChip: document.getElementById('sysChip'),
    archBadge: document.getElementById('archBadge'),
    uptimeText: document.getElementById('uptimeText'),
    
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

    // Settings
    btnSettings: document.getElementById('btnSettings'),
    settingsDrawer: document.getElementById('settingsDrawer'),
    toggleLaunchAtLogin: document.getElementById('toggleLaunchAtLogin'),
    selectMode: document.getElementById('selectMode'),
    unitControl: document.getElementById('unitControl'),
    intervalControl: document.getElementById('intervalControl'),
    btnActivityMonitor: document.getElementById('btnActivityMonitor'),
    btnQuit: document.getElementById('btnQuit')
  };

  // Canvas Sparkline Setup
  const ctx = el.cpuSparkline ? el.cpuSparkline.getContext('2d') : null;

  function drawSparkline() {
    if (!ctx) return;
    const canvas = el.cpuSparkline;
    const w = canvas.width;
    const h = canvas.height;

    ctx.clearRect(0, 0, w, h);

    if (sparklineHistory.length < 2) return;

    const step = w / (sparklineHistory.length - 1);

    // Draw area fill
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

    // Draw stroke line
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

  // Post message to native host
  function sendNative(action, payload = {}) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.statix) {
      window.webkit.messageHandlers.statix.postMessage(Object.assign({ action: action }, payload));
    } else {
      console.log('[Statix Native Mock]', action, payload);
    }
  }

  // Initial config load from native
  window.onConfigLoaded = function(cfg) {
    if (!cfg) return;
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

  // Main stats update handler called from Objective-C
  window.onSystemStatsUpdate = function(stats, unit) {
    if (!stats) return;
    currentStats = stats;
    if (unit) currentUnit = unit;

    // 1. System Info
    if (stats.system) {
      const cores = stats.cpu ? `${stats.cpu.physicalCores} Çekirdek` : '';
      el.sysChip.textContent = `${stats.cpu?.brand || 'Apple Silicon'} • ${cores}`;
      el.sysChip.title = `${stats.system.hostname} (${stats.system.osVersion})`;
      el.archBadge.textContent = stats.system.architecture || 'Apple Silicon';
      el.uptimeText.textContent = stats.system.uptime || '0 saat';
    }

    // 2. CPU & Temperature
    if (stats.cpu) {
      const total = stats.cpu.totalPercent || 0;
      el.cpuTotalPercent.textContent = total.toFixed(1) + '%';
      el.cpuProgressBar.style.width = Math.min(100, total) + '%';
      el.cpuUserPercent.textContent = (stats.cpu.userPercent || 0).toFixed(1) + '%';
      el.cpuSystemPercent.textContent = (stats.cpu.systemPercent || 0).toFixed(1) + '%';
      el.cpuIdlePercent.textContent = (stats.cpu.idlePercent || 0).toFixed(1) + '%';

      // Push to sparkline
      sparklineHistory.shift();
      sparklineHistory.push(total);
      drawSparkline();

      // Per-core meters
      if (stats.cpu.coresPercent && Array.isArray(stats.cpu.coresPercent)) {
        renderCores(stats.cpu.coresPercent);
      }
    }

    // Temperature display
    if (stats.temperature && stats.temperature.hasTemp) {
      el.cpuTempBadge.style.display = 'flex';
      const dispTemp = convertTemp(stats.temperature.cpuTemp, currentUnit);
      el.cpuTempVal.textContent = `${dispTemp.toFixed(1)}°${currentUnit}`;
      el.cpuTempBadge.title = `Ortalama: ${dispTemp.toFixed(1)}°${currentUnit} | Maks: ${convertTemp(stats.temperature.cpuTempMax, currentUnit).toFixed(1)}°${currentUnit}`;
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
      const pressure = stats.ram.pressure || 'Normal';
      el.ramPressureBadge.textContent = pressure;
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
      el.diskFreeText.textContent = formatBytes(stats.disk.freeBytes) + ' Boş';
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
      el.batterySub.textContent = stats.battery.state || 'Pilde';
      if (stats.battery.timeRemaining > 0) {
        const hrs = Math.floor(stats.battery.timeRemaining / 60);
        const mins = stats.battery.timeRemaining % 60;
        el.batterySub.textContent += ` (${hrs > 0 ? hrs + 's ' : ''}${mins}dk kaldı)`;
      }
    } else {
      el.batteryCard.style.display = 'none';
    }

    // 7. Top Processes
    renderProcesses();
  };

  // Render CPU Cores
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

  // Render Top Processes Table
  function renderProcesses() {
    if (!currentStats || !currentStats.processes) return;
    
    const list = activeProcTab === 'cpu' 
      ? (currentStats.processes.topCpu || []) 
      : (currentStats.processes.topRam || []);

    el.procMetricHeader.textContent = activeProcTab === 'cpu' ? 'CPU %' : 'Bellek (RAM)';

    if (list.length === 0) {
      el.procTableBody.innerHTML = '<tr><td colspan="3" class="proc-loading">Veri bekleniyor...</td></tr>';
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

  function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  // Event Listeners
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

  // Launch at login toggle
  el.toggleLaunchAtLogin.addEventListener('change', (e) => {
    sendNative('setLaunchAtLogin', { enabled: e.target.checked });
  });

  el.selectMode.addEventListener('change', (e) => {
    sendNative('setMode', { mode: e.target.value });
  });

  // Temperature unit selector
  el.unitControl.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => {
      el.unitControl.querySelectorAll('button').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      const unit = btn.dataset.unit;
      currentUnit = unit;
      sendNative('setTempUnit', { unit: unit });
    });
  });

  // Interval selector
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

  // Initial Sparkline Render
  drawSparkline();

  // Request initial config from host
  sendNative('getConfig');

})();
