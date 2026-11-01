#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>

#pragma clang diagnostic ignored "-Wunused-function"

static UIWindow *logWindow;
static UITextView *logTextView;
static struct encryption_info_command_64 *cryptInfo = NULL;

static void addLog(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!logTextView) return;
        logTextView.text = [NSString stringWithFormat:@"%@\n%@", logTextView.text, text];
    });
}

static void setupUI(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        logWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 50, 350, 150)];
        logWindow.windowLevel = UIWindowLevelAlert + 1;
        logWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        logTextView = [[UITextView alloc] initWithFrame:logWindow.bounds];
        logTextView.backgroundColor = [UIColor clearColor];
        logTextView.textColor = [UIColor greenColor];
        logTextView.font = [UIFont fontWithName:@"Courier" size:11];
        logTextView.editable = NO;
        logTextView.text = @"[TK-TEST] Ожидание загрузки движка...";
        [logWindow addSubview:logTextView];
        logWindow.hidden = NO;
    });
}

// Эта функция будет вызываться каждый кадр
void tick(CADisplayLink *link) {
    if (cryptInfo) {
        cryptInfo->cryptid = 1;
        usleep(500); 
        cryptInfo->cryptid = 0;
    }
}

__attribute__((constructor))
static void init_patch(void) {
    // Ждем 3 секунды, чтобы игра полностью прогрузилась
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupUI();
        
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
        if (header) {
            const struct load_command *cmd = (const struct load_command *)(header + 1);
            for (uint32_t i = 0; i < header->ncmds; i++) {
                if (cmd->cmd == LC_ENCRYPTION_INFO_64) {
                    cryptInfo = (struct encryption_info_command_64 *)cmd;
                    break;
                }
                cmd = (const struct load_command *)((uint8_t *)cmd + cmd->cmdsize);
            }
        }
        
        if (cryptInfo) {
            vm_protect(mach_task_self(), (vm_address_t)cryptInfo, sizeof(*cryptInfo), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
            addLog(@"[OK] Нашли cryptid. Запускаем таймер.");
            
            // Создаем таймер, который тикает вместе с кадрами экрана
            CADisplayLink *link = [CADisplayLink displayLinkWithTarget:[NSBlockOperation blockOperationWithBlock:^{
                tick(nil);
            }] selector:@selector(main)];
            [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        } else {
            addLog(@"[ERR] cryptid не найден.");
        }
    });
}
