#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>

#define OFF_PLAYER_HULL_TRANSFORM 0x20

typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* namespaze, const char* name);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);
typedef void* (*il2cpp_field_get_value_t)(void* obj, void* field, void* value);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_runtime_invoke_t)(void* method, void* obj, void** params, void** exc);

il2cpp_domain_get_t il2cpp_domain_get_ptr = NULL;
il2cpp_domain_get_assemblies_t il2cpp_domain_get_assemblies_ptr = NULL;
il2cpp_assembly_get_image_t il2cpp_assembly_get_image_ptr = NULL;
il2cpp_class_from_name_t il2cpp_class_from_name_ptr = NULL;
il2cpp_class_get_field_from_name_t il2cpp_class_get_field_from_name_ptr = NULL;
il2cpp_field_get_value_t il2cpp_field_get_value_ptr = NULL;
il2cpp_class_get_method_from_name_t il2cpp_class_get_method_from_name_ptr = NULL;
il2cpp_runtime_invoke_t il2cpp_runtime_invoke_ptr = NULL;

UIWindow *espWindow;
UIView *drawView;
UILabel *debugLabel;
void* gameImage = NULL;

struct Vector3 { float x, y, z; };

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
    if (!gameImage) return;

    NSMutableString *debugText = [NSMutableString string];
    
    // 1. Камера
    void* cameraClass = il2cpp_class_from_name_ptr(gameImage, "UnityEngine", "Camera");
    void* mainCamField = il2cpp_class_get_field_from_name_ptr(cameraClass, "main");
    void* cameraObj = NULL;
    if (mainCamField) il2cpp_field_get_value_ptr(NULL, mainCamField, &cameraObj);
    void* w2sMethod = il2cpp_class_get_method_from_name_ptr(cameraClass, "WorldToScreenPoint", 1);
    
    [debugText appendFormat:@"Cam: %@\n", cameraObj ? @"OK" : @"NULL"];

    // 2. Игроки
    // В дампе PlayerHull без namespace, поэтому передаем пустую строку ""
    void* hullClass = il2cpp_class_from_name_ptr(gameImage, "", "PlayerHull");
    if (!hullClass) hullClass = il2cpp_class_from_name_ptr(gameImage, "ScarletWork.Game", "PlayerHull");
    
    void* activeField = il2cpp_class_get_field_from_name_ptr(hullClass, "Active");
    void* listObj = NULL;
    if (activeField) il2cpp_field_get_value_ptr(NULL, activeField, &listObj);
    
    if (!listObj) {
        debugText = [@"Hull list NULL" mutableCopy];
    } else {
        void* listClass = *(void**)listObj;
        void* itemsField = il2cpp_class_get_field_from_name_ptr(listClass, "_items");
        void* sizeField = il2cpp_class_get_field_from_name_ptr(listClass, "_size");
        
        void* itemsArray = NULL;
        int size = 0;
        if (itemsField) il2cpp_field_get_value_ptr(listObj, itemsField, &itemsArray);
        if (sizeField) il2cpp_field_get_value_ptr(listObj, sizeField, &size);

        [debugText appendFormat:@"List Size: %d\n", size];
        [debugText appendFormat:@"Array: %@\n", itemsArray ? @"OK" : @"NULL"];

        if (itemsArray && size > 0) {
            void** players = (void**)((uintptr_t)itemsArray + 0x20); 
            for (int i = 0; i < size; i++) {
                void* player = players[i];
                if (!player) continue;

                void* transform = *(void**)((uintptr_t)player + OFF_PLAYER_HULL_TRANSFORM);
                if (!transform) {
                    [debugText appendFormat:@"P%d: No Trans\n", i];
                    continue;
                }

                void* transformClass = *(void**)transform;
                void* getPosMethod = il2cpp_class_get_method_from_name_ptr(transformClass, "get_position", 0);
                if (!getPosMethod) continue;

                void* exc = NULL;
                Vector3* posPtr = (Vector3*)il2cpp_runtime_invoke_ptr(getPosMethod, transform, NULL, &exc);
                if (!posPtr || exc) continue;
                
                Vector3 worldPos = *posPtr;
                free(posPtr);

                if (w2sMethod && cameraObj) {
                    void* w2sParams[1] = { &worldPos };
                    void* w2sExc = NULL;
                    Vector3* screenPosPtr = (Vector3*)il2cpp_runtime_invoke_ptr(w2sMethod, cameraObj, w2sParams, &w2sExc);
                    
                    if (screenPosPtr && !w2sExc) {
                        Vector3 screenPos = *screenPosPtr;
                        free(screenPosPtr);

                        float screenX = screenPos.x;
                        float screenY = [UIScreen mainScreen].bounds.size.height - screenPos.y;
                        
                        [debugText appendFormat:@"P%d: %.0f,%.0f (z%.0f)\n", i, screenX, screenY, screenPos.z];

                        if (screenPos.z > 0 && screenX > 0 && screenX < [UIScreen mainScreen].bounds.size.width &&
                            screenY > 0 && screenY < [UIScreen mainScreen].bounds.size.height) {
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                CAShapeLayer *box = [CAShapeLayer layer];
                                box.path = [UIBezierPath bezierPathWithRect:CGRectMake(screenX - 30, screenY - 80, 60, 120)].CGPath;
                                box.fillColor = [UIColor clearColor].CGColor;
                                box.strokeColor = [UIColor redColor].CGColor;
                                box.lineWidth = 2.0;
                                [drawView.layer addSublayer:box];
                            });
                        }
                    }
                }
            }
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        debugLabel.text = debugText;
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
        
        debugLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 300, 300)];
        debugLabel.numberOfLines = 0;
        debugLabel.textColor = [UIColor greenColor];
        debugLabel.font = [UIFont systemFontOfSize:12];
        [vc.view addSubview:debugLabel];
        
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
            il2cpp_class_get_method_from_name_ptr = (il2cpp_class_get_method_from_name_t)dlsym(unityHandle, "il2cpp_class_get_method_from_name");
            il2cpp_runtime_invoke_ptr = (il2cpp_runtime_invoke_t)dlsym(unityHandle, "il2cpp_runtime_invoke");
            
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

        ESPRenderer *renderer = [[ESPRenderer alloc] init];
        (void)renderer;
    });
}
