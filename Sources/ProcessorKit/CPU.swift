//
//  CPU.swift
//  
//
//  Created by MacBook Pro M1 on 2021/09/01.
//

import Foundation

public struct ProcessorUsage {
    public var user: Double
    public var system: Double
    public var idle: Double
    public var nice: Double
}

// MARK: - CPU

private let HOST_CPU_LOAD_INFO_COUNT : mach_msg_type_number_t = UInt32(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)

public class CPU: NSObject {
    static let machHost = mach_host_self()
    static var hostCPULoadInfo: host_cpu_load_info {
        get {
            var size     = HOST_CPU_LOAD_INFO_COUNT
            var hostInfo = host_cpu_load_info()
            let result = withUnsafeMutablePointer(to: &hostInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                    host_statistics(machHost, HOST_CPU_LOAD_INFO, $0, &size)
                }
            }
            
            #if DEBUG
                if result != KERN_SUCCESS {
                    fatalError("ERROR - \(#file):\(#function) - kern_result_t = "
                        + "\(result)")
                }
            #endif
            
            return hostInfo
        }
    }
    
    /// previous load of cpu
    private static var loadPrevious = host_cpu_load_info()
    
    /// get overall CPU usage
    public static func systemUsage() -> ProcessorUsage {
        let load = self.hostCPULoadInfo
        
        let userDiff = Double(load.cpu_ticks.0 - loadPrevious.cpu_ticks.0)
        let sysDiff  = Double(load.cpu_ticks.1 - loadPrevious.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 - loadPrevious.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 - loadPrevious.cpu_ticks.3)
        
        let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
        
        let sys  = sysDiff  / totalTicks * 100.0
        let user = userDiff / totalTicks * 100.0
        let idle = idleDiff / totalTicks * 100.0
        let nice = niceDiff / totalTicks * 100.0
        
        loadPrevious = load
        
        return ProcessorUsage(user: user, system: sys, idle: idle, nice: nice)
    }
    
    /// get app CPU usage (% CPU on Activity Monitor)
    /// https://qiita.com/rinov/items/f30d386fb7b8b12278a5
    public static func appUsage() -> Float {
        var result: Int32
        var threadList = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        var threadCount = UInt32(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<natural_t>.size)
        var threadInfo = thread_basic_info()
        
        result = withUnsafeMutablePointer(to: &threadList) {
                $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                    task_threads(mach_task_self_, $0, &threadCount)
                }
            }

        if result != KERN_SUCCESS { return 0 }
        
        return (0 ..< Int(threadCount))
            .compactMap { index -> Float? in
                    var threadInfoCount = UInt32(THREAD_INFO_MAX)
                    result = withUnsafeMutablePointer(to: &threadInfo) {
                        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                            thread_info(threadList[index], UInt32(THREAD_BASIC_INFO), $0, &threadInfoCount)
                        }
                    }
                    if result != KERN_SUCCESS { return nil }
                    let isIdle = threadInfo.flags == TH_FLAGS_IDLE
                    
                    return !isIdle ? (Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE)) * 100 : nil
                }
                .reduce(0, +)
    }
    
    /// get each core CPU usage
    /// https://github.com/daisuke-t-jp/Mach-Swift/blob/master/Mach-Swift/Mach/Host/Processor/MachHostProcessorCPULoadInfo.swift
    public static func coreUsage() -> [ProcessorUsage] {
        var cpuCount: natural_t = 0
        var cpuInfoArray: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        
        guard KERN_SUCCESS == host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfoArray, &cpuInfoCount) else {
            return [ProcessorUsage]()
        }
        
        do {
            guard cpuCount > 0 else {
                return [ProcessorUsage]()
            }
            
            guard let cpuInfoArray = cpuInfoArray else {
                return [ProcessorUsage]()
            }
            
            defer {
                vm_deallocate(mach_task_self_, vm_address_t(cpuInfoArray.pointee), vm_size_t(cpuInfoCount))
            }
            
            var array = [ProcessorUsage]()
            for i in 0..<cpuCount {
                let index = Int32(i) * CPU_STATE_MAX
                
                let userTick = UInt32(cpuInfoArray[Int(index + CPU_STATE_USER)])
                let systemTick = UInt32(cpuInfoArray[Int(index + CPU_STATE_SYSTEM)])
                let idleTick = UInt32(cpuInfoArray[Int(index + CPU_STATE_IDLE)])
                let niceTick = UInt32(cpuInfoArray[Int(index + CPU_STATE_NICE)])
                
                let totalTick = userTick + systemTick + idleTick + niceTick
                
                let user = Double(userTick) / Double(totalTick) * 100.0
                let system = Double(systemTick) / Double(totalTick) * 100.0
                let idle = Double(idleTick) / Double(totalTick) * 100.0
                let nice = Double(niceTick) / Double(totalTick) * 100.0
                
                let usage = ProcessorUsage(user: user, system: system, idle: idle, nice: nice)
                
                array.append(usage)
            }
            
            return array
        }
    }
}
