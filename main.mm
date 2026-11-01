#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>

// === ОФФСЕТЫ ===
#define OFF_PLAYER_HULL_ACTIVE 0x8
#define OFF_PLAYER_HULL_TRANSFORM 0x20
#define OFF_PLAYER_HULL_TEAM 0x30

// === IL2CPP API ===
typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);
typedef void* (*il2cpp_field_get_value_t)(void* obj, void* field, void* value);
typedef void* (*il2cpp_class_get_property_from_name_t)(void* klass, const char* name);

// Unity Camera API (через UnityFramework)
typedef struct { float x, y, z; } Vector3;
typedef struct { float x, y; } Vector2;

// В реальности Unity использует свои структуры, но мы вызовем методы через objc_msgSend
// Для простоты мы пока будем рисовать квадраты в фиксированных местах, чтобы проверить UI.
// Потому что вызов Unity API для WorldToScreen через чистый C++ без заголовков — это ад.

il2cpp_domain_get_t il2cpp_domain_get_ptr = NULL;
il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies_ptr = NULL;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image_ptr = NULL;
il2cpp_class_from_name_t il2cpp_class_from_name_ptr = NULL;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name_ptr = NULL;
il2cpp_field_get_value_t il2cpp_field_get_value_ptr = NULL;

UIWindow *espWindow;
UIView *drawView;
void* gameImage = NULL;

@interface ESPRenderer : NSObject
@property (nonatomic, strong) CADisplayLink *displayLink;
- (void)render;
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
    // Очищаем старые квадраты
    for (CALayer *layer in drawView.layer.sublayers) {
        [layer removeFromSuperlayer];
    }

    if (!gameImage || !il2cpp_class_from_name_ptr) return;

    // Ищем класс PlayerHull
    void* klass = il2cpp_class_from_name_ptr(gameImage, "", "PlayerHull");
    if (!klass) return;

    // Ищем статический список Active
    void* field = il2cpp_class_get_field_from_name_ptr(klass, "Active");
    if (!field) return;

    // Получаем список
    void* listObj = NULL;
    il2cpp_field_get_value_ptr(NULL, field, &listObj);
    if (!listObj) return;

    // ВАЖНО: Для теста, чтобы ты увидел работу, мы просто нарисуем зеленый квадрат в центре экрана.
    // В следующем шаге мы научимся итерироваться по List<T> и доставать реальные координаты.
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CAShapeLayer *box = [CAShapeLayer layer];
        box.path = [UIBezierPath bezierPathWithRect:CGRectMake(100, 300, 100, 200)].CGPath;
        box.fillColor = [UIColor clearColor].CGColor;
        box.strokeColor = [UIColor greenColor].CGColor;
        box.lineWidth = 2.0;
        [drawView.layer addSublayer:box];
    });
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
        (void)renderer; // Чтобы компилятор не ругался
    });
}
