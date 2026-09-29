#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UIButton *igfs_button = nil;
static BOOL igfs_enabled = NO;
static UIView *igfs_targetView = nil;

static BOOL IGFS_IsReelsLikeViewController(UIViewController *vc) {
    if (!vc) return NO;

    NSString *cls = NSStringFromClass([vc class]);
    NSString *lower = [cls lowercaseString];

    // Generic detection so the tweak does not depend on one private class name.
    return [lower containsString:@"reel"] ||
           [lower containsString:@"fullscreenvideo"] ||
           [lower containsString:@"video"];
}

static UIViewController *IGFS_TopViewController(void) {
    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState == UISceneActivationStateUnattached) continue;

            for (UIWindow *w in ws.windows) {
                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }
            if (window) break;
        }
    }

    if (!window) window = UIApplication.sharedApplication.keyWindow;
    if (!window) return nil;

    UIViewController *vc = window.rootViewController;

    while (vc.presentedViewController)
        vc = vc.presentedViewController;

    while ([vc isKindOfClass:[UINavigationController class]])
        vc = [(UINavigationController *)vc visibleViewController];

    while ([vc isKindOfClass:[UITabBarController class]])
        vc = [(UITabBarController *)vc selectedViewController];

    return vc;
}

static UIView *IGFS_FindVideoContainer(UIView *root) {
    if (!root) return nil;

    // Prefer a view containing an AVPlayerLayer.
    if ([root.layer.sublayers count]) {
        for (CALayer *layer in root.layer.sublayers) {
            NSString *name = NSStringFromClass([layer class]);
            if ([name.lowercaseString containsString:@"avplayer"]) {
                return root;
            }
        }
    }

    for (UIView *sub in root.subviews) {
        UIView *found = IGFS_FindVideoContainer(sub);
        if (found) return found;
    }

    return nil;
}

static void IGFS_SetFullscreen(BOOL fullscreen) {
    UIViewController *vc = IGFS_TopViewController();
    if (!vc || !IGFS_IsReelsLikeViewController(vc)) return;

    UIWindow *window = vc.view.window ?: UIApplication.sharedApplication.keyWindow;
    if (!window) return;

    if (fullscreen) {
        igfs_targetView = IGFS_FindVideoContainer(vc.view);
        if (!igfs_targetView)
            igfs_targetView = vc.view;

        // Hide common Instagram overlay controls while preserving the video.
        for (UIView *sub in vc.view.subviews) {
            if (sub == igfs_button) continue;

            NSString *cls = NSStringFromClass([sub class]).lowercaseString;
            if ([cls containsString:@"comment"] ||
                [cls containsString:@"like"] ||
                [cls containsString:@"share"] ||
                [cls containsString:@"caption"] ||
                [cls containsString:@"toolbar"]) {
                sub.alpha = 0.0;
                sub.userInteractionEnabled = NO;
            }
        }

        // Extend the video container to the whole screen.
        igfs_targetView.translatesAutoresizingMaskIntoConstraints = YES;
        igfs_targetView.frame = window.bounds;
        igfs_targetView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        [[UIApplication sharedApplication] setStatusBarHidden:YES
                                                  withAnimation:UIStatusBarAnimationFade];
    } else {
        for (UIView *sub in vc.view.subviews) {
            if (sub == igfs_button) continue;
            if (sub.alpha == 0.0) {
                sub.alpha = 1.0;
                sub.userInteractionEnabled = YES;
            }
        }

        [[UIApplication sharedApplication] setStatusBarHidden:NO
                                                  withAnimation:UIStatusBarAnimationFade];

        igfs_targetView = nil;
    }

    igfs_enabled = fullscreen;
}

static void IGFS_ButtonPressed(void) {
    IGFS_SetFullscreen(!igfs_enabled);
}

static void IGFS_AddButtonIfNeeded(void) {
    UIViewController *vc = IGFS_TopViewController();
    if (!vc || !vc.view.window) return;
    if (!IGFS_IsReelsLikeViewController(vc)) return;

    if (igfs_button && igfs_button.superview == vc.view)
        return;

    [igfs_button removeFromSuperview];

    igfs_button = [UIButton buttonWithType:UIButtonTypeSystem];
    igfs_button.frame = CGRectMake(vc.view.bounds.size.width - 52.0, 52.0, 36.0, 36.0);
    igfs_button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
                                   UIViewAutoresizingFlexibleBottomMargin;

    igfs_button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.45];
    igfs_button.layer.cornerRadius = 18.0;
    igfs_button.clipsToBounds = YES;

    UIImage *image = nil;
    if (@available(iOS 13.0, *)) {
        image = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"];
    }

    if (image)
        [igfs_button setImage:image forState:UIControlStateNormal];
    else
        [igfs_button setTitle:@"⛶" forState:UIControlStateNormal];

    [igfs_button setTintColor:UIColor.whiteColor];
    [igfs_button addTarget:[IGFS_ButtonTarget shared]
                    action:@selector(pressed:)
          forControlEvents:UIControlEventTouchUpInside];

    [vc.view addSubview:igfs_button];
}

@interface IGFS_ButtonTarget : NSObject
+ (instancetype)shared;
- (void)pressed:(UIButton *)sender;
@end

@implementation IGFS_ButtonTarget
+ (instancetype)shared {
    static IGFS_ButtonTarget *obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [IGFS_ButtonTarget new];
    });
    return obj;
}
- (void)pressed:(UIButton *)sender {
    IGFS_ButtonPressed();
}
@end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        IGFS_AddButtonIfNeeded();
    });
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (igfs_button && igfs_button.superview == self.view) {
        CGFloat top = self.view.safeAreaInsets.top + 8.0;
        igfs_button.frame = CGRectMake(self.view.bounds.size.width - 52.0,
                                       top,
                                       36.0,
                                       36.0);
    }
}

%end

%ctor {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Give Instagram time to finish initialising its root UI.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                IGFS_AddButtonIfNeeded();
            });
        });
    }
}
