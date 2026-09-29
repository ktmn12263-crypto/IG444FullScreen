#import <UIKit/UIKit.h>

// نسخة تشخيصية: تعرض أسماء الشاشات والعناصر الحالية داخل Instagram.

static UILabel *dbgLabel = nil;
static UIViewController *dbgLeaf = nil;

static UIWindow *DBG_KeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *ws = (UIWindowScene *)scene;
        if (ws.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in ws.windows) {
            if (w.isKeyWindow) return w;
        }
    }
    return nil;
}

static void DBG_Collect(UIViewController *vc, int depth, NSMutableString *out) {
    if (!vc || depth > 6) return;
    NSString *indent = [@"" stringByPaddingToLength:(NSUInteger)(depth * 2)
                                         withString:@" "
                                    startingAtIndex:0];
    [out appendFormat:@"%@%@\n", indent, NSStringFromClass([vc class])];
    dbgLeaf = vc;

    if (vc.presentedViewController)
        DBG_Collect(vc.presentedViewController, depth + 1, out);

    for (UIViewController *child in vc.childViewControllers)
        DBG_Collect(child, depth + 1, out);
}

static void DBG_Update(void) {
    UIWindow *window = DBG_KeyWindow();
    if (!window) return;

    if (!dbgLabel) {
        dbgLabel = [[UILabel alloc] init];
        dbgLabel.numberOfLines = 0;
        dbgLabel.font = [UIFont monospacedSystemFontOfSize:9 weight:UIFontWeightRegular];
        dbgLabel.textColor = UIColor.greenColor;
        dbgLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        dbgLabel.userInteractionEnabled = NO;
    }

    NSMutableString *text = [NSMutableString stringWithString:@"== VC ==\n"];
    dbgLeaf = nil;
    DBG_Collect(window.rootViewController, 0, text);

    [text appendString:@"== VIEWS ==\n"];
    if (dbgLeaf && dbgLeaf.isViewLoaded) {
        NSUInteger n = 0;
        for (UIView *sub in dbgLeaf.view.subviews) {
            [text appendFormat:@"%@\n", NSStringFromClass([sub class])];
            if (++n >= 15) break;
        }
    }

    dbgLabel.text = text;

    CGFloat width = window.bounds.size.width - 20.0;
    CGSize size = [dbgLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    CGFloat maxH = window.bounds.size.height * 0.6;
    dbgLabel.frame = CGRectMake(10.0,
                                window.safeAreaInsets.top + 4.0,
                                width,
                                MIN(size.height, maxH));

    if (dbgLabel.superview != window)
        [window addSubview:dbgLabel];
    [window bringSubviewToFront:dbgLabel];
}

%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSTimer scheduledTimerWithTimeInterval:1.0
                                        repeats:YES
                                          block:^(NSTimer *timer) {
            DBG_Update();
        }];
    });
}
