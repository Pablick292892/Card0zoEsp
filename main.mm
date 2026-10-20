#include <unistd.h>
#include <cstdlib>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");

    // Ждем загрузки игры
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Создаем окно
        UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelAlert + 1; // Поверх всего
        window.backgroundColor = [UIColor clearColor];
        window.rootViewController = [[UIViewController alloc] init];
        [window makeKeyAndVisible];

        // Создаем меню
        UIView *menu = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 280, 200)];
        menu.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        menu.layer.cornerRadius = 12;
        menu.layer.borderWidth = 2;
        menu.layer.borderColor = [UIColor purpleColor].CGColor;
        [window.rootViewController.view addSubview:menu];

        // Заголовок
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 260, 40)];
        title.text = @"CARD0ZO PREMIUM";
        title.textColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0];
        title.font = [UIFont boldSystemFontOfSize:22];
        title.textAlignment = NSTextAlignmentCenter;
        [menu addSubview:title];

        // Кнопка ESP
        UIButton *espBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        espBtn.frame = CGRectMake(10, 60, 260, 40);
        [espBtn setTitle:@"Enable ESP" forState:UIControlStateNormal];
        [espBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [menu addSubview:espBtn];

        // Кнопка закрытия
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(10, 150, 260, 40);
        [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        [closeBtn addTarget:window action:@selector(resignKeyWindow) forControlEvents:UIControlEventTouchUpInside];
        [menu addSubview:closeBtn];
    });
}
