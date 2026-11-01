#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import "fishhook/fishhook.h"

// Глобальные переменные для UI
static UIWindow *logWindow;
static UITextView *logTextView;

static void addLog(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!logTextView) return;
        logTextView.text = [NSString stringWithFormat:@"%@\n%@", logTextView.text, text];
        // Автоскролл вниз
        NSRange range = NSMakeRange(logTextView.text.length - 1, 1);
        [logTextView scrollRangeToVisible:range];
    });
}

// Оригинальные функции
static kern_return_t (*orig_mach_vm_read_overwrite)(vm_map_t, vm_address_t, vm_size_t, vm_address_t, vm_size_t *);
static kern_return_t (*orig_mach_vm_read)(vm_map_t, vm_address_t, vm_size_t, vm_offset_t *, vm_size_t *);

// Хук для mach_vm_read_overwrite
static kern_return_t fake_mach_vm_read_overwrite(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_address_t data, vm_size_t *outsize) {
    // Логируем адрес и размер
    addLog([NSString stringWithFormat:@"R_OVERW: %p (size %zu)", (void*)address, size]);
    
    // Пропускаем настоящий вызов, чтобы игра не крашилась
    return orig_mach_vm_read_overwrite(target_task, address, size, data, outsize);
}

// Хук для mach_vm_read
static kern_return_t fake_mach_vm_read(vm_map_t target_task, vm_address_t address, vm_size_t size, vm_offset_t *data, vm_size_t *outsize) {
    addLog([NSString stringWithFormat:@"R_READ: %p (size %zu)", (void*)address, size]);
    return orig_mach_vm_read(target_task, address, size, data, outsize);
}

__attribute__((constructor))
static void init_hooks(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Настраиваем окно
        logWindow = [[UIWindow alloc] initWithFrame:CGRectMake(10, 50, 350, 250)];
        logWindow.windowLevel = UIWindowLevelAlert + 1;
        logWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
        
        logTextView = [[UITextView alloc] initWithFrame:logWindow.bounds];
        logTextView.backgroundColor = [UIColor clearColor];
        logTextView.textColor = [UIColor greenColor];
        logTextView.font = [UIFont fontWithName:@"Courier" size:10];
        logTextView.editable = NO;
        logTextView.text = @"[TK-TEST] Логгер памяти запущен...";
        
        [logWindow addSubview:logTextView];
        logWindow.hidden = NO;
        
        // Ставим хуки
        struct rebinding rebinds[2];
        
        rebinds[0].name = "mach_vm_read_overwrite";
        rebinds[0].replacement = (void *)fake_mach_vm_read_overwrite;
        rebinds[0].replaced = (void **)&orig_mach_vm_read_overwrite;

        rebinds[1].name = "mach_vm_read";
        rebinds[1].replacement = (void *)fake_mach_vm_read;
        rebinds[1].replaced = (void **)&orig_mach_vm_read;

        rebind_symbols(rebinds, 2);
    });
}
