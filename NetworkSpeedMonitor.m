#import <Cocoa/Cocoa.h>
#import <ifaddrs.h>
#import <net/if.h>

static NSString *FormatBytes(double value, BOOL perSecond) {
    NSArray *units = @[@"B", @"KB", @"MB", @"GB", @"TB"];
    NSInteger index = 0;
    while (value >= 1024.0 && index < (NSInteger)units.count - 1) { value /= 1024.0; index++; }
    NSString *number = index == 0 ? [NSString stringWithFormat:@"%.0f", value] : [NSString stringWithFormat:@"%.1f", value];
    return [NSString stringWithFormat:@"%@ %@%@", number, units[index], perSecond ? @"/s" : @""];
}

static NSDictionary<NSString *, NSArray<NSNumber *> *> *ReadCounters(void) {
    struct ifaddrs *first = NULL;
    if (getifaddrs(&first) != 0 || !first) return @{};
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    for (struct ifaddrs *item = first; item; item = item->ifa_next) {
        if (!item->ifa_name || !item->ifa_data || !(item->ifa_flags & IFF_UP)) continue;
        NSString *name = [NSString stringWithUTF8String:item->ifa_name];
        if ([name isEqualToString:@"lo0"] || [name hasPrefix:@"gif"] || [name hasPrefix:@"stf"]) continue;
        struct if_data *data = (struct if_data *)item->ifa_data;
        NSArray *value = @[@((uint64_t)data->ifi_ibytes), @((uint64_t)data->ifi_obytes)];
        NSArray *old = result[name];
        if (!old || [value[0] unsignedLongLongValue] + [value[1] unsignedLongLongValue] >
                    [old[0] unsignedLongLongValue] + [old[1] unsignedLongLongValue]) result[name] = value;
    }
    freeifaddrs(first);
    return result;
}

static uint64_t Delta(uint64_t current, uint64_t previous) {
    if (current >= previous) return current - previous;
    if (current <= UINT32_MAX && previous <= UINT32_MAX) return (uint64_t)UINT32_MAX + 1 - previous + current;
    return 0;
}

static NSTextField *Label(NSString *text, CGFloat size, NSColor *color, BOOL bold) {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.textColor = color;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property NSWindow *window;
@property NSTextField *statusLabel;
@property NSTextField *downloadLabel;
@property NSTextField *uploadLabel;
@property NSTextField *totalLabel;
@property NSDictionary *previous;
@property NSTimeInterval previousTime;
@property NSTimer *timer;
@end

@implementation AppDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSColor *background = [NSColor colorWithCalibratedRed:0.067 green:0.094 blue:0.153 alpha:1];
    NSColor *cardColor = [NSColor colorWithCalibratedRed:0.12 green:0.16 blue:0.22 alpha:1];
    NSColor *text = [NSColor colorWithCalibratedWhite:0.97 alpha:1];
    NSColor *muted = [NSColor colorWithCalibratedRed:0.61 green:0.64 blue:0.69 alpha:1];
    NSColor *blue = [NSColor colorWithCalibratedRed:0.22 green:0.74 blue:0.97 alpha:1];
    NSColor *purple = [NSColor colorWithCalibratedRed:0.65 green:0.55 blue:0.98 alpha:1];

    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 620, 330)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"实时网速监控";
    [self.window center];
    NSView *content = self.window.contentView;
    content.wantsLayer = YES; content.layer.backgroundColor = background.CGColor;

    NSTextField *title = Label(@"实时网速", 26, text, YES);
    self.statusLabel = Label(@"正在读取网络数据…", 12, muted, NO);
    self.downloadLabel = Label(@"0 B/s", 27, text, YES);
    self.uploadLabel = Label(@"0 B/s", 27, text, YES);
    self.totalLabel = Label(@"", 11, muted, NO);
    NSTextField *downTitle = Label(@"↓ 下载", 13, blue, YES);
    NSTextField *upTitle = Label(@"↑ 上传", 13, purple, YES);

    NSView *downCard = [NSView new], *upCard = [NSView new];
    for (NSView *card in @[downCard, upCard]) {
        card.translatesAutoresizingMaskIntoConstraints = NO; card.wantsLayer = YES;
        card.layer.backgroundColor = cardColor.CGColor; card.layer.cornerRadius = 12;
        [content addSubview:card];
    }
    for (NSView *view in @[title, self.statusLabel, self.totalLabel]) [content addSubview:view];
    for (NSView *view in @[downTitle, self.downloadLabel]) [downCard addSubview:view];
    for (NSView *view in @[upTitle, self.uploadLabel]) [upCard addSubview:view];

    NSDictionary *views = NSDictionaryOfVariableBindings(title, _statusLabel, downCard, upCard, _totalLabel);
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-28-[title]" options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-28-[_statusLabel]-28-|" options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-28-[downCard(==upCard)]-12-[upCard]-28-|" options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-29-[_totalLabel]-20-|" options:0 metrics:nil views:views]];
    [content addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-25-[title]-5-[_statusLabel]-24-[downCard(130)]-25-[_totalLabel]" options:0 metrics:nil views:views]];
    [content addConstraint:[upCard.topAnchor constraintEqualToAnchor:downCard.topAnchor]];
    [content addConstraint:[upCard.heightAnchor constraintEqualToAnchor:downCard.heightAnchor]];
    for (NSArray *pair in @[@[downCard, downTitle, self.downloadLabel], @[upCard, upTitle, self.uploadLabel]]) {
        NSView *card = pair[0]; NSTextField *heading = pair[1]; NSTextField *value = pair[2];
        [heading.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20].active = YES;
        [heading.topAnchor constraintEqualToAnchor:card.topAnchor constant:20].active = YES;
        [value.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20].active = YES;
        [value.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:17].active = YES;
    }

    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self refresh];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)refresh {
    NSDictionary *current = ReadCounters();
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (!current.count) { self.statusLabel.stringValue = @"读取失败：没有发现网络接口"; return; }
    uint64_t down = 0, up = 0; NSMutableArray *changed = [NSMutableArray array];
    if (self.previous) for (NSString *name in current) {
        NSArray *old = self.previous[name], *value = current[name]; if (!old) continue;
        uint64_t d = Delta([value[0] unsignedLongLongValue], [old[0] unsignedLongLongValue]);
        uint64_t u = Delta([value[1] unsignedLongLongValue], [old[1] unsignedLongLongValue]);
        down += d; up += u; if (d || u) [changed addObject:name];
    }
    double elapsed = self.previousTime ? MAX(now - self.previousTime, 0.001) : 1;
    self.downloadLabel.stringValue = FormatBytes(down / elapsed, YES);
    self.uploadLabel.stringValue = FormatBytes(up / elapsed, YES);
    NSArray *names = changed.count ? [changed sortedArrayUsingSelector:@selector(compare:)] : [[current allKeys] sortedArrayUsingSelector:@selector(compare:)];
    self.statusLabel.stringValue = [@"活动网卡：" stringByAppendingString:[names componentsJoinedByString:@"、"]];
    uint64_t totalDown = 0, totalUp = 0;
    for (NSArray *value in current.allValues) { totalDown += [value[0] unsignedLongLongValue]; totalUp += [value[1] unsignedLongLongValue]; }
    self.totalLabel.stringValue = [NSString stringWithFormat:@"累计：下载 %@  ·  上传 %@", FormatBytes(totalDown, NO), FormatBytes(totalUp, NO)];
    self.previous = current; self.previousTime = now;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

int main(void) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        AppDelegate *delegate = [AppDelegate new]; app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular]; [app run];
    }
    return 0;
}

