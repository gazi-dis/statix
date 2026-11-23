#import <Foundation/Foundation.h>

@interface ProcessStat : NSObject
@property (nonatomic, assign) pid_t pid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double cpuPercent;
@property (nonatomic, assign) uint64_t residentMemoryBytes;
@end

@interface SystemSnapshot : NSObject
// CPU
@property (nonatomic, assign) double cpuTotalPercent;
@property (nonatomic, assign) double cpuUserPercent;
@property (nonatomic, assign) double cpuSystemPercent;
@property (nonatomic, assign) double cpuIdlePercent;
@property (nonatomic, copy) NSArray<NSNumber *> *cpuCoresPercent;
@property (nonatomic, copy) NSString *cpuBrand;
@property (nonatomic, assign) int physicalCores;
@property (nonatomic, assign) int logicalCores;

// RAM
@property (nonatomic, assign) uint64_t ramTotalBytes;
@property (nonatomic, assign) uint64_t ramUsedBytes;
@property (nonatomic, assign) uint64_t ramFreeBytes;
@property (nonatomic, assign) uint64_t ramActiveBytes;
@property (nonatomic, assign) uint64_t ramInactiveBytes;
@property (nonatomic, assign) uint64_t ramWiredBytes;
@property (nonatomic, assign) uint64_t ramCompressedBytes;
@property (nonatomic, copy) NSString *memoryPressure; // "Normal", "Warning", "Critical"
@property (nonatomic, assign) uint64_t swapTotalBytes;
@property (nonatomic, assign) uint64_t swapUsedBytes;

// Disk
@property (nonatomic, assign) uint64_t diskTotalBytes;
@property (nonatomic, assign) uint64_t diskUsedBytes;
@property (nonatomic, assign) uint64_t diskFreeBytes;
@property (nonatomic, assign) double diskUsedPercent;
@property (nonatomic, copy) NSString *diskMountPoint;
@property (nonatomic, copy) NSString *diskVolumeName;

// Network
@property (nonatomic, assign) double networkDownloadSpeed; // bytes/sec
@property (nonatomic, assign) double networkUploadSpeed;   // bytes/sec
@property (nonatomic, assign) uint64_t networkTotalBytesIn;
@property (nonatomic, assign) uint64_t networkTotalBytesOut;

// Battery
@property (nonatomic, assign) BOOL hasBattery;
@property (nonatomic, assign) int batteryPercent;
@property (nonatomic, copy) NSString *batteryState; // "Charging", "Charged", "Discharging", "AC Connected"
@property (nonatomic, assign) int batteryTimeRemainingMinutes;

// Processes
@property (nonatomic, copy) NSArray<NSDictionary *> *topCpuProcesses;
@property (nonatomic, copy) NSArray<NSDictionary *> *topRamProcesses;

// System Info
@property (nonatomic, copy) NSString *hostname;
@property (nonatomic, copy) NSString *architecture;
@property (nonatomic, copy) NSString *osVersion;
@property (nonatomic, copy) NSString *uptimeString;
@property (nonatomic, assign) uint64_t uptimeSeconds;

- (NSDictionary *)toDictionary;
- (NSString *)toJSONString;
@end

@interface SystemMonitor : NSObject
+ (instancetype)sharedMonitor;
- (SystemSnapshot *)currentSnapshot;
@end
