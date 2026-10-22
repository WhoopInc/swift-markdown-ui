#if os(macOS)
  import AppKit
  import SwiftUI
  import XCTest

  import MarkdownUI

  @MainActor
  final class MarkdownTableLayoutTests: XCTestCase {
    func testUnconstrainedFillAvailableUsesBodyCellWidths() throws {
      guard #available(macOS 13.0, *) else {
        throw XCTSkip("Table rendering is not available")
      }

      let defaultSize = size(behavior: nil)
      let compactSize = size(behavior: .compact)
      let naturalSize = size(behavior: .fillAvailable)

      XCTAssertEqual(defaultSize.width, compactSize.width, accuracy: 1)
      XCTAssertGreaterThan(naturalSize.width, compactSize.width)
      XCTAssertLessThan(naturalSize.height, compactSize.height)
    }

    @available(macOS 13.0, *)
    private func size(behavior: TableLayoutWidthBehavior?) -> CGSize {
      let view = Markdown(
        """
        | Day | Notes |
        | --- | --- |
        | Monday | A longer body cell that should retain its natural width |
        """
      )
      .markdownBlockStyle(\.table) { configuration in
        if let behavior {
          configuration.label.markdownTableLayoutWidthBehavior(behavior)
        } else {
          configuration.label
        }
      }
      .fixedSize()

      return NSHostingView(rootView: view).fittingSize
    }
  }
#endif
