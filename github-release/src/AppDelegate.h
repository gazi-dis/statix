#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "SystemMonitor.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler, NSPopoverDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *displayMode; // "icon", "cpu", "cpu_ram", "temp", "cpu_temp", "net"
@property (nonatomic, copy) NSString *tempUnit;    // "C" or "F"
@property (nonatomic, copy) NSString *language;    // "en", "tr", "de", "es", "fr"
@property (nonatomic, assign) NSTimeInterval updateInterval;
@property (nonatomic, assign) BOOL launchAtLogin;

- (void)togglePopover:(id)sender;
- (void)showContextMenu;
- (void)updateStats;
- (void)setLaunchAtLogin:(BOOL)enabled;

@end
