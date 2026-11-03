#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>

// --- IL2CPP API ---
typedef void* Il2CppDomain;
typedef void* Il2CppAssembly;
typedef void* Il2CppImage;
typedef void* Il2CppClass;
typedef void* Il2CppObject;
typedef void* Il2CppMethod;
typedef void* Il2CppField;
typedef void* Il2CppString;

static Il2CppDomain (*il2cpp_domain_get)();
static Il2CppAssembly** (*il2cpp_domain_get_assemblies)(const Il2CppDomain*, size_t*);
static Il2CppImage* (*il2cpp_assembly_get_image)(const Il2CppAssembly*);
static Il2CppClass* (*il2cpp_class_from_name)(const Il2CppImage*, const char*, const char*);
static void (*il2cpp_field_get_value)(Il2CppObject*, Il2CppField*, void*);
static Il2CppField* (*il2cpp_class_get_field_from_name)(Il2CppClass*, const char*);
static const char* (*il2cpp_class_get_name)(Il2CppClass*);
static Il2CppClass* (*il2cpp_object_get_class)(Il2CppObject*);
static Il2CppMethod* (*il2cpp_class_get_method_from_name)(Il2CppClass*, const char*, int);
static Il2CppObject* (*il2cpp_runtime_invoke)(const Il2CppMethod*, void*, void**, Il2CppObject**);
static Il2CppString* (*il2cpp_string_new)(const char* str);
static uint32_t (*il2cpp_image_get_class_count)(const Il2CppImage*);
static Il2CppClass* (*il2cpp_image_get_class)(const Il2CppImage*, size_t);

// --- UI ---
static UIWindow *espWindow;
static UIView *espView;

typedef struct { float x, y, z; } Vector3;

void drawBox(CGRect rect) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CAShapeLayer *box = [CAShapeLayer layer];
        box.path = [UIBezierPath bezierPathWithRect:rect].CGPath;
        box.strokeColor = [UIColor redColor].CGColor;
        box.fillColor = [UIColor clearColor].CGColor;
        box.lineWidth = 1.5;
        [espView.layer addSublayer:box];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.016 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [box removeFromSuperlayer];
        });
    });
}

bool w2s(Vector3 world, Vector3 camPos, Vector3 camRot, float fov, CGPoint *out) {
    float dx = world.x - camPos.x;
    float dy = world.y - camPos.y;
    float dz = world.z - camPos.z;
    float yaw = camRot.y * M_PI / 180.0;
    float cosY = cos(yaw), sinY = sin(yaw);
    float rx = dx * cosY - dz * sinY;
    float rz = dx * sinY + dz * cosY;
    float pitch = camRot.x * M_PI / 180.0;
    float cosP = cos(pitch), sinP = sin(pitch);
    float ry = dy * cosP - rz * sinP;
    float rz2 = dy * sinP + rz * cosP;
    if (rz2 <= 0.1) return false;
    float screenX = ([UIScreen mainScreen].bounds.size.width / 2) * (1 + rx / (rz2 * tan(fov * M_PI / 360.0)));
    float screenY = ([UIScreen mainScreen].bounds.size.height / 2) * (1 - ry / (rz2 * tan(fov * M_PI / 360.0)));
    out->x = screenX;
    out->y = screenY;
    return true;
}

__attribute__((constructor))
static void init() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        void *handle = dlopen(NULL, RTLD_NOW);
        il2cpp_domain_get = dlsym(handle, "il2cpp_domain_get");
        il2cpp_domain_get_assemblies = dlsym(handle, "il2cpp_domain_get_assemblies");
        il2cpp_assembly_get_image = dlsym(handle, "il2cpp_assembly_get_image");
        il2cpp_class_from_name = dlsym(handle, "il2cpp_class_from_name");
        il2cpp_field_get_value = dlsym(handle, "il2cpp_field_get_value");
        il2cpp_class_get_field_from_name = dlsym(handle, "il2cpp_class_get_field_from_name");
        il2cpp_class_get_name = dlsym(handle, "il2cpp_class_get_name");
        il2cpp_object_get_class = dlsym(handle, "il2cpp_object_get_class");
        il2cpp_class_get_method_from_name = dlsym(handle, "il2cpp_class_get_method_from_name");
        il2cpp_runtime_invoke = dlsym(handle, "il2cpp_runtime_invoke");
        il2cpp_string_new = dlsym(handle, "il2cpp_string_new");
        il2cpp_image_get_class_count = dlsym(handle, "il2cpp_image_get_class_count");
        il2cpp_image_get_class = dlsym(handle, "il2cpp_image_get_class");

        if (!il2cpp_domain_get) return;

        espWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        espWindow.windowLevel = UIWindowLevelAlert + 1;
        espWindow.backgroundColor = [UIColor clearColor];
        espWindow.userInteractionEnabled = NO;
        espView = [[UIView alloc] initWithFrame:espWindow.bounds];
        espView.backgroundColor = [UIColor clearColor];
        [espWindow addSubview:espView];
        espWindow.hidden = NO;

        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:[NSBlockOperation blockOperationWithBlock:^{
            size_t count = 0;
            Il2CppAssembly **assemblies = il2cpp_domain_get_assemblies(il2cpp_domain_get(), &count);
            Il2CppClass *gameControllerClass = NULL;
            Il2CppImage *mainImage = NULL;

            for (size_t i = 0; i < count; i++) {
                Il2CppImage *image = il2cpp_assembly_get_image(assemblies[i]);
                gameControllerClass = il2cpp_class_from_name(image, "ScarletWork.Game", "GameController");
                if (gameControllerClass) { mainImage = image; break; }
            }
            if (!gameControllerClass || !mainImage) return;

            Il2CppMethod *getInstanceMethod = il2cpp_class_get_method_from_name(gameControllerClass, "get_Instance", 0);
            if (!getInstanceMethod) return;

            Il2CppObject *instance = il2cpp_runtime_invoke(getInstanceMethod, NULL, NULL, NULL);
            if (!instance) return;

            Il2CppMethod *getAlivePlayersMethod = il2cpp_class_get_method_from_name(gameControllerClass, "GetAlivePlayers", 1);
            if (!getAlivePlayersMethod) return;

            Il2CppString *teamString = il2cpp_string_new("");
            void *args[1] = { teamString };
            Il2CppObject *alivePlayersList = il2cpp_runtime_invoke(getAlivePlayersMethod, instance, args, NULL);
            if (!alivePlayersList) return;

            Il2CppClass *listClass = il2cpp_class_from_name(mainImage, "System.Collections.Generic", "List`1");
            Il2CppField *itemsField = il2cpp_class_get_field_from_name(listClass, "_items");
            Il2CppField *sizeField = il2cpp_class_get_field_from_name(listClass, "_size");

            Il2CppObject *itemsArray = NULL;
            int size = 0;
            il2cpp_field_get_value(alivePlayersList, itemsField, &itemsArray);
            il2cpp_field_get_value(alivePlayersList, sizeField, &size);

            if (!itemsArray || size <= 0) return;

            uintptr_t arrayData = (uintptr_t)itemsArray + 0x20;

            for (int i = 0; i < size; i++) {
                Il2CppObject *player = *(Il2CppObject**)(arrayData + i * 8);
                if (!player) continue;

                Il2CppClass *playerClass = il2cpp_object_get_class(player);
                Il2CppField *posField = il2cpp_class_get_field_from_name(playerClass, "Position");
                if (!posField) continue;

                Vector3 pos;
                il2cpp_field_get_value(player, posField, &pos);

                CGPoint screen;
                if (w2s(pos, (Vector3){0,0,0}, (Vector3){0,0,0}, 90.0, &screen)) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        drawBox(CGRectMake(screen.x - 20, screen.y - 40, 40, 80));
                    });
                }
            }
        }] selector:@selector(main)];
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    });
}
