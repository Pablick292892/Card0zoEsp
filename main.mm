#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <mach/mach.h>

#pragma mark - IL2CPP Runtime Types
typedef void* Il2CppClass;
typedef void* Il2CppFieldInfo;
typedef void* Il2CppDomain;
typedef void* Il2CppAssembly;
typedef void* Il2CppImage;

typedef Il2CppDomain* (*il2cpp_domain_get_t)();
typedef Il2CppAssembly* (*il2cpp_domain_assembly_open_t)(Il2CppDomain*, const char*);
typedef Il2CppImage* (*il2cpp_assembly_get_image_t)(Il2CppAssembly*);
typedef Il2CppClass* (*il2cpp_class_from_name_t)(Il2CppImage*, const char*, const char*);
typedef Il2CppFieldInfo* (*il2cpp_class_get_fields_t)(Il2CppClass*, void**);
typedef void (*il2cpp_field_static_get_value_t)(Il2CppFieldInfo*, void*);
typedef const char* (*il2cpp_field_get_name_t)(Il2CppFieldInfo*);

static il2cpp_domain_get_t fn_domain_get = NULL;
static il2cpp_domain_assembly_open_t fn_assembly_open = NULL;
static il2cpp_assembly_get_image_t fn_get_image = NULL;
static il2cpp_class_from_name_t fn_class_from_name = NULL;
static il2cpp_class_get_fields_t fn_class_get_fields = NULL;
static il2cpp_field_static_get_value_t fn_field_static_get = NULL;
static il2cpp_field_get_name_t fn_field_get_name = NULL;

#pragma mark - Math
struct Vector3 { float x, y, z; };
struct Vector2 { float x, y; };

#pragma mark - Memory
class Memory {
public:
    static uintptr_t GetBase(const char* name) {
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            if (strstr(_dyld_get_image_name(i), name))
                return (uintptr_t)_dyld_get_image_header(i);
        }
        return 0;
    }
    template<typename T>
    static T Read(uintptr_t a) { return a ? *(T*)a : T{}; }
};

#pragma mark - IL2CPP Helper
class IL2CPP {
public:
    static uintptr_t base;
    static Il2CppImage* csharpImage;
    
    static bool Init() {
        base = Memory::GetBase("GameAssembly.dylib");
        if (!base) return false;
        
        *(void**)&fn_domain_get = dlsym(RTLD_DEFAULT, "il2cpp_domain_get");
        *(void**)&fn_assembly_open = dlsym(RTLD_DEFAULT, "il2cpp_domain_assembly_open");
        *(void**)&fn_get_image = dlsym(RTLD_DEFAULT, "il2cpp_assembly_get_image");
        *(void**)&fn_class_from_name = dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
        *(void**)&fn_class_get_fields = dlsym(RTLD_DEFAULT, "il2cpp_class_get_fields");
        *(void**)&fn_field_static_get = dlsym(RTLD_DEFAULT, "il2cpp_field_static_get_value");
        *(void**)&fn_field_get_name = dlsym(RTLD_DEFAULT, "il2cpp_field_get_name");
        
        if (!fn_domain_get || !fn_class_from_name) return false;
        
        auto domain = fn_domain_get();
        auto assembly = fn_assembly_open(domain, "Assembly-CSharp");
        csharpImage = fn_get_image(assembly);
        
        return csharpImage != NULL;
    }
    
    static void* GetStaticField(const char* className, const char* fieldName) {
        if (!csharpImage) return NULL;
        
        auto cls = fn_class_from_name(csharpImage, "ScarletWork.Game", className);
        if (!cls) return NULL;
        
        void* iter = NULL;
        Il2CppFieldInfo* field;
        while ((field = fn_class_get_fields(cls, &iter)) != NULL) {
            const char* name = fn_field_get_name(field);
            if (name && strcmp(name, fieldName) == 0) {
                void* value = NULL;
                fn_field_static_get(field, &value);
                return value;
            }
        }
        return NULL;
    }
};

uintptr_t IL2CPP::base = 0;
Il2CppImage* IL2CPP::csharpImage = NULL;

#pragma mark - ESP Overlay
static UIView* g_overlayView = nil;
static bool g_espEnabled = true;

static void CreateOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow* window = UIApplication.sharedApplication.windows.firstObject;
        if (!window) return;
        
        g_overlayView = [[UIView alloc] initWithFrame:window.bounds];
        g_overlayView.backgroundColor = [UIColor clearColor];
        g_overlayView.userInteractionEnabled = NO;
        g_overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [window addSubview:g_overlayView];
    });
}

static void ClearOverlay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_overlayView) return;
        for (UIView* sub in g_overlayView.subviews) {
            [sub removeFromSuperview];
        }
    });
}

static void DrawBox(float x, float y, float w, float h, bool isClose) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_overlayView) return;
        
        CGRect rect = CGRectMake(x - w/2, y - h, w, h);
        UIView* box = [[UIView alloc] initWithFrame:rect];
        box.backgroundColor = [UIColor clearColor];
        box.layer.borderColor = isClose ? [UIColor redColor].CGColor : [UIColor greenColor].CGColor;
        box.layer.borderWidth = 2.0;
        [g_overlayView addSubview:box];
    });
}

static void DrawText(NSString* text, float x, float y) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!g_overlayView) return;
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(x - 25, y - 20, 50, 20)];
        label.text = text;
        label.textColor = [UIColor whiteColor];
        label.font = [UIFont systemFontOfSize:12];
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor clearColor];
        [g_overlayView addSubview:label];
    });
}

#pragma mark - ESP Logic
class ESP {
public:
    static void* hittableList;
    
    static constexpr uintptr_t GET_MAIN_CAMERA_RVA = 0x1579AAC;
    static constexpr uintptr_t W2S_RVA = 0x2D5F87C;
    
    static void Init() {
        if (!IL2CPP::Init()) return;
        
        hittableList = IL2CPP::GetStaticField("PlayerSkeleton", "Hittable");
        
        if (hittableList) {
            CreateOverlay();
        }
    }
    
    static void Update() {
        if (!g_espEnabled || !hittableList || !g_overlayView) return;
        
        auto items = Memory::Read<uintptr_t>((uintptr_t)hittableList + 0x10);
        auto size = Memory::Read<int>((uintptr_t)hittableList + 0x18);
        
        if (!items || size <= 0 || size > 100) {
            ClearOverlay();
            return;
        }
        
        auto getCamera = (uintptr_t(*)(void))(IL2CPP::base + GET_MAIN_CAMERA_RVA);
        auto camera = getCamera();
        if (!camera) return;
        
        auto w2s = (Vector2(*)(uintptr_t, Vector3))(IL2CPP::base + W2S_RVA);
        
        float sw = [UIScreen mainScreen].bounds.size.width;
        float sh = [UIScreen mainScreen].bounds.size.height;
        
        ClearOverlay();
        
        for (int i = 0; i < size; i++) {
            auto skeleton = Memory::Read<uintptr_t>(items + i * 8);
            if (!skeleton) continue;
            
            auto transform = Memory::Read<uintptr_t>(skeleton + 0x40);
            if (!transform) continue;
            
            auto pos = Memory::Read<Vector3>(transform + 0x38);
            float dist = sqrtf(pos.x*pos.x + pos.y*pos.y + pos.z*pos.z);
            if (dist > 200.0f) continue;
            
            auto screen = w2s(camera, pos);
            screen.x *= (sw / 1920.0f);
            screen.y *= (sh / 1080.0f);
            
            if (screen.x < 0 || screen.x > sw || screen.y < 0 || screen.y > sh) continue;
            
            bool isClose = dist < 50;
            DrawBox(screen.x, screen.y, 60, 120, isClose);
            DrawText([NSString stringWithFormat:@"%dm", (int)dist], screen.x, screen.y - 130);
        }
    }
};

void* ESP::hittableList = NULL;

#pragma mark - Entry Point
__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC),
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        ESP::Init();
        
        dispatch_source_t timer = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC, 10 * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(timer, ^{
            ESP::Update();
        });
        dispatch_resume(timer);
    });
}
