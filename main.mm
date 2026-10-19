#import <Foundation/Foundation.h>
#include <unistd.h>
#include <cstdlib>
#include <dlfcn.h>
#include <string.h>
#include "fishhook/fishhook.h"

#define PT_DENY_ATTACH 31

typedef int (*ptrace_t)(int _request, pid_t _pid, void *_addr, int _data);
static ptrace_t orig_ptrace = NULL;

int new_ptrace(int _request, pid_t _pid, void *_addr, int _data) {
    if (_request == PT_DENY_ATTACH) return 0;
    return orig_ptrace(_request, _pid, _addr, _data);
}

typedef void* (*CC_SHA256_t)(const void *data, unsigned int len, void *md);
typedef void* (*CC_SHA1_t)(const void *data, unsigned int len, void *md);
typedef void* (*CC_MD5_t)(const void *data, unsigned int len, void *md);

static CC_SHA256_t orig_CC_SHA256 = NULL;
static CC_SHA1_t orig_CC_SHA1 = NULL;
static CC_MD5_t orig_CC_MD5 = NULL;

void* new_CC_SHA256(const void *data, unsigned int len, void *md) {
    orig_CC_SHA256(data, len, md);
    if (md) memset(md, 0, 4);
    return md;
}

void* new_CC_SHA1(const void *data, unsigned int len, void *md) {
    orig_CC_SHA1(data, len, md);
    if (md) memset(md, 0, 4);
    return md;
}

void* new_CC_MD5(const void *data, unsigned int len, void *md) {
    orig_CC_MD5(data, len, md);
    if (md) memset(md, 0, 4);
    return md;
}

// Хукаем ВСЕ версии SecCode функций
typedef int (*SecStaticCodeCheckValidity_t)(void *staticCode, unsigned int flags, void *requirement);
typedef int (*SecStaticCodeCheckValidityWithErrors_t)(void *staticCode, unsigned int flags, void *requirement, void **errors);
typedef int (*SecCodeCheckValidity_t)(void *staticCode, unsigned int flags, void *requirement);
typedef int (*SecCodeCheckValidityWithErrors_t)(void *staticCode, unsigned int flags, void *requirement, void **errors);

static SecStaticCodeCheckValidity_t orig_SecStaticCodeCheckValidity = NULL;
static SecStaticCodeCheckValidityWithErrors_t orig_SecStaticCodeCheckValidityWithErrors = NULL;
static SecCodeCheckValidity_t orig_SecCodeCheckValidity = NULL;
static SecCodeCheckValidityWithErrors_t orig_SecCodeCheckValidityWithErrors = NULL;

int new_SecStaticCodeCheckValidity(void *staticCode, unsigned int flags, void *requirement) {
    return 0;
}

int new_SecStaticCodeCheckValidityWithErrors(void *staticCode, unsigned int flags, void *requirement, void **errors) {
    if (errors) *errors = NULL;
    return 0;
}

int new_SecCodeCheckValidity(void *staticCode, unsigned int flags, void *requirement) {
    return 0;
}

int new_SecCodeCheckValidityWithErrors(void *staticCode, unsigned int flags, void *requirement, void **errors) {
    if (errors) *errors = NULL;
    return 0;
}

__attribute__((constructor))
void Init() {
    unsetenv("DYLD_INSERT_LIBRARIES");
    unsetenv("DYLD_FRAMEWORK_PATH");
    unsetenv("DYLD_LIBRARY_PATH");
    
    struct rebinding ptrace_rebinding = {"ptrace", (void *)new_ptrace, (void **)&orig_ptrace};
    struct rebinding sha256_rebinding = {"CC_SHA256", (void *)new_CC_SHA256, (void **)&orig_CC_SHA256};
    struct rebinding sha1_rebinding = {"CC_SHA1", (void *)new_CC_SHA1, (void **)&orig_CC_SHA1};
    struct rebinding md5_rebinding = {"CC_MD5", (void *)new_CC_MD5, (void **)&orig_CC_MD5};
    struct rebinding sec1_rebinding = {"SecStaticCodeCheckValidity", (void *)new_SecStaticCodeCheckValidity, (void **)&orig_SecStaticCodeCheckValidity};
    struct rebinding sec2_rebinding = {"SecStaticCodeCheckValidityWithErrors", (void *)new_SecStaticCodeCheckValidityWithErrors, (void **)&orig_SecStaticCodeCheckValidityWithErrors};
    struct rebinding sec3_rebinding = {"SecCodeCheckValidity", (void *)new_SecCodeCheckValidity, (void **)&orig_SecCodeCheckValidity};
    struct rebinding sec4_rebinding = {"SecCodeCheckValidityWithErrors", (void *)new_SecCodeCheckValidityWithErrors, (void **)&orig_SecCodeCheckValidityWithErrors};
    
    rebind_symbols((struct rebinding[8]){ptrace_rebinding, sha256_rebinding, sha1_rebinding, md5_rebinding, 
                                          sec1_rebinding, sec2_rebinding, sec3_rebinding, sec4_rebinding}, 8);
    
    NSLog(@"[Card0zo] Init loaded. All SecCode functions hooked.");
}
