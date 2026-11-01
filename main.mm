#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#import <objc/message.h>

// Оффсеты из твоего дампа
#define OFF_PLAYER_HULL_TRANSFORM 0x20
#define OFF_PLAYER_HULL_TEAM 0x30

typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);
typedef void* (*il2cpp_field_get_value_t)(void* obj, void* field, void* value);

il2cpp_domain_get_t il2cpp_domain_get_ptr = NULL;
il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies_ptr = NULL;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image_ptr = NULL;
il2cpp_class_from_name_t il2cpp_class_from_name_ptr = NULL;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name_ptr = NULL;
il2cpp_field_get_value_t il2cpp_field_get_value_ptr = NULL;

UIWindow *espWindow;
UIView *drawView;
void* gameImage = NULL;

// Структуры Unity
typedef struct { float x, y, z; } Vector3;
typedef struct { float x, y; } Vector2;

// Простая функция WorldToScreen
Vector2 WorldToScreen(Vector3 worldPos, void* camera, Vector3 camPos) {
    Vector2 screen = {0, 0};
    // В реальном Unity нужно использовать Camera.WorldToScreenPoint
    // Для этого используем objc_msgSend, так как C++ классы Unity имеют ObjC-обертки
    if (!camera) return screen;
    
    // Передаем структуру Vector3 через регистры (на arm64 это работает)
    Vector3 result = ((Vector3 (*)(void*, SEL, Vector3))objc_msgSend)(camera, @selector(WorldToScreenPoint:), worldPos);
    
    screen.x = result.x;
    screen.y = [UIScreen mainScreen].bounds.size.height - result.y; // Инверсия Y для iOS
    return screen;
}

@interface ESPRenderer : NSObject
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ESPRenderer
- (instancetype)init {
    self = [super init];
    if (self) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

- (void)render {
    for (CALayer *layer in drawView.layer.sublayers) { [layer removeFromSuperlayer]; }
    if (!gameImage || !il2cpp_class_from_name_ptr) return;

    // 1. Получаем камеру (через PlayerMovement или Camera.main)
    void* cameraClass = il2cpp_class_from_name_ptr(gameImage, "UnityEngine", "Camera");
    void* mainCamProp = il2cpp_class_get_field_from_name_ptr(cameraClass, "main");
    void* cameraObj = NULL;
    if (mainCamProp) il2cpp_field_get_value_ptr(NULL, mainCamProp, &cameraObj);

    // 2. Получаем список игроков
    void* hullClass = il2cpp_class_from_name_ptr(gameImage, "", "PlayerHull");
    void* activeField = il2cpp_class_get_field_from_name_ptr(hullClass, "Active");
    void* listObj = NULL;
    il2cpp_field_get_value_ptr(NULL, activeField, &listObj);
    if (!listObj) return;

    // 3. Получаем массив _items из списка (внутреннее поле List<T>)
    void* listClass = *(void**)listObj; // klass
    void* itemsField = il2cpp_class_get_field_from_name_ptr(listClass, "_items");
    void* sizeField = il2cpp_class_get_field_from_name_ptr(listClass, "_size");
    
    void* itemsArray = NULL;
    int size = 0;
    il2cpp_field_get_value_ptr(listObj, itemsField, &itemsArray);
    il2cpp_field_get_value_ptr(listObj, sizeField, &size);

    if (!itemsArray || size <= 0) return;

    // 4. Итерируемся по игрокам
    // В Il2CppArray первые 16 байт (или 32 на 64-бит) — это заголовок, дальше идут элементы
    void** players = (void**)((uintptr_t)itemsArray + 0x20); 

    for (int i = 0; i < size; i++) {
        void* player = players[i];
        if (!player) continue;

        // Достаем Transform
        void* transform = *(void**)((uintptr_t)player + OFF_PLAYER_HULL_TRANSFORM);
        if (!transform) continue;

        // Получаем позицию (через objc_msgSend)
        Vector3 worldPos = ((Vector3 (*)(void*, SEL))objc_msgSend)(transform, @selector(get_position));

        // Переводим в экранные координаты
        Vector2 screenPos = WorldToScreen(worldPos, cameraObj, worldPos);

        // Если игрок на экране, рисуем квадрат
        if (screenPos.x > 0 && screenPos.x < [UIScreen mainScreen].bounds.size.width &&
            screenPos.y > 0 && screenPos.y < [UIScreen mainScreen].bounds.size.height) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                CAShapeLayer *box = [CAShapeLayer layer];
                box.path = [UIBezierPath bezierPathWithRect:CGRectMake(screenPos.x - 25, screenPos.y - 50, 50, 100)].CGPath;
                box.fillColor = [UIColor clearColor].CGColor;
                box.strokeColor = [UIColor redColor].CGColor; // Красные боксы на врагах
                box.lineWidth = 2.0;
                [drawView.layer addSublayer:box];
            });
        }
    }
}
@end

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        espWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        espWindow.windowLevel = UIWindowLevelAlert + 1;
        espWindow.backgroundColor = [UIColor clearColor];
        espWindow.userInteractionEnabled = NO;
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        
        drawView = [[UIView alloc] initWithFrame:espWindow.bounds];
        drawView.backgroundColor = [UIColor clearColor];
        drawView.userInteractionEnabled = NO;
        [vc.view addSubview:drawView];
        
        espWindow.rootViewController = vc;
        espWindow.hidden = NO;

        NSString *unityPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Frameworks/UnityFramework.framework/UnityFramework"];
        void* unityHandle = dlopen([unityPath UTF8String], RTLD_LAZY);
        
        if (unityHandle) {
            il2cpp_domain_get_ptr = (il2cpp_domain_get_t)dlsym(unityHandle, "il2cpp_domain_get");
            il2cpp_domain_get_assemblies_ptr = (il2cpp_domain_get_assemblies_t)dlsym(unityHandle, "il2cpp_domain_get_assemblies");
            il2cpp_assembly_get_image_ptr = (il2cpp_assembly_get_image_t)dlsym(unityHandle, "il2cpp_assembly_get_image");
            il2cpp_class_from_name_ptr = (il2cpp_class_from_name_t)dlsym(unityHandle, "il2cpp_class_from_name");
            il2cpp_class_get_field_from_name_ptr = (il2cpp_class_get_field_from_name_t)dlsym(unityHandle, "il2cpp_class_get_field_from_name");
            il2cpp_field_get_value_ptr = (il2cpp_field_get_value_t)dlsym(unityHandle, "il2cpp_field_get_value");
            
            if (il2cpp_domain_get_ptr && il2cpp_domain_get_assemblies_ptr && il2cpp_assembly_get_image_ptr) {
                void* domain = il2cpp_domain_get_ptr();
                size_t assemblyCount = 0;
                void** assemblies = il2cpp_domain_get_assemblies_ptr(domain, &assemblyCount);
                
                if (assemblies) {
                    for (size_t i = 0; i < assemblyCount; i++) {
                        void* image = il2cpp_assembly_get_image_ptr(assemblies[i]);
                        if (image) {
                            void* testClass = il2cpp_class_from_name_ptr(image, "ScarletWork.Game", "PlayerSkeleton");
                            if (testClass) {
                                gameImage = image;
                                break;
                            }
                        }
                    }
                }
            }
        }

        // Запускаем рендер
        ESPRenderer *renderer = [[ESPRenderer alloc] init];
        (void)renderer;
    });
}
