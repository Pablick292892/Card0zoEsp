#import <Foundation/Foundation.h>
#include <unistd.h>
#include <cstdlib>

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    
    NSLog(@"[Card0zo] Init loaded. Minimal bypass only.");
}
