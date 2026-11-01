#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <mach/mach.h>

// Глобальные переменные для UI
static UIWindow *logWindow;
static UITextView *logTextView;

// Функция для добавления текста на экран
static void addLog(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!logTextView) return;
        NSString *current = logTextView.text;
        logTextView.text = [NSString stringWithFormat:@"%@\n%@", current, text];
        // Скроллим вниз, чтобы видеть новые строки
        NSRange range = NSMakeRange(logTextView.text.length - 1, 1);
        [logTextView scrollRangeToVisible:range];
    });
}

// Создаем окно с логами поверх игры
static void setupUI(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        logWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 50, 350, 250)];
        logWindow.windowLevel = UIWindowLevelAlert + 1;
        logWindow.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        logWindow.layer.cornerRadius = 10;
        logWindow.layer.masksToBounds = YES;

        logTextView = [[UITextView alloc] initWithFrame:logWindow.bounds];
        logTextView.backgroundColor = [UIColor clearColor];
        logTextView.textColor = [UIColor greenColor];
        logTextView.font = [UIFont fontWithName:@"Courier" size:11];
        logTextView.editable = NO;
        logTextView.text = @"[TK-TEST] Запуск...";
        
        [logWindow addSubview:logTextView];
        logWindow.hidden = NO;
    });
}

__attribute__((constructor))
static void init_patch(void) {
    // Ждем 1 секунду, чтобы игра инициализировала память
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        setupUI();
        addLog(@"[TK] Поиск Mach-O заголовка...");
        
        // Получаем заголовок главного бинаря игры
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(0);
        
        if (!header) {
            addLog(@"[ERR] Заголовок не найден!");
            return;
        }

        int patchedCount = 0;

        // Ищем сегмент с информацией о шифровании
        const struct load_command *cmd = (const struct load_command *)(header + 1);
        for (uint32_t i = 0; i < header->ncmds; i++) {
            if (cmd->cmd == LC_ENCRYPTION_INFO_64) {
                struct encryption_info_command_64 *info = (struct encryption_info_command_64 *)cmd;
                
                addLog([NSString stringWithFormat:@"[INF] cryptid сейчас: %d", info->cryptid]);
                
                if (info->cryptid == 0) {
                    // Снимаем защиту памяти (делаем страницу доступной для записи)
                    kern_return_t kr = vm_protect(mach_task_self(), (vm_address_t)info, sizeof(*info), false, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
                    
                    if (kr == KERN_SUCCESS) {
                        info->cryptid = 1;
                        patchedCount++;
                        addLog(@"[OK] Патч применен! cryptid = 1");
                    } else {
                        addLog([NSString stringWithFormat:@"[ERR] vm_protect failed: %d", kr]);
                    }
                } else {
                    addLog(@"[INF] Уже зашифрован (cryptid = 1)");
                }
            }
            cmd = (const struct load_command *)((uint8_t *)cmd + cmd->cmdsize);
        }
        
        if (patchedCount == 0) {
            addLog(@"[WRN] LC_ENCRYPTION_INFO_64 не найден.");
        }
        
        addLog(@"[TK] Ждем ответа от libloader...");
    });
}
