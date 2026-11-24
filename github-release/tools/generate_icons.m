#import <Cocoa/Cocoa.h>

void drawMenuBarIcon(int size, NSString *outputPath) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:size
                                                                    pixelsHigh:size
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bytesPerRow:0
                                                                  bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext setCurrentContext:context];
    
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, size, size));
    
    CGFloat s = size;
    [[NSColor blackColor] setStroke];
    
    // Outer rounded rect (chip frame)
    CGFloat pad = s * 0.14;
    NSRect chipRect = NSMakeRect(pad, pad, s - pad * 2, s - pad * 2);
    NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:chipRect xRadius:s*0.14 yRadius:s*0.14];
    border.lineWidth = MAX(1.0, s * 0.08);
    [border stroke];
    
    // ECG / Pulse waveform
    NSBezierPath *pulse = [NSBezierPath bezierPath];
    pulse.lineWidth = MAX(1.0, s * 0.08);
    pulse.lineCapStyle = NSLineCapStyleRound;
    pulse.lineJoinStyle = NSLineJoinStyleRound;
    
    CGFloat midY = s * 0.5;
    [pulse moveToPoint:NSMakePoint(chipRect.origin.x + s*0.08, midY)];
    [pulse lineToPoint:NSMakePoint(chipRect.origin.x + s*0.22, midY)];
    [pulse lineToPoint:NSMakePoint(chipRect.origin.x + s*0.34, midY + s*0.22)];
    [pulse lineToPoint:NSMakePoint(chipRect.origin.x + s*0.44, midY - s*0.22)];
    [pulse lineToPoint:NSMakePoint(chipRect.origin.x + s*0.54, midY)];
    [pulse lineToPoint:NSMakePoint(chipRect.origin.x + chipRect.size.width - s*0.08, midY)];
    [pulse stroke];
    
    [NSGraphicsContext restoreGraphicsState];
    
    NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [pngData writeToFile:outputPath atomically:YES];
}

void drawAppIcon(int size, NSString *outputPath) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                    pixelsWide:size
                                                                    pixelsHigh:size
                                                                 bitsPerSample:8
                                                               samplesPerPixel:4
                                                                      hasAlpha:YES
                                                                      isPlanar:NO
                                                                colorSpaceName:NSDeviceRGBColorSpace
                                                                   bytesPerRow:0
                                                                  bitsPerPixel:0];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext setCurrentContext:context];
    
    CGFloat s = size;
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, s, s));
    
    // Modern macOS Squircle
    NSRect r = NSMakeRect(s * 0.06, s * 0.06, s * 0.88, s * 0.88);
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:r xRadius:s * 0.22 yRadius:s * 0.22];
    
    // Dark tech luxury gradient
    NSGradient *bgGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.04 green:0.07 blue:0.14 alpha:1.0]
                                                       endingColor:[NSColor colorWithCalibratedRed:0.10 green:0.15 blue:0.25 alpha:1.0]];
    [bgGrad drawInBezierPath:bgPath angle:315.0];
    
    // Cyan glow border
    [[NSColor colorWithCalibratedRed:0.22 green:0.74 blue:0.97 alpha:0.5] setStroke];
    bgPath.lineWidth = MAX(1.0, s * 0.025);
    [bgPath stroke];
    
    // Concentric gauge ring
    NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(s*0.22, s*0.22, s*0.56, s*0.56)];
    [[NSColor colorWithCalibratedRed:0.06 green:0.72 blue:0.51 alpha:0.3] setStroke];
    ring.lineWidth = MAX(1.0, s * 0.035);
    [ring stroke];
    
    // Glowing pulse wave
    NSBezierPath *wave = [NSBezierPath bezierPath];
    wave.lineWidth = MAX(1.5, s * 0.05);
    wave.lineCapStyle = NSLineCapStyleRound;
    wave.lineJoinStyle = NSLineJoinStyleRound;
    
    [[NSColor colorWithCalibratedRed:0.22 green:0.74 blue:0.97 alpha:1.0] setStroke];
    [wave moveToPoint:NSMakePoint(s * 0.20, s * 0.5)];
    [wave lineToPoint:NSMakePoint(s * 0.34, s * 0.5)];
    [wave lineToPoint:NSMakePoint(s * 0.44, s * 0.70)];
    [wave lineToPoint:NSMakePoint(s * 0.54, s * 0.30)];
    [wave lineToPoint:NSMakePoint(s * 0.64, s * 0.5)];
    [wave lineToPoint:NSMakePoint(s * 0.80, s * 0.5)];
    [wave stroke];
    
    [NSGraphicsContext restoreGraphicsState];
    
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:outputPath atomically:YES];
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *outDir = @"assets";
        if (argc > 1) {
            outDir = [NSString stringWithUTF8String:argv[1]];
        }
        
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir withIntermediateDirectories:YES attributes:nil error:nil];
        
        // Menu Bar Icons
        drawMenuBarIcon(18, [outDir stringByAppendingPathComponent:@"menubar_icon.png"]);
        drawMenuBarIcon(36, [outDir stringByAppendingPathComponent:@"menubar_icon@2x.png"]);
        
        // App Icons
        drawAppIcon(16,   [outDir stringByAppendingPathComponent:@"icon_16.png"]);
        drawAppIcon(32,   [outDir stringByAppendingPathComponent:@"icon_32.png"]);
        drawAppIcon(64,   [outDir stringByAppendingPathComponent:@"icon_64.png"]);
        drawAppIcon(128,  [outDir stringByAppendingPathComponent:@"icon_128.png"]);
        drawAppIcon(256,  [outDir stringByAppendingPathComponent:@"icon_256.png"]);
        drawAppIcon(512,  [outDir stringByAppendingPathComponent:@"icon_512.png"]);
        drawAppIcon(1024, [outDir stringByAppendingPathComponent:@"icon_1024.png"]);
        
        NSLog(@"Icons rendered successfully in %@", outDir);
    }
    return 0;
}
