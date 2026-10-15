// Simulator-only profiling input, using protocol signatures documented by Meta idb (MIT).
// https://github.com/facebook/idb/tree/main/FBSimulatorControl/HID
// Kept outside the application and never linked into a shipping target.
#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <dlfcn.h>
#import <objc/runtime.h>
@interface NSObject (SimulatorMessaging)
+ (id)sharedServiceContextForDeveloperDir:(NSString *)dir error:(NSError **)error;
- (id)defaultDeviceSetWithError:(NSError **)error;
- (NSArray *)availableDevices;
- (id)initWithDevice:(id)device error:(NSError **)error;
- (void)sendWithMessage:(void *)message freeWhenDone:(BOOL)freeWhenDone completionQueue:(dispatch_queue_t)queue completion:(void (^)(NSError *error))completion;
@end
int main(int argc,const char **argv) { @autoreleasepool {
    if(argc!=5){fprintf(stderr,"usage: sim-hid UDID X Y holdSeconds\n");return 2;}
    if(!dlopen("/Library/Developer/PrivateFrameworks/CoreSimulator.framework/CoreSimulator",RTLD_NOW|RTLD_GLOBAL)){fprintf(stderr,"CoreSimulator: %s\n",dlerror());return 3;}
    NSString *developer = NSProcessInfo.processInfo.environment[@"DEVELOPER_DIR"] ?: @"/Applications/Xcode.app/Contents/Developer";
    NSString *kitPath = [developer stringByAppendingPathComponent:@"Library/PrivateFrameworks/SimulatorKit.framework/SimulatorKit"];
    void *kit=dlopen(kitPath.UTF8String,RTLD_NOW|RTLD_GLOBAL);
    if(!kit){fprintf(stderr,"SimulatorKit: %s\n",dlerror());return 3;}
    NSError *error=nil;
    id context=[NSClassFromString(@"SimServiceContext") sharedServiceContextForDeveloperDir:developer error:&error];
    id set=[context defaultDeviceSetWithError:&error];
    id device=nil;
    for(id d in [set availableDevices])if([[[d valueForKey:@"UDID"] UUIDString] isEqualToString:@(argv[1])])device=d;
    if(!device || ![[device valueForKey:@"name"] isEqualToString:@"Mi Keyboard Switch Latency"]){fprintf(stderr,"Dedicated test device not resolved: %s\n",error.description.UTF8String);return 4;}
    Class cls=NSClassFromString(@"SimulatorKit.SimDeviceLegacyHIDClient");
    id client=[[cls alloc] initWithDevice:device error:&error];
    if(!client){fprintf(stderr,"HID client: %s\n",error.description.UTF8String);return 5;}
    void *(*make)(CGPoint *,CGPoint *,uint32_t,NSUInteger,CGSize,uint32_t)=dlsym(kit,"IndigoHIDMessageForMouseNSEvent");
    if(!make)return 6;
    CGPoint point=CGPointMake(atof(argv[2])/402.,atof(argv[3])/874.); // Dedicated portrait iPhone17Pro geometry.
    dispatch_queue_t queue=dispatch_queue_create("mi.profile.hid",DISPATCH_QUEUE_SERIAL);
    dispatch_group_t group=dispatch_group_create();
    __block BOOL failed=NO;
    for(NSUInteger type=1;type<=2;type++){
        dispatch_group_enter(group);
        void *message=make(&point,NULL,0x32,type,CGSizeMake(1,1),0);
        [client sendWithMessage:message freeWhenDone:YES completionQueue:queue completion:^(NSError *e){if(e){failed=YES;fprintf(stderr,"HID: %s\n",e.description.UTF8String);}dispatch_group_leave(group);}];
        if(type==1){fprintf(stdout,"HID down=%.6f\n",NSProcessInfo.processInfo.systemUptime);fflush(stdout);usleep((useconds_t)(atof(argv[4])*1e6));}
    }
    if(dispatch_group_wait(group,dispatch_time(DISPATCH_TIME_NOW,5*NSEC_PER_SEC))){fprintf(stderr,"HID acknowledgment timeout\n");return 7;}
    fprintf(stdout,"HID complete=%.6f\n",NSProcessInfo.processInfo.systemUptime);
    return failed?8:0;
}}
