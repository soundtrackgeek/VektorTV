#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

// The webview keeps keyboard/mouse control while libVLC renders into this view.
@interface VektorVideoView : NSView
@end
@implementation VektorVideoView
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

static NSView *findWebView(NSView *view) {
    if ([view isKindOfClass:NSClassFromString(@"WKWebView")]) return view;
    for (NSView *child in view.subviews) {
        NSView *webView = findWebView(child);
        if (webView) return webView;
    }
    return nil;
}

void *vektor_surface_new(void *parentPointer) {
    NSCAssert([NSThread isMainThread], @"Create the video surface on the main thread");
    // Window content coordinates can include the title bar. DOM rectangles are
    // relative to WKWebView, so the native picture must share that exact parent.
    NSView *parent = findWebView((__bridge NSView *)parentPointer);
    if (!parent) return NULL;
    VektorVideoView *view = [[VektorVideoView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
    view.wantsLayer = YES;
    view.layer.backgroundColor = NSColor.blackColor.CGColor;
    view.hidden = YES;
    [parent addSubview:view positioned:NSWindowAbove relativeTo:nil];
    return (__bridge_retained void *)view;
}

void vektor_surface_hide(void *pointer) {
    NSView *view = (__bridge NSView *)pointer;
    dispatch_async(dispatch_get_main_queue(), ^{ view.hidden = YES; });
}

void vektor_surface_bounds(void *pointer, double x, double y, double width, double height, bool visible) {
    NSView *view = (__bridge NSView *)pointer;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSView *parent = view.superview;
        CGFloat scale = parent.window.backingScaleFactor ?: 1;
        CGFloat top = y / scale;
        CGFloat h = height / scale;
        CGFloat originY = parent.isFlipped ? top : parent.bounds.size.height - top - h;
        view.frame = NSMakeRect(x / scale, originY, MAX(1, width / scale), MAX(1, h));
        view.hidden = !visible;
    });
}

void vektor_surface_destroy(void *pointer) {
    NSView *view = (__bridge_transfer NSView *)pointer;
    dispatch_async(dispatch_get_main_queue(), ^{ [view removeFromSuperview]; });
}
