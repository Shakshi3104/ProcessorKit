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
    }
