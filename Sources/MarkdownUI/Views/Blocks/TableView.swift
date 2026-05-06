import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableView: View {
  @Environment(\.theme.table) private var table

  private let columnAlignments: [RawTableColumnAlignment]
  private let rows: [RawTableRow]

  init(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow]) {
    self.columnAlignments = columnAlignments
    self.rows = rows
  }

  var body: some View {
    self.table.makeBody(
      configuration: .init(
        label: .init(self.label),
        content: .init(block: .table(columnAlignments: self.columnAlignments, rows: self.rows))
      )
    )
  }

  private var label: some View {
    MarkdownTableLayoutView(
      columnAlignments: self.columnAlignments,
      rows: self.rows
    )
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct MarkdownTableLayoutView: View {
  @Environment(\.tableBackgroundStyle) private var tableBackgroundStyle
  @Environment(\.tableBorderStyle) private var tableBorderStyle

  let columnAlignments: [RawTableColumnAlignment]
  let rows: [RawTableRow]

  var body: some View {
    MarkdownTableLayout(
      rowCount: self.rowCount,
      columnCount: self.columnCount,
      columnAlignments: self.columnAlignments,
      borderWidth: self.tableBorderStyle.strokeStyle.lineWidth,
      visibleBorders: self.tableBorderStyle.visibleBorders
    ) {
      ForEach(0..<self.rowCount, id: \.self) { row in
        ForEach(0..<self.columnCount, id: \.self) { column in
          Rectangle()
            .fill(self.tableBackgroundStyle.background(row, column))
        }
      }

      ForEach(0..<self.rowCount, id: \.self) { row in
        ForEach(0..<self.columnCount, id: \.self) { column in
          TableCell(row: row, column: column, cell: self.rows[row].cells[column])
        }
      }

      ForEach(0..<self.borderSubviewCount, id: \.self) { _ in
        Rectangle()
          .strokeBorder(self.tableBorderStyle.color, style: self.tableBorderStyle.strokeStyle)
      }
    }
  }

  private var rowCount: Int {
    self.rows.count
  }

  private var columnCount: Int {
    self.columnAlignments.count
  }

  private var borderSubviewCount: Int {
    max(1, self.rowCount + self.columnCount + 2)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct MarkdownTableLayout: Layout {
  let rowCount: Int
  let columnCount: Int
  let columnAlignments: [RawTableColumnAlignment]
  let borderWidth: CGFloat
  let visibleBorders: TableBorderSelector

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    self.computeLayout(proposal: proposal, subviews: subviews).tableBounds.bounds.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let layout = self.computeLayout(proposal: proposal, subviews: subviews)

    for cell in layout.backgrounds {
      subviews[cell.index].place(
        at: .init(x: bounds.minX + cell.bounds.minX, y: bounds.minY + cell.bounds.minY),
        anchor: .topLeading,
        proposal: .init(cell.bounds.size)
      )
    }

    for cell in layout.cells {
      subviews[cell.index].place(
        at: .init(x: bounds.minX + cell.bounds.minX, y: bounds.minY + cell.bounds.minY),
        anchor: .topLeading,
        proposal: .init(cell.bounds.size)
      )
    }

    for border in layout.borders {
      subviews[border.index].place(
        at: .init(x: bounds.minX + border.bounds.minX, y: bounds.minY + border.bounds.minY),
        anchor: .topLeading,
        proposal: .init(border.bounds.size)
      )
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension MarkdownTableLayout {
  private struct PlacedSubview {
    let index: Int
    let bounds: CGRect
  }

  private struct ComputedLayout {
    var backgrounds: [PlacedSubview] = []
    var cells: [PlacedSubview] = []
    var borders: [PlacedSubview] = []
    var tableBounds: TableBounds
  }

  private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> ComputedLayout {
    guard self.rowCount > 0, self.columnCount > 0 else {
      return .init(tableBounds: .init(bounds: .zero, rows: [], columns: []))
    }

    let cellStartIndex = self.rowCount * self.columnCount
    let cellSizes = self.cellSizes(subviews: subviews, cellStartIndex: cellStartIndex)
    let minimumCellSizes = self.cellSizes(
      proposal: .init(width: 0, height: nil),
      subviews: subviews,
      cellStartIndex: cellStartIndex
    )
    let columnWidths = self.columnWidths(
      proposal: proposal,
      cellSizes: cellSizes,
      minimumCellSizes: minimumCellSizes
    )
    let measuredCellSizes = self.cellSizes(
      columnWidths: columnWidths,
      subviews: subviews,
      cellStartIndex: cellStartIndex
    )
    let rowHeights = self.rowHeights(cellSizes: measuredCellSizes)
    let tableBounds = self.tableBounds(columnWidths: columnWidths, rowHeights: rowHeights)
    let borderRects = self.visibleBorders.rectangles(tableBounds, self.borderWidth)
    var layout = ComputedLayout(tableBounds: tableBounds)

    for row in 0..<self.rowCount {
      for column in 0..<self.columnCount {
        let bounds = tableBounds.bounds(forRow: row, column: column)
        let cellSize = measuredCellSizes[row][column]
        layout.backgrounds.append(
          .init(index: self.backgroundSubviewIndex(row: row, column: column), bounds: bounds)
        )
        layout.cells.append(
          .init(
            index: self.cellSubviewIndex(row: row, column: column, cellStartIndex: cellStartIndex),
            bounds: self.cellBounds(cellSize: cellSize, in: bounds, column: column)
          )
        )
      }
    }

    let borderStartIndex = cellStartIndex + self.rowCount * self.columnCount
    for index in 0..<self.borderSubviewCount(subviews: subviews, borderStartIndex: borderStartIndex)
    {
      layout.borders.append(
        .init(
          index: borderStartIndex + index,
          bounds: index < borderRects.count ? borderRects[index] : .zero
        )
      )
    }

    return layout
  }

  private func cellSizes(
    subviews: Subviews,
    cellStartIndex: Int
  ) -> [[CGSize]] {
    self.cellSizes(proposal: .unspecified, subviews: subviews, cellStartIndex: cellStartIndex)
  }

  private func cellSizes(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cellStartIndex: Int
  ) -> [[CGSize]] {
    (0..<self.rowCount).map { row in
      (0..<self.columnCount).map { column in
        subviews[self.cellSubviewIndex(row: row, column: column, cellStartIndex: cellStartIndex)]
          .sizeThatFits(proposal)
      }
    }
  }

  private func cellSizes(
    columnWidths: [CGFloat],
    subviews: Subviews,
    cellStartIndex: Int
  ) -> [[CGSize]] {
    (0..<self.rowCount).map { row in
      (0..<self.columnCount).map { column in
        subviews[self.cellSubviewIndex(row: row, column: column, cellStartIndex: cellStartIndex)]
          .sizeThatFits(.init(width: columnWidths[column], height: nil))
      }
    }
  }

  private func columnWidths(
    proposal: ProposedViewSize,
    cellSizes: [[CGSize]],
    minimumCellSizes: [[CGSize]]
  ) -> [CGFloat] {
    var widths = Array(repeating: CGFloat(0), count: self.columnCount)
    var minimumWidths = Array(repeating: CGFloat(0), count: self.columnCount)
    var widthCandidates = Array(repeating: [CGFloat](), count: self.columnCount)

    for column in 0..<self.columnCount {
      let naturalWidths = cellSizes.map { $0[column].width }
      widths[column] = naturalWidths.max() ?? 0
      minimumWidths[column] = minimumCellSizes.map { $0[column].width }.max() ?? 0
      widthCandidates[column] = self.widthCandidates(
        naturalWidths: naturalWidths,
        minimumWidth: minimumWidths[column]
      )
    }

    guard let proposedWidth = proposal.width else {
      return widths
    }

    let availableWidth =
      proposedWidth - 2 * self.borderWidth - CGFloat(max(0, self.columnCount - 1))
      * self.borderWidth
    guard widths.reduce(0, +) > availableWidth, availableWidth > 0 else {
      return widths
    }

    var candidateIndices = Array(repeating: 0, count: self.columnCount)
    while widths.reduce(0, +) > availableWidth {
      let shrinkableColumn =
        widths.indices
        .compactMap { column -> (column: Int, shrink: CGFloat)? in
          let nextIndex = candidateIndices[column] + 1
          guard widthCandidates[column].indices.contains(nextIndex) else {
            return nil
          }
          return (column, widths[column] - widthCandidates[column][nextIndex])
        }
        .max { $0.shrink < $1.shrink }?
        .column

      guard let shrinkableColumn else {
        break
      }

      candidateIndices[shrinkableColumn] += 1
      widths[shrinkableColumn] =
        widthCandidates[shrinkableColumn][
          candidateIndices[shrinkableColumn]
        ]
    }

    var remainingOverflow = widths.reduce(0, +) - availableWidth
    for column in widths.indices.reversed() where remainingOverflow > 0 {
      let shrink = min(remainingOverflow, max(0, widths[column] - minimumWidths[column]))
      widths[column] -= shrink
      remainingOverflow -= shrink
    }

    return widths
  }

  private func widthCandidates(naturalWidths: [CGFloat], minimumWidth: CGFloat) -> [CGFloat] {
    let candidates =
      (naturalWidths + [minimumWidth])
      .map { max($0, minimumWidth) }
      .sorted(by: >)
      .reduce(into: [CGFloat]()) { result, width in
        if result.last.map({ abs($0 - width) > 0.5 }) ?? true {
          result.append(width)
        }
      }

    return candidates.isEmpty ? [minimumWidth] : candidates
  }

  private func rowHeights(cellSizes: [[CGSize]]) -> [CGFloat] {
    cellSizes.map { row in
      row.map(\.height).max() ?? 0
    }
  }

  private func tableBounds(columnWidths: [CGFloat], rowHeights: [CGFloat]) -> TableBounds {
    var minX = self.borderWidth
    let columns = columnWidths.map { width -> (minX: CGFloat, width: CGFloat) in
      defer { minX += width + self.borderWidth }
      return (minX: minX, width: width)
    }

    var minY = self.borderWidth
    let rows = rowHeights.map { height -> (minY: CGFloat, height: CGFloat) in
      defer { minY += height + self.borderWidth }
      return (minY: minY, height: height)
    }

    return .init(
      bounds: .init(
        origin: .zero,
        size: .init(
          width: columns.last.map { $0.minX + $0.width + self.borderWidth } ?? 0,
          height: rows.last.map { $0.minY + $0.height + self.borderWidth } ?? 0
        )
      ),
      rows: rows,
      columns: columns
    )
  }

  private func cellBounds(cellSize: CGSize, in bounds: CGRect, column: Int) -> CGRect {
    .init(
      origin: .init(
        x: self.xPosition(forCellWidth: cellSize.width, in: bounds, column: column),
        y: bounds.minY + (bounds.height - cellSize.height) / 2
      ),
      size: cellSize
    )
  }

  private func xPosition(forCellWidth cellWidth: CGFloat, in bounds: CGRect, column: Int) -> CGFloat
  {
    switch self.columnAlignments[column] {
    case .none, .left:
      return bounds.minX
    case .center:
      return bounds.minX + (bounds.width - cellWidth) / 2
    case .right:
      return bounds.maxX - cellWidth
    }
  }

  private func backgroundSubviewIndex(row: Int, column: Int) -> Int {
    row * self.columnCount + column
  }

  private func cellSubviewIndex(row: Int, column: Int, cellStartIndex: Int) -> Int {
    cellStartIndex + row * self.columnCount + column
  }

  private func borderSubviewCount(subviews: Subviews, borderStartIndex: Int) -> Int {
    max(0, subviews.count - borderStartIndex)
  }
}
