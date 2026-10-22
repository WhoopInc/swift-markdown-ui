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

    func testUnconstrainedRemeasurementKeepsEveryRowInsideMeasuredTable() throws {
      guard #available(macOS 13.0, *) else {
        throw XCTSkip("Table rendering is not available")
      }

      let placed = expectation(description: "All table cells have been placed")
      var recordedBounds: [Cell: CGRect] = [:]
      let view = Markdown(
        """
        | Day | Sleep | Recovery | Notes |
        | --- | --- | --- | --- |
        | October 18 | 8 hours 12 minutes | 100 percent | Feeling well rested |
        | October 19 | 7 hours 30 minutes | 86 percent | Earlier wake up time |
        | October 20 | 8 hours 45 minutes | 95 percent | Final row stays fully visible |
        """
      )
      .markdownBlockStyle(\.table) { configuration in
        RemeasuredTableLayout {
          configuration.label.markdownTableLayoutWidthBehavior(.fillAvailable)
        }
        .background {
          GeometryReader { proxy in
            Color.clear.preference(
              key: CellBoundsPreference.self,
              value: [.table: proxy.frame(in: .local)]
            )
          }
        }
        .coordinateSpace(name: "table")
      }
      .markdownBlockStyle(\.tableCell) { configuration in
        configuration.label.background {
          GeometryReader { proxy in
            Color.clear.preference(
              key: CellBoundsPreference.self,
              value: [
                Cell(row: configuration.row, column: configuration.column):
                  proxy.frame(in: .named("table"))
              ]
            )
          }
        }
      }
      .fixedSize()
      .onPreferenceChange(CellBoundsPreference.self) { bounds in
        guard bounds.count == 17, bounds[.table]?.height ?? 0 > 0 else { return }
        if recordedBounds.isEmpty {
          placed.fulfill()
        }
        recordedBounds = bounds
      }
      let hostingView = NSHostingView(rootView: view)
      hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
      hostingView.layoutSubtreeIfNeeded()
      wait(for: [placed], timeout: 2)

      let tableBounds = try XCTUnwrap(recordedBounds[.table])
      let firstBodyCell = try XCTUnwrap(recordedBounds[Cell(row: 1, column: 0)])
      let lastBodyCell = try XCTUnwrap(recordedBounds[Cell(row: 3, column: 0)])
      XCTAssertEqual(firstBodyCell.height, lastBodyCell.height, accuracy: 1)
      for (cell, bounds) in recordedBounds where cell != .table {
        XCTAssertLessThanOrEqual(bounds.maxY, tableBounds.maxY + 1, "Clipped cell: \(cell)")
        XCTAssertGreaterThanOrEqual(bounds.minY, tableBounds.minY - 1)
      }
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

  private struct Cell: Hashable {
    let row: Int
    let column: Int

    static let table = Cell(row: -1, column: -1)
  }

  private struct CellBoundsPreference: PreferenceKey {
    static let defaultValue: [Cell: CGRect] = [:]

    static func reduce(value: inout [Cell: CGRect], nextValue: () -> [Cell: CGRect]) {
      value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
  }

  @available(macOS 13.0, *)
  private struct RemeasuredTableLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
      let size = subviews[0].sizeThatFits(.unspecified)
      // Replace the table's pending measurement before placing it at its natural size.
      _ = subviews[0].sizeThatFits(.init(width: 200, height: nil))
      return size
    }

    func placeSubviews(
      in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
    ) {
      _ = subviews[0].sizeThatFits(.init(width: 200, height: nil))
      subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: .unspecified)
    }
  }
#endif
