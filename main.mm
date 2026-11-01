#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// Окно для отрисовки
UIWindow *espWindow;
UILabel *espLabel;

__attribute__((constructor))
static void init() {
    NSLog(@"[Card0zoEsp] Loaded. Waiting for UI...");
    
    // Ждем 3 секунды, чтобы игра прогрузилась
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Создаем UI без всяких dlopen и функций памяти
        espWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        espWindow.windowLevel = UIWindowLevelAlert + 1;
        espWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        
        espLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 30)];
        espLabel.text = @"ESP: Injected OK!";
        espLabel.textColor = [UIColor greenColor];
        espLabel.font = [UIFont boldSystemFontOfSize:16];
        [vc.view addSubview:espLabel];
        
        espWindow.rootViewController = vc;
        espWindow.hidden = NO;
    });
}
