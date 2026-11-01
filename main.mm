#import <Foundation/Foundation.h>

__attribute__((constructor))
static void init_oxide_test(void) {
    // Этот код сработает сразу при запуске игры
    // Если игра запустится и не вылетит - значит, обход LCsign работает
    NSLog(@"[TK-TEST] ======================================");
    NSLog(@"[TK-TEST] Dylib успешно загружена в Oxide!");
    NSLog(@"[TK-TEST] Проверка инъекции пройдена.");
    NSLog(@"[TK-TEST] ======================================");
}
