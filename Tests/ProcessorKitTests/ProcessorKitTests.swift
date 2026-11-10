    import XCTest
    @testable import ProcessorKit

    final class ProcessorKitTests: XCTestCase {
       
        func testSystemUsage() {
            let usage = CPU.systemUsage()
            XCTAssertTrue(usage.system >= 0.0)
            XCTAssertTrue(usage.system <= 100.0)
        }
        
        func testUserUsage() {
            let usage = CPU.systemUsage()
            XCTAssertTrue(usage.user >= 0.0)
            XCTAssertTrue(usage.user <= 100.0)
        }

        func testIdleUsage() {
            let usage = CPU.systemUsage()
            XCTAssertTrue(usage.idle >= 0.0)
            XCTAssertTrue(usage.idle <= 100.0)
        }

        func testAppUsage() {
            let appUsage = CPU.appUsage()
            XCTAssertTrue(appUsage >= 0.0)
        }
        
        func testMemoryUsage() {
            let memoryUsage = Memory.appUsage()
            XCTAssertNotNil(memoryUsage)
            
            if let memoryUsage = memoryUsage {
                XCTAssertTrue(memoryUsage >= 0)
            }
        }
        
        func testCoreUsage() {
            let coreUsage = CPU.coreUsage()
            XCTAssertTrue(coreUsage.count > 0)
            
            XCTAssertTrue(coreUsage[0].system >= 0.0)
            XCTAssertTrue(coreUsage[0].system <= 100.0)
        }
        
        func testCoreUsageIsStableAcrossCalls() {
            _ = CPU.coreUsage()
            let coreUsage = CPU.coreUsage()
            XCTAssertTrue(coreUsage.count > 0)
            
            for usage in coreUsage {
                XCTAssertFalse(usage.user.isNaN)
                XCTAssertTrue(usage.idle >= 0.0)
                XCTAssertTrue(usage.idle <= 100.0)
            }
        }
        
        func testCoreUsageDoesNotLeak() throws {
            _ = CPU.coreUsage()
            let before = try XCTUnwrap(Memory.appUsage())
            
            for _ in 0..<2000 {
                _ = CPU.coreUsage()
            }
            
            let after = try XCTUnwrap(Memory.appUsage())
            // Before the fix, each call leaked at least one page (16 KB on Apple silicon): ~31 MB for 2000 calls
            XCTAssertLessThan(after > before ? after - before : 0, 4 * 1024 * 1024)
        }
        
        func testAppUsageDoesNotLeak() throws {
            _ = CPU.appUsage()
            let before = try XCTUnwrap(Memory.appUsage())
            
            for _ in 0..<2000 {
                _ = CPU.appUsage()
            }
            
            let after = try XCTUnwrap(Memory.appUsage())
            XCTAssertLessThan(after > before ? after - before : 0, 4 * 1024 * 1024)
        }
    }
