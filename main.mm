#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>

// Отключаем ошибку неиспользуемой функции
#pragma clang diagnostic ignored "-Wunused-function"

static UIWindow *logWindow;
static UITextView *logTextView;
static BOOL keepRunning = YES;

static void addLog(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!logTextView) return;
        logTextView.text = [NSString stringWithFormat:@"%@\n%@", logTextView.text, text];
    });
}

static void setupUI(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        logWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 50, 350, 200)];
        logWindow.windowLevel = UIWindowLevelAlert + 1;
        logWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        logTextView = [[UITextView alloc] initWithFrame:logWindow.bounds];
        logTextView.backgroundColor = [UIColor clearColor];
        logTextView.textColor = [UIColor greenColor];
        logTextView.font = [UIFont fontWithName:@"Courier" size:11];
        logTextView.editable = NO;
        logTextView.text = @"[TK-TEST] Фоновый патч запущен...";
        [logWindow addSubview:logTextView];
        logWindow.hidden = NO;
    });
}

__attribute__((constructor))
static void init_patch(void) {
    // Запускаем в фоне, чтобы не блокировать главный поток
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        setupUI();
        
        while (keepRunning) {
            const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
            if (header) {
                const struct load_command *cmd = (const struct load_command *)(header + 1);
                for (uint32_t i = 0; i < header->ncmds; i++) {
                    if (cmd->cmd == LC_ENCRYPTION_INFO_64) {
                        struct encryption_info_command_64 *info = (struct encryption_info_command_64 *)cmd;
                        if (info->cryptid == 0) {
                            vm_protect(mach_task_self(), (vm_address_t)info, sizeof(*info), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                            info->cryptid = 1; 
                        }
                    }
                    cmd = (const struct load_command *)((uint8_t *)cmd + cmd->cmdsize);
                }
            }
            // Ждем 10 миллисекунд и повторяем
            usleep(10000); 
        }
    });
}
