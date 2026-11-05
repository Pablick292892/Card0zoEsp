#include <stdint.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>

__attribute__((constructor)) void init_bypass() {
    const struct mach_header_64* header = (const struct mach_header_64*)_dyld_get_image_header(0);
    if (header) {
        uint8_t* cursor = (uint8_t*)header + sizeof(struct mach_header_64);
        for (uint32_t i = 0; i < header->ncmds; i++) {
            struct load_command* lc = (struct load_command*)cursor;
            if (lc->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64* eic = (struct encryption_info_command_64*)lc;
                uintptr_t page_size = sysconf(_SC_PAGESIZE);
                if (mprotect((void*)((uintptr_t)&eic->cryptid & ~(page_size - 1)), page_size, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
                    eic->cryptid = 0;
                }
            }
            cursor += lc->cmdsize;
        }
    }

    uintptr_t slide = _dyld_get_image_vmaddr_slide(0);
    uintptr_t base = header ? (uintptr_t)header + slide : 0;
    if (!base) return;

    size_t page_size = sysconf(_SC_PAGESIZE);
    uintptr_t target_page = (base + 0x4000) & ~(page_size - 1);
    
    if (mprotect((void*)target_page, page_size * 4, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
        uintptr_t offsets[] = {
            0x4530, 0x4544, 0x41ec, 0x4264, 0x4304, 0x4478
        };

        for (int i = 0; i < 6; i++) {
            *(uint32_t*)(base + offsets[i]) = 0xD503201F;
        }
    }
}
