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
        
        // wrapping subtraction: tick counters are 32-bit and may overflow
        let userDiff = Double(load.cpu_ticks.0 &- loadPrevious.cpu_ticks.0)
        let sysDiff  = Double(load.cpu_ticks.1 &- loadPrevious.cpu_ticks.1)
        let idleDiff = Double(load.cpu_ticks.2 &- loadPrevious.cpu_ticks.2)
        let niceDiff = Double(load.cpu_ticks.3 &- loadPrevious.cpu_ticks.3)
        
        let totalTicks = sysDiff + userDiff + niceDiff + idleDiff
        
        loadPrevious = load
        
        // no ticks elapsed since the previous call (e.g. called twice in a row)
        guard totalTicks > 0 else {
            return ProcessorUsage(user: 0, system: 0, idle: 100.0, nice: 0)
        }
        
        let sys  = sysDiff  / totalTicks * 100.0
        let user = userDiff / totalTicks * 100.0
        let idle = idleDiff / totalTicks * 100.0
        let nice = niceDiff / totalTicks * 100.0
        
        return ProcessorUsage(user: user, system: sys, idle: idle, nice: nice)
    }
    
    /// get app CPU usage (% CPU on Activity Monitor)
    /// https://qiita.com/rinov/items/f30d386fb7b8b12278a5
    public static func appUsage() -> Float {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        
        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threadList = threadList else {
            return 0
        }
        
        // task_threads returns a send right for each thread and a buffer allocated in our address space;
        // both must be released, or they leak on every call.
        defer {
            for index in 0..<Int(threadCount) {
                mach_port_deallocate(mach_task_self_, threadList[index])
            }
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: threadList),
                          vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride))
        }
        
        return (0 ..< Int(threadCount))
            .compactMap { index -> Float? in
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
                let result = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(threadInfoCount)) {
                        thread_info(threadList[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                if result != KERN_SUCCESS { return nil }
                let isIdle = threadInfo.flags & TH_FLAGS_IDLE != 0
                
                return !isIdle ? (Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE)) * 100 : nil
            }
            .reduce(0, +)
    }
    
    /// get each core CPU usage
    /// https://github.com/daisuke-t-jp/Mach-Swift/blob/master/Mach-Swift/Mach/Host/Processor/MachHostProcessorCPULoadInfo.swift
    /// previous ticks of each core (copied, because the kernel buffer is deallocated after each call)
    private static var processorPrevious: [integer_t]?
    
    public static func coreUsage() -> [ProcessorUsage] {
        var cpuCount: natural_t = 0
        var cpuInfoArray: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        
        guard KERN_SUCCESS == host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfoArray, &cpuInfoCount),
              let cpuInfoArray = cpuInfoArray else {
            return [ProcessorUsage]()
        }
        
        // host_processor_info allocates a new buffer in our address space on every call,
        // so it must be deallocated with its own address and its size in bytes.
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: cpuInfoArray),
                          vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }
        
        guard cpuCount > 0 else {
            return [ProcessorUsage]()
        }
        
        let current = Array(UnsafeBufferPointer(start: cpuInfoArray, count: Int(cpuInfoCount)))
        let previous = processorPrevious.flatMap { $0.count == current.count ? $0 : nil }
        
        var array = [ProcessorUsage]()
        for i in 0..<Int(cpuCount) {
            let index = i * Int(CPU_STATE_MAX)
            
            func tick(_ ticks: [integer_t], _ state: Int32) -> UInt32 {
                UInt32(bitPattern: ticks[index + Int(state)])
            }
            
            var userTick = tick(current, CPU_STATE_USER)
            var systemTick = tick(current, CPU_STATE_SYSTEM)
            var idleTick = tick(current, CPU_STATE_IDLE)
            var niceTick = tick(current, CPU_STATE_NICE)
            
            if let previous = previous {
                // wrapping subtraction: tick counters are 32-bit and may overflow
                userTick = userTick &- tick(previous, CPU_STATE_USER)
                systemTick = systemTick &- tick(previous, CPU_STATE_SYSTEM)
                idleTick = idleTick &- tick(previous, CPU_STATE_IDLE)
                niceTick = niceTick &- tick(previous, CPU_STATE_NICE)
            }
            
            let total = Double(userTick) + Double(systemTick) + Double(idleTick) + Double(niceTick)
            
            let usage: ProcessorUsage
            if total > 0 {
                usage = ProcessorUsage(user: Double(userTick) / total * 100.0,
                                       system: Double(systemTick) / total * 100.0,
                                       idle: Double(idleTick) / total * 100.0,
                                       nice: Double(niceTick) / total * 100.0)
            } else {
                usage = ProcessorUsage(user: 0, system: 0, idle: 100.0, nice: 0)
            }
            
            array.append(usage)
        }
        
        processorPrevious = current
        
        return array
    }
}
