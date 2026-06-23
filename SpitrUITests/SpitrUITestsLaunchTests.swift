//
//  SpitrUITestsLaunchTests.swift
//  SpitrUITests
//
//  Spitr is a menu-bar accessory app (LSUIElement) with no window on launch and
//  hard dependencies on Microphone, Speech and Accessibility permissions. A
//  scripted XCUIApplication launch is therefore meaningless here (nothing to
//  drive or screenshot) and would hang or fail on any headless CI runner, which
//  can't grant those TCC permissions. We keep the target so real, permission-free
//  UI tests can be added later, but skip this default launch test on purpose.
//

import XCTest

final class SpitrUITestsLaunchTests: XCTestCase {

    @MainActor
    func testLaunch() throws {
        throw XCTSkip("Menu-bar accessory app with permission-gated UI — no meaningful headless launch test.")
    }
}
