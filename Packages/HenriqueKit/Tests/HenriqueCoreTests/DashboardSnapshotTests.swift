import Foundation
import Testing

@testable import HenriqueCore

@Suite("Snapshot do arranque")
struct DashboardSnapshotTests {
  @Test("o painel da rede sobrevive ao disco")
  func roundTrip() throws {
    let dashboard = try ContractTests.dashboard()
    let data = try JSONEncoder.henrique().encode(dashboard)
    let back = try JSONDecoder.henrique().decode(Dashboard.self, from: data)
    #expect(back == dashboard)
  }
}
