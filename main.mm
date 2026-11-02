#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import "fishhook/fishhook.h"

// Оригинальные функции
static kern_return_t (*orig_mach_vm_region)(vm_map_t, vm_address_t *, vm_size_t, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);

// Хук на чтение карты памяти (прячем наши либы)
static kern_return_t fake_mach_vm_region(vm_map_t target_task, vm_address_t *address, vm_size_t size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *info_cnt, mach_port_t *object_name) {
    kern_return_t kr = orig_mach_vm_region(target_task, address, size, flavor, info, info_cnt, object_name);
    // Если античит пытается просканировать регион, мы можем тут вернуть KERN_INVALID_ADDRESS, 
    // чтобы он пропустил этот регион. Но для начала просто пропускаем.
    return kr;
}

__attribute__((constructor))
static void init_hooks(void) {
    // Ставим хук на mach_vm_region
    struct rebinding rebinds[1];
    rebinds[0].name = "mach_vm_region";
    rebinds[0].replacement = (void *)fake_mach_vm_region;
    rebinds[0].replaced = (void **)&orig_mach_vm_region;
    
    rebind_symbols(rebinds, 1);
    
    // Остальные хуки (were...Hooks) мы не можем напрямую захукать, 
    // потому что это методы Objective-C. Но мы можем попробовать 
    // заменить их реализацию в рантайме через method_setImplementation.
}
