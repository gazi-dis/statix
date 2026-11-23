#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "SystemMonitor.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, WKScriptMessageHandler, NSPopoverDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *displayMode; // "icon", "cpu", "cpu_ram", "net"
@property (nonatomic, assign) NSTimeInterval updateInterval;

- (void)togglePopover:(id)sender;
- (void)showContextMenu;
- (void)updateStats;

@end
