    import XCTest
    @testable import ProcessorKit

    final class ProcessorKitTests: XCTestCase {
       
        func testSystemUsage() {
            let usage = CPU.systemUsage()
            XCTAssertTrue(usage.system >= 0.0)
        }
        
        func testUserUsage() {
            let usage = CPU.systemUsage()
            XCTAssertTrue(usage.user >= 0.0)
        }

        func testIdleUsage() {
            let usage = CPU.systemUsage()
            XCTAssertTrue(usage.idle >= 0.0)
        }

        func testAppUsage() {
            let appUsage = CPU.appUsage()
            XCTAssertTrue(appUsage >= 0.0)
        }
    }
