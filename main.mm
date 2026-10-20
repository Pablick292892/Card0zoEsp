#include <unistd.h>
#include <cstdlib>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <dlfcn.h>
#include <thread>

// --- Хук на появление UIView ---
__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    // Ждем, пока игра загрузится и создаст окно
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Создаем наше окно
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1; // Поверх всего
        window.backgroundColor = [UIColor clearColor];
        window.rootViewController = [[UIViewController alloc] init];
        [window makeKeyAndVisible];

        // Создаем контейнер для меню
        UIView *menuView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 250, 150)];
        menuView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        menuView.layer.cornerRadius = 10;
        menuView.layer.borderWidth = 1;
        menuView.layer.borderColor = [UIColor purpleColor].CGColor;
        [window.rootViewController.view addSubview:menuView];

        // Заголовок
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 230, 30)];
        title.text = @"CARD0ZO PREMIUM";
        title.textColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
        title.font = [UIFont boldSystemFontOfSize:18];
        [menuView addSubview:title];

        // Кнопка закрытия
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(10, 100, 230, 40);
        [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [closeBtn addTarget:window action:@selector(resignKeyWindow) forControlEvents:UIControlEventTouchUpInside];
        [menuView addSubview:closeBtn];
        
        NSLog(@"[Card0zo] Native UI Menu Loaded!");
    });
}
