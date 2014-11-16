//
//  DisableTurboBoost.c
//  DisableTurboBoost
//
//  Created by Matthias Frick on 28.12.13.
//  Copyright (c) 2013 Matthias Frick. All rights reserved.
//

#include <IOKit/IOLib.h>
#include <IOKit/pwr_mgt/RootDomain.h>
#include <IOKit/pwr_mgt/IOPM.h>
#include <IOKit/IOService.h>
#include <IOKit/IONotifier.h>
#define ALLOW_SLEEP 1

IONotifier *notifier;

extern "C" {
#include <libkern/libkern.h>
#include <mach/mach_types.h>
#include <i386/proc_reg.h>
extern void mp_rendezvous_no_intrs(
                                   void (*action_func)(void *),
                                   void *arg);

const uint64_t expectedFeatures  = 0x850089LL;
const uint64_t disableTurboBoost = 0x4000000000LL;


static void disable_tb(__unused void * param_not_used) {
	wrmsr64(MSR_IA32_MISC_ENABLE, rdmsr64(MSR_IA32_MISC_ENABLE) | disableTurboBoost);
}

static void enable_tb(__unused void * param_not_used) {
	wrmsr64(MSR_IA32_MISC_ENABLE, rdmsr64(MSR_IA32_MISC_ENABLE) & ~disableTurboBoost);
}
    
IOReturn mySleepHandler( void * target, void * refCon,
                            UInt32 messageType, IOService * provider,
                            void * messageArgument, vm_size_t argSize )
    {
        // IOLog("Got sleep/wake notice.  Message type was %d\n", messageType);
#if ALLOW_SLEEP
        acknowledgeSleepWakeNotification(refCon);
        
        // Just sending out the kernel start routine again.
        uint64_t prev = rdmsr64(MSR_IA32_MISC_ENABLE);
        mp_rendezvous_no_intrs(disable_tb, NULL);
        printf("Disabled Turbo Boost: %llx -> %llx\n", prev, rdmsr64(MSR_IA32_MISC_ENABLE));
#else
        vetoSleepWakeNotification(refCon);
#endif
        return 0;
    }

kern_return_t DisableTurboBoost_start(kmod_info_t * ki, void *d);
kern_return_t DisableTurboBoost_stop(kmod_info_t *ki, void *d);

kern_return_t DisableTurboBoost_start(kmod_info_t * ki, void *d)
{
    uint64_t prev = rdmsr64(MSR_IA32_MISC_ENABLE);
	mp_rendezvous_no_intrs(disable_tb, NULL);
	printf("Disabled Turbo Boost: %llx -> %llx\n", prev, rdmsr64(MSR_IA32_MISC_ENABLE));
    
    // Sleep Notifier
    void *myself = NULL; // Would pass the self pointer here if in a class instance
    
    // Register to sleep notifier
    notifier = registerPrioritySleepWakeInterest(&mySleepHandler, myself, NULL);
    
	return KERN_SUCCESS;
}



kern_return_t DisableTurboBoost_stop(kmod_info_t *ki, void *d)
{
    uint64_t prev = rdmsr64(MSR_IA32_MISC_ENABLE);
	mp_rendezvous_no_intrs(enable_tb, NULL);
    
    // remove itself or else we might get a kernel panic
    notifier->remove();
	printf("Re-enabled Turbo Boost: %llx -> %llx\n", prev, rdmsr64(MSR_IA32_MISC_ENABLE));
    return KERN_SUCCESS;
}
    
}
