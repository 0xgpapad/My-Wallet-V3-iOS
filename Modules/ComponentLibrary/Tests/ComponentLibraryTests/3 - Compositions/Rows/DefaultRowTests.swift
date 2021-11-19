@testable import ComponentLibrary
import SnapshotTesting
import SwiftUI
import XCTest

final class DefaultRowTests: XCTestCase {

    func testSnapshot() {
        let view = VStack(spacing: Spacing.baseline) {
            DefaultRow_Previews.previews
        }
        .fixedSize()
        .padding()

        assertSnapshots(
            matching: view,
            as: [
                .image(layout: .sizeThatFits, traits: UITraitCollection(userInterfaceStyle: .light)),
                .image(layout: .sizeThatFits, traits: UITraitCollection(userInterfaceStyle: .dark))
            ]
        )
    }
}