//
//  TestSupport.swift
//  SpitrTests
//
//  Shared helpers for the test suites.
//

import Foundation
@testable import Spitr

/// A throwaway, isolated UserDefaults so each test starts from a clean slate and
/// never touches the real app preferences.
func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "spitr.tests.\(UUID().uuidString)")!
}
