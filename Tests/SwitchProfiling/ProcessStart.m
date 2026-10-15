#import <os/log.h>
#import <mach/mach_time.h>
__attribute__((constructor)) static void profileEarly(void) {
    mach_timebase_info_data_t info; mach_timebase_info(&info);
    double t = (double)mach_absolute_time() * info.numer / info.denom / 1e9;
    os_log_t log = os_log_create("com.shh.mi.switchprofile", "early");
    os_log_with_type(log, OS_LOG_TYPE_DEFAULT, "SWFULL t=%{public}.6f event=process.constructor", t);
}
