#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

@interface ProbeViewController : UIViewController
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *counterLabel;
@property(nonatomic, copy) NSString *lifecycleState;
@property(nonatomic) NSUInteger touchCount;
@property(nonatomic) NSUInteger resumeCount;
- (void)refreshStatus;
@end

@implementation ProbeViewController
- (UILabel *)labelWithText:(NSString *)text style:(UIFontTextStyle)style {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.numberOfLines = 0;
    label.font = [UIFont preferredFontForTextStyle:style];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = UIColor.labelColor;
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    if (!self.lifecycleState) self.lifecycleState = @"Indulás";

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:stack];
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48]
    ]];
    UILabel *heading = [self labelWithText:@"Sorin2 Origins\niOS próba" style:UIFontTextStyleLargeTitle];
    heading.accessibilityTraits |= UIAccessibilityTraitHeader;
    [stack addArrangedSubview:heading];
    [stack addArrangedSubview:[self labelWithText:@"Önálló helyi próbaalkalmazás. Ez még nem a játékkliens." style:UIFontTextStyleBody]];
    self.statusLabel = [self labelWithText:@"" style:UIFontTextStyleHeadline];
    self.statusLabel.accessibilityIdentifier = @"lifecycle_status";
    [stack addArrangedSubview:self.statusLabel];

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    NSString *metalText = device ? [NSString stringWithFormat:@"Metal eszköz elérhető: %@\nRenderelési próba még nem történt.", device.name]
                                 : @"Metal eszköz nem érhető el.\nEz nem grafikai teljesítménymérés.";
    [stack addArrangedSubview:[self labelWithText:metalText style:UIFontTextStyleBody]];
    self.counterLabel = [self labelWithText:@"" style:UIFontTextStyleTitle2];
    self.counterLabel.accessibilityIdentifier = @"touch_count";
    [stack addArrangedSubview:self.counterLabel];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = @"Érintés hozzáadása";
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(16, 12, 16, 12);
    button.configuration = configuration;
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.accessibilityIdentifier = @"increment_button";
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
    [button addTarget:self action:@selector(incrementCounter:) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:button];
    [stack addArrangedSubview:[self labelWithText:@"Próba: érintsd meg a gombot, lépj a kezdőképernyőre, majd térj vissza. A számláló a futó alkalmazásban megmarad; újraindításkor nullázódik." style:UIFontTextStyleBody]];
    [self refreshStatus];
}

- (void)incrementCounter:(UIButton *)sender {
    (void)sender;
    self.touchCount += 1;
    [self refreshStatus];
}

- (void)refreshStatus {
    self.statusLabel.text = [NSString stringWithFormat:@"Állapot: %@\nVisszatérések háttérből: %lu", self.lifecycleState ?: @"Indulás", (unsigned long)self.resumeCount];
    self.counterLabel.text = [NSString stringWithFormat:@"Érintések: %lu", (unsigned long)self.touchCount];
}
@end

@interface ProbeSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) ProbeViewController *probe;
@property(nonatomic) BOOL hasEnteredBackground;
@end

@implementation ProbeSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    (void)session;
    (void)connectionOptions;
    if (![scene isKindOfClass:UIWindowScene.class]) return;
    self.probe = [[ProbeViewController alloc] init];
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = self.probe;
    [self.window makeKeyAndVisible];
}
- (void)sceneDidBecomeActive:(UIScene *)scene {
    (void)scene;
    self.probe.lifecycleState = @"Aktív / előtérben";
    [self.probe refreshStatus];
}
- (void)sceneWillResignActive:(UIScene *)scene {
    (void)scene;
    self.probe.lifecycleState = @"Átmenetileg inaktív";
    [self.probe refreshStatus];
}
- (void)sceneDidEnterBackground:(UIScene *)scene {
    (void)scene;
    self.hasEnteredBackground = YES;
    self.probe.lifecycleState = @"Háttérben";
    [self.probe refreshStatus];
}
- (void)sceneWillEnterForeground:(UIScene *)scene {
    (void)scene;
    if (self.hasEnteredBackground) {
        self.probe.resumeCount += 1;
        self.hasEnteredBackground = NO;
        self.probe.lifecycleState = @"Visszatérés az előtérbe";
    } else {
        self.probe.lifecycleState = @"Indulás / előtérbe lépés";
    }
    [self.probe refreshStatus];
}
@end

@interface ProbeAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation ProbeAppDelegate
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(ProbeAppDelegate.class));
    }
}
