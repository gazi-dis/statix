#import "SystemMonitor.h"
#import <Cocoa/Cocoa.h>
#include <mach/mach.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <net/if.h>
#include <ifaddrs.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/IOKitLib.h>
#include <libproc.h>

// Apple HID Event System Client declarations
typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

#ifdef __cplusplus
extern "C" {
#endif
IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t flags);
double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);
CFStringRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
#define IOHIDEventFieldBase(type) (type << 16)
#define kIOHIDEventTypeTemperature 15
#ifdef __cplusplus
}
#endif

// Apple SMC Declarations for Intel Macs
#define KERN_INDEX_SMC 2
#define SMC_CMD_READ_BYTES 5
#define SMC_CMD_READ_KEYINFO 9

typedef struct {
    uint32_t key;
    uint32_t dataSize;
    uint32_t dataType;
    uint8_t  dataAttributes;
} SMCKeyInfoData;

typedef struct {
    uint32_t key;
    uint32_t vers;
    uint32_t p8;
    uint32_t p12;
    uint8_t  p16;
} SMCVersion;

typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCKeyInfoData pKeyInfo;
    uint8_t result;
    uint8_t status;
    uint8_t data8;
    uint32_t data32;
    uint8_t bytes[32];
} SMCParamStruct;

@implementation ProcessStat
@end

@implementation SystemSnapshot

- (NSDictionary *)toDictionary {
    return @{
        @"cpu": @{
            @"totalPercent": @(self.cpuTotalPercent),
            @"userPercent": @(self.cpuUserPercent),
            @"systemPercent": @(self.cpuSystemPercent),
            @"idlePercent": @(self.cpuIdlePercent),
            @"coresPercent": self.cpuCoresPercent ?: @[],
            @"brand": self.cpuBrand ?: @"Apple Processor",
            @"physicalCores": @(self.physicalCores),
            @"logicalCores": @(self.logicalCores)
        },
        @"temperature": @{
            @"hasTemp": @(self.hasTemperature),
            @"cpuTemp": @(round(self.cpuTemperature * 10.0) / 10.0),
            @"cpuTempMax": @(round(self.cpuTemperatureMax * 10.0) / 10.0),
            @"socTemp": @(round(self.socTemperature * 10.0) / 10.0)
        },
        @"ram": @{
            @"totalBytes": @(self.ramTotalBytes),
            @"usedBytes": @(self.ramUsedBytes),
            @"freeBytes": @(self.ramFreeBytes),
            @"activeBytes": @(self.ramActiveBytes),
            @"inactiveBytes": @(self.ramInactiveBytes),
            @"wiredBytes": @(self.ramWiredBytes),
            @"compressedBytes": @(self.ramCompressedBytes),
            @"pressure": self.memoryPressure ?: @"Normal",
            @"swapTotalBytes": @(self.swapTotalBytes),
            @"swapUsedBytes": @(self.swapUsedBytes)
        },
        @"disk": @{
            @"totalBytes": @(self.diskTotalBytes),
            @"usedBytes": @(self.diskUsedBytes),
            @"freeBytes": @(self.diskFreeBytes),
            @"usedPercent": @(self.diskUsedPercent),
            @"mountPoint": self.diskMountPoint ?: @"/",
            @"volumeName": self.diskVolumeName ?: @"Macintosh HD"
        },
        @"network": @{
            @"downloadSpeed": @(self.networkDownloadSpeed),
            @"uploadSpeed": @(self.networkUploadSpeed),
            @"totalBytesIn": @(self.networkTotalBytesIn),
            @"totalBytesOut": @(self.networkTotalBytesOut)
        },
        @"battery": @{
            @"hasBattery": @(self.hasBattery),
            @"percent": @(self.batteryPercent),
            @"state": self.batteryState ?: @"Desktop",
            @"timeRemaining": @(self.batteryTimeRemainingMinutes)
        },
        @"processes": @{
            @"topCpu": self.topCpuProcesses ?: @[],
            @"topRam": self.topRamProcesses ?: @[]
        },
        @"system": @{
            @"hostname": self.hostname ?: @"Mac",
            @"architecture": self.architecture ?: @"Apple Silicon",
            @"osVersion": self.osVersion ?: @"macOS",
            @"uptime": self.uptimeString ?: @"0m",
            @"uptimeSeconds": @(self.uptimeSeconds)
        }
    };
}

- (NSString *)toJSONString {
    NSDictionary *dict = [self toDictionary];
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
    if (error || !data) {
        return @"{}";
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

@end

@interface SystemMonitor () {
    // CPU state
    host_cpu_load_info_data_t _prevTotalCpuTicks;
    BOOL _hasPrevTotalCpu;
    
    processor_info_array_t _prevCoreTicks;
    mach_msg_type_number_t _prevNumCoreTicks;
    natural_t _prevNumCPUs;
    BOOL _hasPrevCoreTicks;
    
    // Network state
    uint64_t _prevNetworkInBytes;
    uint64_t _prevNetworkOutBytes;
    NSTimeInterval _prevNetworkTimestamp;
    
    // Process state
    NSMutableDictionary<NSNumber *, NSNumber *> *_prevProcessTimes;
    NSTimeInterval _prevProcessTimestamp;
    
    // Static system info cache
    NSString *_cachedCpuBrand;
    int _cachedPhysicalCores;
    int _cachedLogicalCores;
    uint64_t _cachedTotalRam;
    NSString *_cachedHostname;
    NSString *_cachedArchitecture;
    NSString *_cachedOsVersion;
}
@end

@implementation SystemMonitor

+ (instancetype)sharedMonitor {
    static SystemMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SystemMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _prevProcessTimes = [NSMutableDictionary dictionary];
        _hasPrevTotalCpu = NO;
        _hasPrevCoreTicks = NO;
        [self initStaticInfo];
        // Prime the initial metrics sample
        [self pollCPU:nil];
        [self pollNetwork:nil];
        [self pollProcesses:nil];
    }
    return self;
}

- (void)dealloc {
    if (_hasPrevCoreTicks && _prevCoreTicks) {
        vm_deallocate(mach_task_self(), (vm_address_t)_prevCoreTicks, sizeof(integer_t) * _prevNumCoreTicks);
    }
}

- (void)initStaticInfo {
    // CPU Brand
    char brand[256];
    size_t brandSize = sizeof(brand);
    if (sysctlbyname("machdep.cpu.brand_string", brand, &brandSize, NULL, 0) == 0) {
        _cachedCpuBrand = [NSString stringWithUTF8String:brand];
    } else {
        _cachedCpuBrand = @"Apple Silicon";
    }
    
    // Core Counts
    int phys = 0, log = 0;
    size_t size = sizeof(phys);
    sysctlbyname("hw.physicalcpu", &phys, &size, NULL, 0);
    sysctlbyname("hw.logicalcpu", &log, &size, NULL, 0);
    _cachedPhysicalCores = phys > 0 ? phys : 8;
    _cachedLogicalCores = log > 0 ? log : 8;
    
    // Total RAM
    uint64_t totalRam = 0;
    size = sizeof(totalRam);
    sysctlbyname("hw.memsize", &totalRam, &size, NULL, 0);
    _cachedTotalRam = totalRam;
    
    // Architecture
#if defined(__arm64__)
    _cachedArchitecture = @"Apple Silicon (arm64)";
#elif defined(__x86_64__)
    _cachedArchitecture = @"Intel (x86_64)";
#else
    _cachedArchitecture = @"Universal";
#endif

    // Hostname
    _cachedHostname = [[NSHost currentHost] localizedName] ?: @"Mac";
    
    // OS Version
    _cachedOsVersion = [[NSProcessInfo processInfo] operatingSystemVersionString];
}

- (SystemSnapshot *)currentSnapshot {
    SystemSnapshot *snapshot = [[SystemSnapshot alloc] init];
    
    snapshot.cpuBrand = _cachedCpuBrand;
    snapshot.physicalCores = _cachedPhysicalCores;
    snapshot.logicalCores = _cachedLogicalCores;
    snapshot.architecture = _cachedArchitecture;
    snapshot.hostname = _cachedHostname;
    snapshot.osVersion = _cachedOsVersion;
    
    [self pollCPU:snapshot];
    [self pollTemperature:snapshot];
    [self pollRAM:snapshot];
    [self pollDisk:snapshot];
    [self pollNetwork:snapshot];
    [self pollBattery:snapshot];
    [self pollProcesses:snapshot];
    [self pollUptime:snapshot];
    
    return snapshot;
}

#pragma mark - CPU

- (void)pollCPU:(SystemSnapshot *)snapshot {
    // 1. Total CPU load
    host_cpu_load_info_data_t curCpuInfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    kern_return_t kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&curCpuInfo, &count);
    
    if (kr == KERN_SUCCESS) {
        if (_hasPrevTotalCpu && snapshot) {
            uint64_t deltaUser = curCpuInfo.cpu_ticks[CPU_STATE_USER] - _prevTotalCpuTicks.cpu_ticks[CPU_STATE_USER];
            uint64_t deltaSystem = curCpuInfo.cpu_ticks[CPU_STATE_SYSTEM] - _prevTotalCpuTicks.cpu_ticks[CPU_STATE_SYSTEM];
            uint64_t deltaNice = curCpuInfo.cpu_ticks[CPU_STATE_NICE] - _prevTotalCpuTicks.cpu_ticks[CPU_STATE_NICE];
            uint64_t deltaIdle = curCpuInfo.cpu_ticks[CPU_STATE_IDLE] - _prevTotalCpuTicks.cpu_ticks[CPU_STATE_IDLE];
            uint64_t total = deltaUser + deltaSystem + deltaNice + deltaIdle;
            
            if (total > 0) {
                snapshot.cpuUserPercent = ((double)deltaUser / total) * 100.0;
                snapshot.cpuSystemPercent = ((double)deltaSystem / total) * 100.0;
                snapshot.cpuIdlePercent = ((double)deltaIdle / total) * 100.0;
                snapshot.cpuTotalPercent = snapshot.cpuUserPercent + snapshot.cpuSystemPercent + (((double)deltaNice / total) * 100.0);
            }
        }
        _prevTotalCpuTicks = curCpuInfo;
        _hasPrevTotalCpu = YES;
    }
    
    // 2. Per-core CPU load
    natural_t numCPUs = 0;
    processor_info_array_t curCoreTicks;
    mach_msg_type_number_t numCoreTicks;
    kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &curCoreTicks, &numCoreTicks);
    
    if (kr == KERN_SUCCESS) {
        if (_hasPrevCoreTicks && snapshot && _prevNumCPUs == numCPUs) {
            NSMutableArray<NSNumber *> *coresArray = [NSMutableArray arrayWithCapacity:numCPUs];
            for (unsigned int i = 0; i < numCPUs; ++i) {
                integer_t u1 = _prevCoreTicks[CPU_STATE_MAX * i + CPU_STATE_USER];
                integer_t s1 = _prevCoreTicks[CPU_STATE_MAX * i + CPU_STATE_SYSTEM];
                integer_t n1 = _prevCoreTicks[CPU_STATE_MAX * i + CPU_STATE_NICE];
                integer_t id1 = _prevCoreTicks[CPU_STATE_MAX * i + CPU_STATE_IDLE];

                integer_t u2 = curCoreTicks[CPU_STATE_MAX * i + CPU_STATE_USER];
                integer_t s2 = curCoreTicks[CPU_STATE_MAX * i + CPU_STATE_SYSTEM];
                integer_t n2 = curCoreTicks[CPU_STATE_MAX * i + CPU_STATE_NICE];
                integer_t id2 = curCoreTicks[CPU_STATE_MAX * i + CPU_STATE_IDLE];

                uint64_t total = (u2 - u1) + (s2 - s1) + (n2 - n1) + (id2 - id1);
                double corePercent = 0.0;
                if (total > 0) {
                    corePercent = ((double)((u2 - u1) + (s2 - s1) + (n2 - n1)) / total) * 100.0;
                }
                [coresArray addObject:@(corePercent)];
            }
            snapshot.cpuCoresPercent = coresArray;
        }
        
        if (_hasPrevCoreTicks && _prevCoreTicks) {
            vm_deallocate(mach_task_self(), (vm_address_t)_prevCoreTicks, sizeof(integer_t) * _prevNumCoreTicks);
        }
        _prevCoreTicks = curCoreTicks;
        _prevNumCoreTicks = numCoreTicks;
        _prevNumCPUs = numCPUs;
        _hasPrevCoreTicks = YES;
    }
}

#pragma mark - Temperature (Apple Silicon + Intel)

static uint32_t stringToSMCKey(const char *str) {
    uint32_t key = 0;
    for (int i = 0; i < 4; i++) {
        key = (key << 8) | (uint8_t)str[i];
    }
    return key;
}

- (BOOL)readIntelSMCTemps:(double *)outCpuAvg max:(double *)outCpuMax {
    mach_port_t masterPort;
    if (@available(macOS 12.0, *)) {
        masterPort = kIOMainPortDefault;
    } else {
        masterPort = kIOMasterPortDefault;
    }
    io_service_t service = IOServiceGetMatchingService(masterPort, IOServiceMatching("AppleSMC"));
    if (!service) return NO;
    
    io_connect_t conn = 0;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &conn);
    IOObjectRelease(service);
    if (kr != kIOReturnSuccess || !conn) return NO;
    
    const char *keys[] = {"TC0P", "TC0D", "TC0E", "TC0F", "TCXC", "TC1C", "TC2C", "TC3C", "TC4C"};
    int numKeys = sizeof(keys) / sizeof(keys[0]);
    double sum = 0;
    int count = 0;
    double maxVal = 0;
    
    for (int i = 0; i < numKeys; i++) {
        SMCParamStruct input;
        SMCParamStruct output;
        memset(&input, 0, sizeof(input));
        memset(&output, 0, sizeof(output));
        
        input.key = stringToSMCKey(keys[i]);
        input.data8 = SMC_CMD_READ_KEYINFO;
        size_t outSize = sizeof(output);
        
        if (IOConnectCallStructMethod(conn, KERN_INDEX_SMC, &input, sizeof(input), &output, &outSize) == kIOReturnSuccess) {
            input.pKeyInfo = output.pKeyInfo;
            input.data8 = SMC_CMD_READ_BYTES;
            outSize = sizeof(output);
            
            if (IOConnectCallStructMethod(conn, KERN_INDEX_SMC, &input, sizeof(input), &output, &outSize) == kIOReturnSuccess) {
                // Parse sp78 format: 1 signed bit, 7 integer bits, 8 fraction bits
                double temp = (double)((int16_t)((output.bytes[0] << 8) | output.bytes[1])) / 256.0;
                if (temp > 10.0 && temp < 125.0) {
                    sum += temp;
                    count++;
                    if (temp > maxVal) maxVal = temp;
                }
            }
        }
    }
    IOServiceClose(conn);
    
    if (count > 0) {
        if (outCpuAvg) *outCpuAvg = sum / count;
        if (outCpuMax) *outCpuMax = maxVal;
        return YES;
    }
    return NO;
}

- (BOOL)readAppleSiliconTemps:(double *)outCpuAvg max:(double *)outCpuMax soc:(double *)outSoc {
    IOHIDEventSystemClientRef client = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (!client) return NO;
    
    NSDictionary *match = @{
        @"PrimaryUsagePage": @(0xff00),
        @"PrimaryUsage": @(5)
    };
    IOHIDEventSystemClientSetMatching(client, (__bridge CFDictionaryRef)match);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(client);
    if (!services) {
        CFRelease(client);
        return NO;
    }
    
    CFIndex count = CFArrayGetCount(services);
    double cpuSum = 0;
    int cpuCount = 0;
    double maxTemp = 0;
    double socTemp = 0;
    
    for (CFIndex i = 0; i < count; i++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, i);
        CFStringRef productRef = IOHIDServiceClientCopyProperty(service, CFSTR("Product"));
        if (!productRef) continue;
        NSString *product = (__bridge NSString *)productRef;
        
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, kIOHIDEventTypeTemperature, 0, 0);
        if (event) {
            double temp = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(kIOHIDEventTypeTemperature));
            if (temp > 5.0 && temp < 125.0) {
                if ([product containsString:@"pACC"] || [product containsString:@"eACC"] || [product containsString:@"CPU"]) {
                    cpuSum += temp;
                    cpuCount++;
                    if (temp > maxTemp) maxTemp = temp;
                } else if ([product containsString:@"SOC"] || [product containsString:@"PMGR SOC"]) {
                    if (socTemp == 0) socTemp = temp;
                }
            }
            CFRelease(event);
        }
        CFRelease(productRef);
    }
    CFRelease(services);
    CFRelease(client);
    
    if (cpuCount > 0) {
        if (outCpuAvg) *outCpuAvg = cpuSum / cpuCount;
        if (outCpuMax) *outCpuMax = maxTemp;
        if (outSoc) *outSoc = socTemp > 0 ? socTemp : (cpuSum / cpuCount);
        return YES;
    }
    if (socTemp > 0) {
        if (outCpuAvg) *outCpuAvg = socTemp;
        if (outCpuMax) *outCpuMax = socTemp;
        if (outSoc) *outSoc = socTemp;
        return YES;
    }
    return NO;
}

- (void)pollTemperature:(SystemSnapshot *)snapshot {
    if (!snapshot) return;
    
    double cpuAvg = 0.0, cpuMax = 0.0, soc = 0.0;
    
    // 1. Try Apple Silicon HID Temperature Sensors
    if ([self readAppleSiliconTemps:&cpuAvg max:&cpuMax soc:&soc]) {
        snapshot.hasTemperature = YES;
        snapshot.cpuTemperature = cpuAvg;
        snapshot.cpuTemperatureMax = cpuMax;
        snapshot.socTemperature = soc;
        return;
    }
    
    // 2. Try Intel AppleSMC
    if ([self readIntelSMCTemps:&cpuAvg max:&cpuMax]) {
        snapshot.hasTemperature = YES;
        snapshot.cpuTemperature = cpuAvg;
        snapshot.cpuTemperatureMax = cpuMax;
        snapshot.socTemperature = cpuAvg;
        return;
    }
    
    snapshot.hasTemperature = NO;
    snapshot.cpuTemperature = 0.0;
    snapshot.cpuTemperatureMax = 0.0;
    snapshot.socTemperature = 0.0;
}

#pragma mark - RAM

- (void)pollRAM:(SystemSnapshot *)snapshot {
    snapshot.ramTotalBytes = _cachedTotalRam;
    
    vm_size_t pageSize;
    mach_port_t machPort = mach_host_self();
    mach_msg_type_number_t count = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
    vm_statistics64_data_t vmStats;
    host_page_size(machPort, &pageSize);
    
    if (host_statistics64(machPort, HOST_VM_INFO64, (host_info64_t)&vmStats, &count) == KERN_SUCCESS) {
        uint64_t free = ((uint64_t)vmStats.free_count + (uint64_t)vmStats.speculative_count) * pageSize;
        uint64_t active = (uint64_t)vmStats.active_count * pageSize;
        uint64_t inactive = (uint64_t)vmStats.inactive_count * pageSize;
        uint64_t wired = (uint64_t)vmStats.wire_count * pageSize;
        uint64_t compressed = (uint64_t)vmStats.compressor_page_count * pageSize;
        uint64_t used = active + inactive + wired + compressed;
        
        snapshot.ramActiveBytes = active;
        snapshot.ramInactiveBytes = inactive;
        snapshot.ramWiredBytes = wired;
        snapshot.ramCompressedBytes = compressed;
        snapshot.ramFreeBytes = free;
        snapshot.ramUsedBytes = used;
    }
    
    // Memory Pressure
    int pressureLevel = 1;
    size_t pSize = sizeof(pressureLevel);
    if (sysctlbyname("kern.memorystatus_vm_pressure_level", &pressureLevel, &pSize, NULL, 0) == 0) {
        if (pressureLevel >= 4) {
            snapshot.memoryPressure = @"Critical";
        } else if (pressureLevel >= 2) {
            snapshot.memoryPressure = @"Warning";
        } else {
            snapshot.memoryPressure = @"Normal";
        }
    } else {
        snapshot.memoryPressure = @"Normal";
    }
    
    // Swap
    struct xsw_usage swap;
    size_t sSize = sizeof(swap);
    if (sysctlbyname("vm.swapusage", &swap, &sSize, NULL, 0) == 0) {
        snapshot.swapTotalBytes = swap.xsu_total;
        snapshot.swapUsedBytes = swap.xsu_used;
    }
}

#pragma mark - Disk

- (void)pollDisk:(SystemSnapshot *)snapshot {
    struct statfs stats;
    if (statfs("/", &stats) == 0) {
        uint64_t total = stats.f_blocks * stats.f_bsize;
        uint64_t free = stats.f_bavail * stats.f_bsize;
        uint64_t used = total > free ? (total - free) : 0;
        
        snapshot.diskTotalBytes = total;
        snapshot.diskFreeBytes = free;
        snapshot.diskUsedBytes = used;
        snapshot.diskUsedPercent = total > 0 ? ((double)used / total) * 100.0 : 0.0;
        snapshot.diskMountPoint = @"/";
        snapshot.diskVolumeName = [NSString stringWithUTF8String:stats.f_mntonname] ?: @"Macintosh HD";
    }
}

#pragma mark - Network

- (void)pollNetwork:(SystemSnapshot *)snapshot {
    struct ifaddrs *ifap;
    uint64_t totalIn = 0;
    uint64_t totalOut = 0;
    
    if (getifaddrs(&ifap) == 0) {
        for (struct ifaddrs *ifa = ifap; ifa != NULL; ifa = ifa->ifa_next) {
            if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_LINK) {
                struct if_data *if_data = (struct if_data *)ifa->ifa_data;
                if (if_data && (ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_LOOPBACK)) {
                    totalIn += if_data->ifi_ibytes;
                    totalOut += if_data->ifi_obytes;
                }
            }
        }
        freeifaddrs(ifap);
    }
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (_prevNetworkTimestamp > 0 && snapshot) {
        NSTimeInterval dt = now - _prevNetworkTimestamp;
        if (dt > 0.1) {
            uint64_t deltaIn = totalIn >= _prevNetworkInBytes ? (totalIn - _prevNetworkInBytes) : 0;
            uint64_t deltaOut = totalOut >= _prevNetworkOutBytes ? (totalOut - _prevNetworkOutBytes) : 0;
            
            snapshot.networkDownloadSpeed = (double)deltaIn / dt;
            snapshot.networkUploadSpeed = (double)deltaOut / dt;
        }
    }
    
    if (snapshot) {
        snapshot.networkTotalBytesIn = totalIn;
        snapshot.networkTotalBytesOut = totalOut;
    }
    
    _prevNetworkInBytes = totalIn;
    _prevNetworkOutBytes = totalOut;
    _prevNetworkTimestamp = now;
}

#pragma mark - Battery

- (void)pollBattery:(SystemSnapshot *)snapshot {
    CFTypeRef blob = IOPSCopyPowerSourcesInfo();
    CFArrayRef sources = IOPSCopyPowerSourcesList(blob);
    
    if (sources && CFArrayGetCount(sources) > 0) {
        CFDictionaryRef psource = IOPSGetPowerSourceDescription(blob, CFArrayGetValueAtIndex(sources, 0));
        if (psource) {
            snapshot.hasBattery = YES;
            NSNumber *capacity = (__bridge NSNumber *)CFDictionaryGetValue(psource, CFSTR(kIOPSCurrentCapacityKey));
            snapshot.batteryPercent = [capacity intValue];
            
            NSString *state = (__bridge NSString *)CFDictionaryGetValue(psource, CFSTR(kIOPSPowerSourceStateKey));
            NSNumber *isCharging = (__bridge NSNumber *)CFDictionaryGetValue(psource, CFSTR(kIOPSIsChargingKey));
            
            if ([isCharging boolValue]) {
                snapshot.batteryState = @"Şarj Oluyor";
                NSNumber *timeToFull = (__bridge NSNumber *)CFDictionaryGetValue(psource, CFSTR(kIOPSTimeToFullChargeKey));
                snapshot.batteryTimeRemainingMinutes = [timeToFull intValue];
            } else if ([state isEqualToString:(__bridge NSString *)CFSTR(kIOPSACPowerValue)]) {
                snapshot.batteryState = @"Adaptör Bağlı";
                snapshot.batteryTimeRemainingMinutes = 0;
            } else {
                snapshot.batteryState = @"Pilde Çalışıyor";
                NSNumber *timeToEmpty = (__bridge NSNumber *)CFDictionaryGetValue(psource, CFSTR(kIOPSTimeToEmptyKey));
                snapshot.batteryTimeRemainingMinutes = [timeToEmpty intValue];
            }
        }
        CFRelease(sources);
    } else {
        snapshot.hasBattery = NO;
        snapshot.batteryState = @"Masaüstü Güç Kaynağı";
        snapshot.batteryPercent = 100;
        snapshot.batteryTimeRemainingMinutes = 0;
    }
    if (blob) CFRelease(blob);
}

#pragma mark - Processes

- (void)pollProcesses:(SystemSnapshot *)snapshot {
    int numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
    if (numberOfProcesses <= 0) return;
    
    pid_t *pids = malloc(sizeof(pid_t) * numberOfProcesses);
    if (!pids) return;
    
    numberOfProcesses = proc_listpids(PROC_ALL_PIDS, 0, pids, sizeof(pid_t) * numberOfProcesses);
    
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval dt = _prevProcessTimestamp > 0 ? (now - _prevProcessTimestamp) : 1.0;
    if (dt <= 0.05) dt = 1.0;
    
    NSMutableDictionary<NSNumber *, NSNumber *> *currentProcessTimes = [NSMutableDictionary dictionaryWithCapacity:numberOfProcesses];
    NSMutableArray<ProcessStat *> *processList = [NSMutableArray arrayWithCapacity:numberOfProcesses];
    
    for (int i = 0; i < numberOfProcesses; ++i) {
        pid_t pid = pids[i];
        if (pid <= 0) continue;
        
        char pathBuffer[PROC_PIDPATHINFO_MAXSIZE];
        if (proc_name(pid, pathBuffer, sizeof(pathBuffer)) <= 0) continue;
        
        struct proc_taskinfo taskInfo;
        if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, sizeof(taskInfo)) <= 0) continue;
        
        uint64_t cpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system;
        currentProcessTimes[@(pid)] = @(cpuTime);
        
        double cpuPercent = 0.0;
        NSNumber *prevTimeNum = _prevProcessTimes[@(pid)];
        if (prevTimeNum) {
            uint64_t prevTime = [prevTimeNum unsignedLongLongValue];
            if (cpuTime >= prevTime) {
                double deltaSec = (double)(cpuTime - prevTime) / 1000000000.0;
                cpuPercent = (deltaSec / dt) * 100.0;
                if (cpuPercent > 1000.0) cpuPercent = 100.0;
            }
        }
        
        ProcessStat *stat = [[ProcessStat alloc] init];
        stat.pid = pid;
        stat.name = [NSString stringWithUTF8String:pathBuffer];
        stat.cpuPercent = cpuPercent;
        stat.residentMemoryBytes = taskInfo.pti_resident_size;
        [processList addObject:stat];
    }
    free(pids);
    
    _prevProcessTimes = currentProcessTimes;
    _prevProcessTimestamp = now;
    
    if (!snapshot) return;
    
    // Sort Top 5 by CPU
    NSArray<ProcessStat *> *sortedByCpu = [processList sortedArrayUsingComparator:^NSComparisonResult(ProcessStat *a, ProcessStat *b) {
        if (a.cpuPercent < b.cpuPercent) return NSOrderedDescending;
        if (a.cpuPercent > b.cpuPercent) return NSOrderedAscending;
        return NSOrderedSame;
    }];
    
    NSMutableArray *topCpu = [NSMutableArray array];
    for (NSUInteger i = 0; i < MIN(sortedByCpu.count, (NSUInteger)5); ++i) {
        ProcessStat *p = sortedByCpu[i];
        [topCpu addObject:@{
            @"pid": @(p.pid),
            @"name": p.name,
            @"cpu": @(round(p.cpuPercent * 10.0) / 10.0),
            @"ramMB": @(p.residentMemoryBytes / (1024 * 1024))
        }];
    }
    snapshot.topCpuProcesses = topCpu;
    
    // Sort Top 5 by RAM
    NSArray<ProcessStat *> *sortedByRam = [processList sortedArrayUsingComparator:^NSComparisonResult(ProcessStat *a, ProcessStat *b) {
        if (a.residentMemoryBytes < b.residentMemoryBytes) return NSOrderedDescending;
        if (a.residentMemoryBytes > b.residentMemoryBytes) return NSOrderedAscending;
        return NSOrderedSame;
    }];
    
    NSMutableArray *topRam = [NSMutableArray array];
    for (NSUInteger i = 0; i < MIN(sortedByRam.count, (NSUInteger)5); ++i) {
        ProcessStat *p = sortedByRam[i];
        [topRam addObject:@{
            @"pid": @(p.pid),
            @"name": p.name,
            @"cpu": @(round(p.cpuPercent * 10.0) / 10.0),
            @"ramMB": @(p.residentMemoryBytes / (1024 * 1024))
        }];
    }
    snapshot.topRamProcesses = topRam;
}

#pragma mark - Uptime

- (void)pollUptime:(SystemSnapshot *)snapshot {
    struct timeval boottime;
    size_t size = sizeof(boottime);
    if (sysctlbyname("kern.boottime", &boottime, &size, NULL, 0) == 0) {
        time_t now = time(NULL);
        time_t uptime = now - boottime.tv_sec;
        if (uptime < 0) uptime = 0;
        
        snapshot.uptimeSeconds = (uint64_t)uptime;
        
        long days = uptime / 86400;
        long hours = (uptime % 86400) / 3600;
        long mins = (uptime % 3600) / 60;
        
        if (days > 0) {
            snapshot.uptimeString = [NSString stringWithFormat:@"%ld gün, %ld sa, %ld dk", days, hours, mins];
        } else if (hours > 0) {
            snapshot.uptimeString = [NSString stringWithFormat:@"%ld saat, %ld dk", hours, mins];
        } else {
            snapshot.uptimeString = [NSString stringWithFormat:@"%ld dk", mins];
        }
    }
}

@end
