#import "AppDelegate.h"

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
    double savedInterval = [defaults doubleForKey:@"StatixUpdateInterval"];
    self.updateInterval = savedInterval > 0.4 ? savedInterval : 1.5;
    
    // 3. Setup Menu Bar Status Item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        // Load menu bar icon
        NSString *iconPath = [[NSBundle mainBundle] pathForResource:@"menubar_icon" ofType:@"png"];
        NSImage *icon = nil;
        if (iconPath) {
            icon = [[NSImage alloc] initWithContentsOfFile:iconPath];
            [icon setTemplate:YES];
        } else {
            // Fallback system symbol if available
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
    
    // 4. Setup Popover
    self.popover = [[NSPopover alloc] init];
    self.popover.contentSize = NSMakeSize(380, 580);
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.animates = YES;
    self.popover.delegate = self;
    
    // Setup WKWebView inside Popover
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    [config.userContentController addScriptMessageHandler:self name:@"statix"];
    
    NSViewController *vc = [[NSViewController alloc] init];
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 380, 580)];
    
    // Vibrant frosted glass effect view
    NSVisualEffectView *vibrantView = [[NSVisualEffectView alloc] initWithFrame:containerView.bounds];
    vibrantView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    vibrantView.material = NSVisualEffectMaterialPopover;
    vibrantView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    vibrantView.state = NSVisualEffectStateActive;
    [containerView addSubview:vibrantView];
    
    // WKWebView on top
    self.webView = [[WKWebView alloc] initWithFrame:containerView.bounds configuration:config];
    self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self.webView setValue:@NO forKey:@"drawsBackground"];
    [containerView addSubview:self.webView];
    
    vc.view = containerView;
    self.popover.contentViewController = vc;
    
    // Load local web UI
    NSString *htmlPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"web"];
    if (htmlPath) {
        NSURL *fileURL = [NSURL fileURLWithPath:htmlPath];
        NSURL *dirURL = [fileURL URLByDeletingLastPathComponent];
        [self.webView loadFileURL:fileURL allowingReadAccessToURL:dirURL];
    } else {
        NSLog(@"[Statix] Warning: index.html not found in bundled resources!");
    }
    
    // 5. Start polling timer
    [self restartTimer];
    
    // Initial fetch
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
    
    // Install global monitor to close popover when clicking anywhere else
    if (!self.eventMonitor) {
        __weak typeof(self) weakSelf = self;
        self.eventMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:(NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown)
                                                                   handler:^(NSEvent *event) {
            [weakSelf closePopover:nil];
        }];
    }
    
    // Send immediate update so popover displays fresh stats
    [self updateStats];
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

- (void)updateStats {
    SystemSnapshot *snapshot = [[SystemMonitor sharedMonitor] currentSnapshot];
    self.lastSnapshot = snapshot;
    
    // Update Menu Bar Title
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        if ([self.displayMode isEqualToString:@"icon"]) {
            button.title = @"";
        } else if ([self.displayMode isEqualToString:@"cpu_ram"]) {
            double ramPercent = snapshot.ramTotalBytes > 0 ? ((double)snapshot.ramUsedBytes / snapshot.ramTotalBytes) * 100.0 : 0.0;
            button.title = [NSString stringWithFormat:@" C:%.0f%% M:%.0f%%", snapshot.cpuTotalPercent, ramPercent];
        } else if ([self.displayMode isEqualToString:@"net"]) {
            button.title = [NSString stringWithFormat:@" ↓%@ ↑%@", formatSpeed(snapshot.networkDownloadSpeed), formatSpeed(snapshot.networkUploadSpeed)];
        } else {
            // Default "cpu"
            button.title = [NSString stringWithFormat:@" %.0f%%", snapshot.cpuTotalPercent];
        }
    }
    
    // Update Popover UI if open
    if (self.popover.isShown) {
        NSString *json = [snapshot toJSONString];
        NSString *js = [NSString stringWithFormat:@"if (window.onSystemStatsUpdate) { window.onSystemStatsUpdate(%@); }", json];
        [self.webView evaluateJavaScript:js completionHandler:nil];
    }
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
    } else if ([action isEqualToString:@"setMode"]) {
        NSString *newMode = body[@"mode"];
        if (newMode) {
            self.displayMode = newMode;
            [[NSUserDefaults standardUserDefaults] setObject:newMode forKey:@"StatixDisplayMode"];
            [self updateStats];
        }
    } else if ([action isEqualToString:@"setInterval"]) {
        NSNumber *intervalNum = body[@"interval"];
        if (intervalNum) {
            self.updateInterval = [intervalNum doubleValue];
            [[NSUserDefaults standardUserDefaults] setDouble:self.updateInterval forKey:@"StatixUpdateInterval"];
            [self restartTimer];
        }
    } else if ([action isEqualToString:@"refresh"]) {
        [self updateStats];
    }
}

#pragma mark - Right Click Context Menu

- (void)showContextMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Statix"];
    
    // Title / Header
    NSMenuItem *titleItem = [[NSMenuItem alloc] initWithTitle:@"Statix — Sistem Kaynak Takibi" action:nil keyEquivalent:@""];
    [titleItem setEnabled:NO];
    [menu addItem:titleItem];
    
    // Quick summary
    if (self.lastSnapshot) {
        double ramPercent = self.lastSnapshot.ramTotalBytes > 0 ? ((double)self.lastSnapshot.ramUsedBytes / self.lastSnapshot.ramTotalBytes) * 100.0 : 0.0;
        NSString *summaryStr = [NSString stringWithFormat:@"⚡ CPU: %.1f%%  |  💾 RAM: %.1f%%  |  💿 Disk: %.1f%%",
                                self.lastSnapshot.cpuTotalPercent, ramPercent, self.lastSnapshot.diskUsedPercent];
        NSMenuItem *sumItem = [[NSMenuItem alloc] initWithTitle:summaryStr action:nil keyEquivalent:@""];
        [sumItem setEnabled:NO];
        [menu addItem:sumItem];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Open Dashboard
    NSMenuItem *dashItem = [[NSMenuItem alloc] initWithTitle:@"Dashboard'ı Aç" action:@selector(openPopover:) keyEquivalent:@"d"];
    dashItem.target = self;
    [menu addItem:dashItem];
    
    // Menu Bar Display Mode Submenu
    NSMenuItem *modeParent = [[NSMenuItem alloc] initWithTitle:@"Üst Bar Görünümü" action:nil keyEquivalent:@""];
    NSMenu *modeSubmenu = [[NSMenu alloc] initWithTitle:@"Görünüm"];
    
    NSArray *modes = @[
        @{@"id": @"icon", @"title": @"Sadece İkon"},
        @{@"id": @"cpu", @"title": @"İkon + CPU %"},
        @{@"id": @"cpu_ram", @"title": @"İkon + CPU & RAM %"},
        @{@"id": @"net", @"title": @"İkon + Ağ Hızı"}
    ];
    for (NSDictionary *m in modes) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:m[@"title"] action:@selector(changeModeMenuItem:) keyEquivalent:@""];
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
    NSMenuItem *intervalParent = [[NSMenuItem alloc] initWithTitle:@"Yenileme Hızı" action:nil keyEquivalent:@""];
    NSMenu *intervalSubmenu = [[NSMenu alloc] initWithTitle:@"Hız"];
    
    NSArray *intervals = @[
        @{@"val": @(1.0), @"title": @"1 Saniye (Hızlı)"},
        @{@"val": @(2.0), @"title": @"2 Saniye (Standart)"},
        @{@"val": @(5.0), @"title": @"5 Saniye (Eko Mod)"}
    ];
    for (NSDictionary *i in intervals) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:i[@"title"] action:@selector(changeIntervalMenuItem:) keyEquivalent:@""];
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
    
    // Activity Monitor
    NSMenuItem *amItem = [[NSMenuItem alloc] initWithTitle:@"Activity Monitor'ı Başlat" action:@selector(openActivityMonitor:) keyEquivalent:@"a"];
    amItem.target = self;
    [menu addItem:amItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Statix'ten Çık" action:@selector(quitApp:) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    
    [self.statusItem popUpStatusItemMenu:menu];
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
