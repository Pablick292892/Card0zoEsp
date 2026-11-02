#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import "fishhook/fishhook.h"

// Оригинальные функции
static kern_return_t (*orig_mach_vm_region)(vm_map_t, vm_address_t *, vm_size_t, vm_region_flavor_t, vm_region_info_t, mach_msg_type_number_t *, mach_port_t *);
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);

// 1. Хук на память (прячем нашу либу)
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
    // Если лезут к нашей либе, отдаем пустоту
    if (our_lib_addr != 0 && *address >= (our_lib_addr - 0x100000) && *address <= (our_lib_addr + 0x100000)) {
        return KERN_INVALID_ADDRESS;
    }
    return orig_mach_vm_region(target_task, address, size, flavor, info, info_cnt, object_name);
}

// 2. Хук на дебаг (sysctl)
static int fake_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (namelen == 4 && name[0] == CTL_KERN && name[1] == KERN_PROC && name[2] == KERN_PROC_PID) {
        if (oldp != NULL && oldlenp != NULL) {
            struct kinfo_proc *info = (struct kinfo_proc *)oldp;
            info->kp_proc.p_flag &= ~P_TRACED;
        }
        return 0;
    }
    return orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
}

__attribute__((constructor))
static void init_hooks(void) {
    struct rebinding rebinds[2];
    
    rebinds[0].name = "mach_vm_region";
    rebinds[0].replacement = (void *)fake_mach_vm_region;
    rebinds[0].replaced = (void **)&orig_mach_vm_region;
    
    rebinds[1].name = "sysctl";
    rebinds[1].replacement = (void *)fake_sysctl;
    rebinds[1].replaced = (void **)&orig_sysctl;
    
    rebind_symbols(rebinds, 2);
}
