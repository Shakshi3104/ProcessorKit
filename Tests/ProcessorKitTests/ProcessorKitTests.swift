    import XCTest
    @testable import ProcessorKit

    final class ProcessorKitTests: XCTestCase {
        let usage = CPU.systemUsage()
        
        func testSystemUsage() {
            XCTAssertTrue(usage.system >= 0.0)
        }
        
        func testUserUsage() {
            XCTAssertTrue(usage.user >= 0.0)
        }

        func testIdleUsage() {
            XCTAssertTrue(usage.idle >= 0.0)
        }

        func testAppUsage() {
            let appUsage = CPU.appUsage()
            XCTAssertTrue(appUsage >= 0.0)
        }
    }
