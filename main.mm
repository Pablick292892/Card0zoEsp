#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#include "dobby.h" // Подключаем Dobby

// Оригинальная функция
static kern_return_t (*orig_mach_vm_region)(vm_map_t, vm_address_t *, vm_size_t, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);

// Наш хук
static kern_return_t fake_mach_vm_region(vm_map_t target_task, vm_address_t *address, vm_size_t size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *info_cnt, mach_port_t *object_name) {
    
    uintptr_t our_lib_addr = 0;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && (strstr(name, "Card0zoESP") || strstr(name, "OxideTest"))) {
            our_lib_addr = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }

    // Если античит лезет к нашей либе
    if (our_lib_addr != 0 && *address >= (our_lib_addr - 0x100000) && *address <= (our_lib_addr + 0x100000)) {
        // Сдвигаем адрес, говорим что тут пусто, ошибки нет
        *address += size; 
        return KERN_SUCCESS; 
    }
    
    // Во всех остальных случаях вызываем оригинал
    return orig_mach_vm_region(target_task, address, size, flavor, info, info_cnt, object_name);
}

__attribute__((constructor))
static void init_hooks(void) {
    // Ищем адрес функции в памяти
    void *handle = dlopen("/usr/lib/libSystem.B.dylib", RTLD_LAZY);
    if (handle) {
        void *target = dlsym(handle, "mach_vm_region");
        if (target) {
            // Ставим хук через Dobby (переписываем машинный код)
            DobbyHook(target, (void *)fake_mach_vm_region, (void **)&orig_mach_vm_region);
        }
        dlclose(handle);
    }
}
 
