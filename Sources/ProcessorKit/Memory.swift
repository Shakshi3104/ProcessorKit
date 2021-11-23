//
//  Memory.swift
//  
//
//  Created by MacBook Pro M1 on 2021/11/23.
//

import Foundation

// MARK: - Memory
/// https://qiita.com/rinov/items/f30d386fb7b8b12278a5
public class Memory: NSObject {
    /// get app memory usage
    public static func appUsage() -> UInt64? {
        var info = mach_task_basic_info()
        
        var count = UInt32(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            task_info(mach_task_self_,
                      task_flavor_t(MACH_TASK_BASIC_INFO),
                      $0.withMemoryRebound(to: Int32.self,
                                           capacity: 1, { pointer in
                        UnsafeMutablePointer<Int32>(pointer)
                
            }), &count)
        }
        
        return result == KERN_SUCCESS ? info.resident_size : nil
    }
}
