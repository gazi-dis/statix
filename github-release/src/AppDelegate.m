#import "AppDelegate.h"
#import <ServiceManagement/ServiceManagement.h>

@interface AppDelegate ()
@property (nonatomic, strong) id eventMonitor;
@property (nonatomic, strong) SystemSnapshot *lastSnapshot;
@end

@implementation AppDelegate

static NSString *formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024.0) {
        return [NSString stringWithFormat:@"%.0fB/s", bytesPerSec];
    } else if (bytesPerSec < 1024.0 * 1024.0) {
        return [NSString stringWithFormat:@"%.0fK/s", bytesPerSec / 1024.0];
    } else {
        return [NSString stringWithFormat:@"%.1fM/s", bytesPerSec / (1024.0 * 1024.0)];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // 1. Accessory app (does not appear in the Dock)
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    
    // 2. Load preferences
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.displayMode = [defaults stringForKey:@"StatixDisplayMode"] ?: @"cpu";
    self.tempUnit = [defaults stringForKey:@"StatixTempUnit"] ?: @"C";
    self.language = [defaults stringForKey:@"StatixLanguage"] ?: @"en";
    
    double savedInterval = [defaults doubleForKey:@"StatixUpdateInterval"];
    self.updateInterval = savedInterval > 0.4 ? savedInterval : 1.5;
    
    // 3. Launch at login: DEFAULT IS ENABLED (YES)
    if ([defaults objectForKey:@"StatixLaunchAtLogin"] == nil) {
        [self setLaunchAtLogin:YES];
    } else {
        self.launchAtLogin = [defaults boolForKey:@"StatixLaunchAtLogin"];
        [self syncLaunchAtLoginStatus:self.launchAtLogin];
    }
    
    // 4. Setup Menu Bar Status Item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"menubar_icon" ofType:@"png"];
        NSImage *icon = nil;
        if (iconPath) {
            icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
            [icon setTemplate:YES];
        } else {
            if (@available(macOS 11.0, *)) {
                icon = [NSImage imageWithSystemSymbolName:@"waveform.path.ecg" accessibilityDescription:@"Statix"];
            }
        }
        if (icon) {
            button.image = icon;
            button.imagePosition = NSImageLeft;
        }
        button.title = @" --%";
        button.target = self;
        button.action = @selector(statusItemClicked:);
        [button sendActionOn:(NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp)];
    }
    
    // 5. Setup Popover
    self.popover = [[NSPopover alloc] init];
    self.popover.contentSize = NSMakeSize(380, 580);
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.animates = YES;
    self.popover.delegate = self;
    
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    [config.userContentController addScriptMessageHandler:self name:@"statix"];
    
    NSViewController *vc = [[NSViewController alloc] init];
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 380, 580)];
    
    NSVisualEffectView *vibrantView = [[NSVisualEffectView alloc] initWithFrame:containerView.bounds];
    vibrantView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    vibrantView.material = NSVisualEffectMaterialPopover;
    vibrantView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    vibrantView.state = NSVisualEffectStateActive;
    [containerView addSubview:vibrantView];
    
    self.webView = [[WKWebView alloc] initWithFrame:containerView.bounds configuration:config];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.webView setValue:@NO forKey:@"drawsBackground"];
    [containerView addSubview:self.webView];
    
    vc.view = containerView;
    self.popover.contentViewController = vc;
    
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"web"];
    if (htmlPath) {
        NSURL *fileURL = [NSURL fileURLWithPath:htmlPath];
        NSURL *dirURL = [fileURL URLByDeletingLastPathComponent];
        [self.webView loadFileURL:fileURL allowingReadAccessToURL:dirURL];
    }
    
    // 6. Start polling timer
    [self restartTimer];
    [self updateStats];
}

- (void)restartTimer {
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.updateInterval
                                                  target:self
                                                selector:@selector(updateStats)
                                                userInfo:nil
                                                 repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

#pragma mark - Launch At Login

- (void)setLaunchAtLogin:(BOOL)enabled {
    _launchAtLogin = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"StatixLaunchAtLogin"];
    [self syncLaunchAtLoginStatus:enabled];
    
    NSString *js = [NSString stringWithFormat:@"if (window.onLaunchAtLoginChanged) { window.onLaunchAtLoginChanged(%@); }", enabled ? @"true" : @"false"];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)syncLaunchAtLoginStatus:(BOOL)enabled {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (enabled) {
            if (service.status != SMAppServiceStatusEnabled) {
                [service registerAndReturnError:&error];
            }
        } else {
            if (service.status == SMAppServiceStatusEnabled) {
                [service unregisterAndReturnError:&error];
            }
        }
    }
    
    NSString *agentDir = [@"~/Library/LaunchAgents" stringByExpandingTildeInPath];
    NSString *plistPath = [agentDir stringByAppendingPathComponent:@"com.gazi.statix.plist"];
    
    if (enabled) {
        [[NSFileManager defaultManager] createDirectoryAtPath:agentDir withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *appPath = [[NSBundle mainBundle] bundlePath];
        NSString *execPath = [appPath stringByAppendingPathComponent:@"Contents/MacOS/Statix"];
        
        NSDictionary *plistDict = @{
            @"Label": @"com.gazi.statix",
            @"ProgramArguments": @[execPath],
            @"RunAtLoad": @YES,
            @"ProcessType": @"Interactive"
        };
        [plistDict writeToFile:plistPath atomically:YES];
    } else {
        [[NSFileManager defaultManager] removeItemAtPath:plistPath error:nil];
    }
}

#pragma mark - Status Item & Popover Actions

- (void)statusItemClicked:(id)sender {
    NSEvent *event = [NSApp currentEvent];
    if (event.type == NSEventTypeRightMouseUp || (event.modifierFlags & NSEventModifierFlagControl)) {
        [self showContextMenu];
    } else {
        [self togglePopover:sender];
    }
}

- (void)togglePopover:(id)sender {
    if (self.popover.isShown) {
        [self closePopover:sender];
    } else {
        [self openPopover:sender];
    }
}

- (void)openPopover:(id)sender {
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) return;
    
    [self.popover showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMinY];
    [NSApp activateIgnoringOtherApps:YES];
    
    if (!self.eventMonitor) {
        __weak typeof(self) weakSelf = self;
        self.eventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown)
                                                                   handler:^(NSEvent *event) {
            [weakSelf closePopover:nil];
        }];
    }
    
    [self sendInitialConfigToWeb];
    [self updateStats];
}

- (void)openPopoverWithTab:(NSString *)tab {
    [self openPopover:nil];
    NSString *js = [NSString stringWithFormat:@"if (window.switchMainTab) { window.switchMainTab('%@'); }", tab];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)sendInitialConfigToWeb {
    NSString *js = [NSString stringWithFormat:
        @"if (window.onConfigLoaded) { window.onConfigLoaded({ launchAtLogin: %@, mode: '%@', unit: '%@', interval: %f, language: '%@' }); }",
        self.launchAtLogin ? @"true" : @"false",
        self.displayMode,
        self.tempUnit,
        self.updateInterval,
        self.language ?: @"en"
    ];
    [self.webView evaluateJavaScript:js completionHandler:nil];
}

- (void)closePopover:(id)sender {
    if (self.popover.isShown) {
        [self.popover performClose:sender];
    }
    if (self.eventMonitor) {
        [NSEvent removeMonitor:self.eventMonitor];
        self.eventMonitor = nil;
    }
}

- (void)popoverDidClose:(NSNotification *)notification {
    if (self.eventMonitor) {
        [NSEvent removeMonitor:self.eventMonitor];
        self.eventMonitor = nil;
    }
}

#pragma mark - Periodic Metric Updates

- (double)temperatureForDisplay:(double)celsius {
    if ([self.tempUnit isEqualToString:@"F"]) {
        return (celsius * 9.0 / 5.0) + 32.0;
    }
    return celsius;
}

- (void)updateStats {
    SystemSnapshot *snapshot = [[SystemMonitor sharedMonitor] currentSnapshot];
    self.lastSnapshot = snapshot;
    
    // Update Menu Bar Title
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        double dispTemp = [self temperatureForDisplay:snapshot.cpuTemperature];
        NSString *u = self.tempUnit;
        
        if ([self.displayMode isEqualToString:@"icon"]) {
            button.title = @"";
        } else if ([self.displayMode isEqualToString:@"cpu_ram"]) {
            double ramPercent = snapshot.ramTotalBytes > 0 ? ((double)snapshot.ramUsedBytes / snapshot.ramTotalBytes) * 100.0 : 0.0;
            button.title = [NSString stringWithFormat:@" C:%.0f%% M:%.0f%%", snapshot.cpuTotalPercent, ramPercent];
        } else if ([self.displayMode isEqualToString:@"temp"]) {
            button.title = snapshot.hasTemperature ? [NSString stringWithFormat:@" %.0f°%@", dispTemp, u] : @" --°C";
        } else if ([self.displayMode isEqualToString:@"cpu_temp"]) {
            if (snapshot.hasTemperature) {
                button.title = [NSString stringWithFormat:@" %.0f%% %.0f°%@", snapshot.cpuTotalPercent, dispTemp, u];
            } else {
                button.title = [NSString stringWithFormat:@" %.0f%%", snapshot.cpuTotalPercent];
            }
        } else if ([self.displayMode isEqualToString:@"net"]) {
            button.title = [NSString stringWithFormat:@" ↓%@ ↑%@", formatSpeed(snapshot.networkDownloadSpeed), formatSpeed(snapshot.networkUploadSpeed)];
        } else {
            button.title = [NSString stringWithFormat:@" %.0f%%", snapshot.cpuTotalPercent];
        }
    }
    
    // Update Popover UI if open
    if (self.popover.isShown) {
        NSString *json = [snapshot toJSONString];
        NSString *js = [NSString stringWithFormat:@"if (window.onSystemStatsUpdate) { window.onSystemStatsUpdate(%@, '%@'); }", json, self.tempUnit];
        [self.webView evaluateJavaScript:js completionHandler:nil];
    }
}

- (void)sendPortsToWeb {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *ports = [[SystemMonitor sharedMonitor] listeningPorts];
        NSError *err = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:ports options:0 error:&err];
        NSString *json = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"[]";
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *js = [NSString stringWithFormat:@"if (window.onPortsLoaded) { window.onPortsLoaded(%@); }", json];
            [self.webView evaluateJavaScript:js completionHandler:nil];
        });
    });
}

#pragma mark - WebKit Message Handler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSDictionary class]]) return;
    
    NSDictionary *body = (NSDictionary *)message.body;
    NSString *action = body[@"action"];
    
    if ([action isEqualToString:@"quit"]) {
        [NSApp terminate:nil];
    } else if ([action isEqualToString:@"openActivityMonitor"]) {
        [[NSWorkspace sharedWorkspace] launchApplication:@"Activity Monitor"];
    } else if ([action isEqualToString:@"openURL"]) {
        NSString *urlStr = body[@"url"];
        if (urlStr) {
            NSURL *url = [NSURL URLWithString:urlStr];
            if (url) {
                [[NSWorkspace sharedWorkspace] openURL:url];
            }
        }
    } else if ([action isEqualToString:@"setMode"]) {
        NSString *newMode = body[@"mode"];
        if (newMode) {
            self.displayMode = newMode;
            [[NSUserDefaults standardUserDefaults] setObject:newMode forKey:@"StatixDisplayMode"];
            [self updateStats];
        }
    } else if ([action isEqualToString:@"setTempUnit"]) {
        NSString *newUnit = body[@"unit"];
        if (newUnit) {
            self.tempUnit = newUnit;
            [[NSUserDefaults standardUserDefaults] setObject:newUnit forKey:@"StatixTempUnit"];
            [self updateStats];
        }
    } else if ([action isEqualToString:@"setLanguage"]) {
        NSString *newLang = body[@"language"];
        if (newLang) {
            self.language = newLang;
            [[NSUserDefaults standardUserDefaults] setObject:newLang forKey:@"StatixLanguage"];
            [self updateStats];
        }
    } else if ([action isEqualToString:@"setLaunchAtLogin"]) {
        BOOL enabled = [body[@"enabled"] boolValue];
        [self setLaunchAtLogin:enabled];
    } else if ([action isEqualToString:@"setInterval"]) {
        NSNumber *intervalNum = body[@"interval"];
        if (intervalNum) {
            self.updateInterval = [intervalNum doubleValue];
            [[NSUserDefaults standardUserDefaults] setDouble:self.updateInterval forKey:@"StatixUpdateInterval"];
            [self restartTimer];
        }
    } else if ([action isEqualToString:@"getPorts"]) {
        [self sendPortsToWeb];
    } else if ([action isEqualToString:@"killProcess"]) {
        pid_t pid = [body[@"pid"] intValue];
        int port = [body[@"port"] intValue];
        NSString *err = nil;
        BOOL success = [[SystemMonitor sharedMonitor] killProcessWithPID:pid error:&err];
        
        NSString *js = [NSString stringWithFormat:
            @"if (window.onProcessKilled) { window.onProcessKilled({ success: %@, pid: %d, port: %d, error: '%@' }); }",
            success ? @"true" : @"false",
            pid,
            port,
            err ? [err stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"] : @""
        ];
        [self.webView evaluateJavaScript:js completionHandler:nil];
        
        if (success) {
            // refresh ports after killing
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self sendPortsToWeb];
            });
        }
    } else if ([action isEqualToString:@"getConfig"]) {
        [self sendInitialConfigToWeb];
    } else if ([action isEqualToString:@"refresh"]) {
        [self updateStats];
    }
}

#pragma mark - Right Click Context Menu

static NSString *localizedMenu(NSString *key, NSString *lang) {
    if (!lang) lang = @"en";
    static NSDictionary *strings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        strings = @{
            @"title": @{@"en": @"Statix — System Monitor", @"tr": @"Statix — Sistem Kaynak Takibi", @"de": @"Statix — Systemmonitor", @"es": @"Statix — Monitor del Sistema", @"fr": @"Statix — Moniteur Système"},
            @"dash": @{@"en": @"Open Dashboard", @"tr": @"Dashboard'ı Aç", @"de": @"Dashboard öffnen", @"es": @"Abrir Panel", @"fr": @"Ouvrir le tableau de bord"},
            @"ports": @{@"en": @"Open Port Manager", @"tr": @"Port Yöneticisi'ni Aç", @"de": @"Port-Manager öffnen", @"es": @"Abrir Gestor de Puertos", @"fr": @"Ouvrir le gestionnaire de ports"},
            @"about": @{@"en": @"About Statix", @"tr": @"Statix Hakkında", @"de": @"Über Statix", @"es": @"Acerca de Statix", @"fr": @"À propos de Statix"},
            @"view": @{@"en": @"Menu Bar Display", @"tr": @"Üst Bar Görünümü", @"de": @"Menüleisten-Anzeige", @"es": @"Barra de menú", @"fr": @"Barre des menus"},
            @"mode_icon": @{@"en": @"Icon Only", @"tr": @"Sadece İkon", @"de": @"Nur Symbol", @"es": @"Solo icono", @"fr": @"Icône seule"},
            @"mode_cpu": @{@"en": @"Icon + CPU %", @"tr": @"İkon + CPU %", @"de": @"Symbol + CPU %", @"es": @"Icono + CPU %", @"fr": @"Icône + CPU %"},
            @"mode_cpu_ram": @{@"en": @"Icon + CPU & RAM %", @"tr": @"İkon + CPU & RAM %", @"de": @"Symbol + CPU & RAM %", @"es": @"Icono + CPU & RAM %", @"fr": @"Icône + CPU & RAM %"},
            @"mode_temp": @{@"en": @"Icon + Temp", @"tr": @"İkon + Sıcaklık", @"de": @"Symbol + Temp", @"es": @"Icono + Temp", @"fr": @"Icône + Temp"},
            @"mode_cpu_temp": @{@"en": @"Icon + CPU & Temp", @"tr": @"İkon + CPU & Sıcaklık", @"de": @"Symbol + CPU & Temp", @"es": @"Icono + CPU & Temp", @"fr": @"Icône + CPU & Temp"},
            @"mode_net": @{@"en": @"Icon + Net Speed", @"tr": @"İkon + Ağ Hızı", @"de": @"Symbol + Netztempo", @"es": @"Icono + Vel. Red", @"fr": @"Icône + Vitesse réseau"},
            @"interval": @{@"en": @"Refresh Interval", @"tr": @"Yenileme Hızı", @"de": @"Aktualisierungsintervall", @"es": @"Intervalo de refresco", @"fr": @"Intervalle de rafraîchissement"},
            @"int_1": @{@"en": @"1 Second (Fast)", @"tr": @"1 Saniye (Hızlı)", @"de": @"1 Sekunde (Schnell)", @"es": @"1 Segundo (Rápido)", @"fr": @"1 Seconde (Rapide)"},
            @"int_15": @{@"en": @"1.5 Seconds (Normal)", @"tr": @"1.5 Saniye (Standart)", @"de": @"1.5 Sekunden (Normal)", @"es": @"1.5 Segundos (Normal)", @"fr": @"1.5 Seconde (Normal)"},
            @"int_3": @{@"en": @"3 Seconds (Eco)", @"tr": @"3 Saniye (Eko Mod)", @"de": @"3 Sekunden (Öko)", @"es": @"3 Segundos (Eco)", @"fr": @"3 Secondes (Éco)"},
            @"login": @{@"en": @"Launch at Login", @"tr": @"Girişte Otomatik Başlat", @"de": @"Beim Login starten", @"es": @"Iniciar al arrancar", @"fr": @"Lancer au démarrage"},
            @"am": @{@"en": @"Launch Activity Monitor", @"tr": @"Activity Monitor'ı Başlat", @"de": @"Aktivitätsanzeige öffnen", @"es": @"Abrir Monitor de Actividad", @"fr": @"Lancer le moniteur d'activité"},
            @"quit": @{@"en": @"Quit Statix", @"tr": @"Statix'ten Çık", @"de": @"Statix beenden", @"es": @"Salir de Statix", @"fr": @"Quitter Statix"}
        };
    });
    NSDictionary *entry = strings[key];
    return entry[lang] ?: (entry[@"en"] ?: key);
}

- (void)showContextMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Statix"];
    NSString *lang = self.language ?: @"en";
    
    // Title / Header
    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"title", lang) action:nil keyEquivalent:@""];
    [titleItem setEnabled:NO];
    [menu addItem:titleItem];
    
    // Quick summary
    if (self.lastSnapshot) {
        double ramPercent = self.lastSnapshot.ramTotalBytes > 0 ? ((double)self.lastSnapshot.ramUsedBytes / self.lastSnapshot.ramTotalBytes) * 100.0 : 0.0;
        NSString *tempStr = self.lastSnapshot.hasTemperature ?
            [NSString stringWithFormat:@"(%.0f°%@)", [self temperatureForDisplay:self.lastSnapshot.cpuTemperature], self.tempUnit] : @"";
        
        NSString *summaryStr = [NSString stringWithFormat:@"⚡ CPU: %.1f%% %@  |  💾 RAM: %.1f%%  |  💿 Disk: %.1f%%",
                                self.lastSnapshot.cpuTotalPercent, tempStr, ramPercent, self.lastSnapshot.diskUsedPercent];
        NSMenuItem *sumItem = [[NSMenuItem alloc] initWithTitle:summaryStr action:nil keyEquivalent:@""];
        [sumItem setEnabled:NO];
        [menu addItem:sumItem];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Open Dashboard
    NSMenuItem *dashItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"dash", lang) action:@selector(openDashboardMenuItem:) keyEquivalent:@"d"];
    dashItem.target = self;
    [menu addItem:dashItem];
    
    // Open Ports Manager
    NSMenuItem *portsItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"ports", lang) action:@selector(openPortsMenuItem:) keyEquivalent:@"p"];
    portsItem.target = self;
    [menu addItem:portsItem];
    
    // Open About
    NSMenuItem *aboutItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"about", lang) action:@selector(openAboutMenuItem:) keyEquivalent:@"i"];
    aboutItem.target = self;
    [menu addItem:aboutItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Menu Bar Display Mode Submenu
    NSMenuItem *modeParent = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"view", lang) action:nil keyEquivalent:@""];
    NSMenu *modeSubmenu = [[NSMenu alloc] initWithTitle:localizedMenu(@"view", lang)];
    
    NSArray *modes = @[
        @{@"id": @"icon", @"key": @"mode_icon"},
        @{@"id": @"cpu", @"key": @"mode_cpu"},
        @{@"id": @"cpu_ram", @"key": @"mode_cpu_ram"},
        @{@"id": @"temp", @"key": @"mode_temp"},
        @{@"id": @"cpu_temp", @"key": @"mode_cpu_temp"},
        @{@"id": @"net", @"key": @"mode_net"}
    ];
    for (NSDictionary *m in modes) {
        NSString *title = localizedMenu(m[@"key"], lang);
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(changeModeMenuItem:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = m[@"id"];
        if ([self.displayMode isEqualToString:m[@"id"]]) {
            item.state = NSControlStateValueOn;
        }
        [modeSubmenu addItem:item];
    }
    modeParent.submenu = modeSubmenu;
    [menu addItem:modeParent];
    
    // Refresh Interval Submenu
    NSMenuItem *intervalParent = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"interval", lang) action:nil keyEquivalent:@""];
    NSMenu *intervalSubmenu = [[NSMenu alloc] initWithTitle:localizedMenu(@"interval", lang)];
    
    NSArray *intervals = @[
        @{@"val": @(1.0), @"key": @"int_1"},
        @{@"val": @(1.5), @"key": @"int_15"},
        @{@"val": @(3.0), @"key": @"int_3"}
    ];
    for (NSDictionary *i in intervals) {
        NSString *title = localizedMenu(i[@"key"], lang);
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(changeIntervalMenuItem:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = i[@"val"];
        if (fabs(self.updateInterval - [i[@"val"] doubleValue]) < 0.2) {
            item.state = NSControlStateValueOn;
        }
        [intervalSubmenu addItem:item];
    }
    intervalParent.submenu = intervalSubmenu;
    [menu addItem:intervalParent];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Launch at login toggle item
    NSMenuItem *loginItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"login", lang) action:@selector(toggleLaunchAtLoginMenuItem:) keyEquivalent:@""];
    loginItem.target = self;
    loginItem.state = self.launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:loginItem];
    
    // Activity Monitor
    NSMenuItem *amItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"am", lang) action:@selector(openActivityMonitor:) keyEquivalent:@"a"];
    amItem.target = self;
    [menu addItem:amItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:localizedMenu(@"quit", lang) action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    
    [self.statusItem popUpStatusItemMenu:menu];
}

- (void)openDashboardMenuItem:(id)sender {
    [self openPopoverWithTab:@"dashboard"];
}

- (void)openPortsMenuItem:(id)sender {
    [self openPopoverWithTab:@"ports"];
}

- (void)openAboutMenuItem:(id)sender {
    [self openPopoverWithTab:@"about"];
}

- (void)toggleLaunchAtLoginMenuItem:(NSMenuItem *)sender {
    [self setLaunchAtLogin:!self.launchAtLogin];
}

- (void)changeModeMenuItem:(NSMenuItem *)sender {
    NSString *newMode = (NSString *)sender.representedObject;
    if (newMode) {
        self.displayMode = newMode;
        [[NSUserDefaults standardUserDefaults] setObject:newMode forKey:@"StatixDisplayMode"];
        [self updateStats];
    }
}

- (void)changeIntervalMenuItem:(NSMenuItem *)sender {
    NSNumber *val = (NSNumber *)sender.representedObject;
    if (val) {
        self.updateInterval = [val doubleValue];
        [[NSUserDefaults standardUserDefaults] setDouble:self.updateInterval forKey:@"StatixUpdateInterval"];
        [self restartTimer];
    }
}

- (void)openActivityMonitor:(id)sender {
    [[NSWorkspace sharedWorkspace] launchApplication:@"Activity Monitor"];
}

- (void)quitApp:(id)sender {
    [NSApp terminate:nil];
}

@end
