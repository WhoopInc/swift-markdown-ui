import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableView: View {
  @Environment(\.theme.table) private var table
  @Environment(\.tableBorderStyle.strokeStyle.lineWidth) private var layoutBorderWidth

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
      layoutBorderWidth: self.layoutBorderWidth,
      rows: self.rows
    )
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct MarkdownTableLayoutView: View {
  @Environment(\.tableBackgroundStyle) private var tableBackgroundStyle
  @Environment(\.tableBorderStyle) private var tableBorderStyle
  @Environment(\.tableLayoutWidthBehavior) private var tableLayoutWidthBehavior
  @Environment(\.displayScale) private var displayScale

  let columnAlignments: [RawTableColumnAlignment]
  let layoutBorderWidth: CGFloat
  let rows: [RawTableRow]

  var body: some View {
    MarkdownTableLayout(
      rowCount: self.rowCount,
      columnCount: self.columnCount,
      columnAlignments: self.columnAlignments,
      widthBehavior: self.tableLayoutWidthBehavior,
      layoutBorderWidth: self.layoutBorderWidth,
      decorationBorderWidth: self.tableBorderStyle.strokeStyle.lineWidth,
      displayScale: self.displayScale,
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
  let widthBehavior: TableLayoutWidthBehavior
  let layoutBorderWidth: CGFloat
  let decorationBorderWidth: CGFloat
  let displayScale: CGFloat
  let visibleBorders: TableBorderSelector

  fileprivate func makeCache(subviews: Subviews) -> Cache {
    .init(structure: self.structure(subviews: subviews))
  }

  fileprivate func updateCache(_ cache: inout Cache, subviews: Subviews) {
    cache.generation &+= 1
    cache.structure = self.structure(subviews: subviews)
    cache.pendingLayout = nil
  }

  fileprivate func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout Cache
  ) -> CGSize {
    self.updateCacheStructureIfNeeded(&cache, subviews: subviews)
    cache.pendingLayout = nil

    let layout = self.computeLayout(
      proposal: proposal,
      subviews: subviews,
      structure: cache.structure
    )
    cache.pendingLayout = .init(
      key: self.pendingLayoutKey(
        generation: cache.generation,
        proposal: proposal,
        resolvedTableWidth: layout.tableBounds.bounds.width,
        structure: cache.structure
      ),
      layout: layout
    )

    return layout.tableBounds.bounds.size
  }

  fileprivate func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
  ) {
    self.updateCacheStructureIfNeeded(&cache, subviews: subviews)

    let key = self.pendingLayoutKey(
      generation: cache.generation,
      proposal: proposal,
      resolvedTableWidth: bounds.width,
      structure: cache.structure
    )
    let pendingLayout = cache.pendingLayout
    cache.pendingLayout = nil

    let layout =
      pendingLayout.flatMap { self.reusableLayout($0, matching: key) }
      ?? self.computeLayout(
        proposal: proposal,
        subviews: subviews,
        structure: cache.structure,
        fixedTableWidth: bounds.width
      )

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
  fileprivate struct Cache {
    var generation = 0
    var structure: Structure
    var pendingLayout: PendingLayout?
  }

  fileprivate struct Structure: Equatable {
    let rowCount: Int
    let columnCount: Int
    let subviewCount: Int
    let cellStartIndex: Int
    let borderStartIndex: Int
    let borderSubviewCount: Int
  }

  fileprivate struct LayoutInputs: Equatable {
    let columnAlignments: [RawTableColumnAlignment]
    let widthBehavior: TableLayoutWidthBehavior
    let layoutBorderWidth: CGFloat
    let decorationBorderWidth: CGFloat
    let displayScale: CGFloat
  }

  fileprivate struct PendingLayoutKey: Equatable {
    let generation: Int
    let proposalWidth: CGFloat?
    let resolvedTableWidth: CGFloat
    let structure: Structure
    let inputs: LayoutInputs
  }

  fileprivate struct PendingLayout {
    let key: PendingLayoutKey
    let layout: ComputedLayout
  }

  fileprivate struct PlacedSubview {
    let index: Int
    let bounds: CGRect
  }

  fileprivate struct ComputedLayout {
    var backgrounds: [PlacedSubview] = []
    var cells: [PlacedSubview] = []
    var borders: [PlacedSubview] = []
    var tableBounds: TableBounds
    var borderRects: [CGRect] = []
  }

  private func computeLayout(
    proposal: ProposedViewSize,
    subviews: Subviews,
    structure: Structure,
    fixedTableWidth: CGFloat? = nil
  ) -> ComputedLayout {
    guard self.rowCount > 0, self.columnCount > 0 else {
      return .init(tableBounds: .init(bounds: .zero, rows: [], columns: []))
    }

    let cellSizes = self.cellSizes(subviews: subviews, cellStartIndex: structure.cellStartIndex)
    let minimumCellSizes = self.cellSizes(
      proposal: .init(width: 0, height: nil),
      subviews: subviews,
      cellStartIndex: structure.cellStartIndex
    )
    let columnWidths = self.columnWidths(
      proposal: proposal,
      cellSizes: cellSizes,
      minimumCellSizes: minimumCellSizes,
      fixedTableWidth: fixedTableWidth
    )
    let measuredCellSizes = self.cellSizes(
      columnWidths: columnWidths,
      subviews: subviews,
      cellStartIndex: structure.cellStartIndex
    )
    let rowHeights = self.rowHeights(cellSizes: measuredCellSizes)
    let tableBounds = self.tableBounds(
      columnWidths: columnWidths,
      rowHeights: rowHeights,
      snapsWidthToDisplayScale: fixedTableWidth == nil
    )
    let borderRects = self.visibleBorders.rectangles(tableBounds, self.decorationBorderWidth)
    var layout = ComputedLayout(tableBounds: tableBounds, borderRects: borderRects)

    for row in 0..<self.rowCount {
      for column in 0..<self.columnCount {
        let bounds = tableBounds.bounds(forRow: row, column: column)
        let cellSize = measuredCellSizes[row][column]
        layout.backgrounds.append(
          .init(index: self.backgroundSubviewIndex(row: row, column: column), bounds: bounds)
        )
        layout.cells.append(
          .init(
            index: self.cellSubviewIndex(
              row: row,
              column: column,
              cellStartIndex: structure.cellStartIndex
            ),
            bounds: self.cellBounds(cellSize: cellSize, in: bounds, column: column)
          )
        )
      }
    }

    for index in 0..<structure.borderSubviewCount {
      layout.borders.append(
        .init(
          index: structure.borderStartIndex + index,
          bounds: index < borderRects.count ? borderRects[index] : .zero
        )
      )
    }

    return layout
  }

  fileprivate func structure(subviews: Subviews) -> Structure {
    let cellStartIndex = self.rowCount * self.columnCount
    let borderStartIndex = cellStartIndex + self.rowCount * self.columnCount

    return .init(
      rowCount: self.rowCount,
      columnCount: self.columnCount,
      subviewCount: subviews.count,
      cellStartIndex: cellStartIndex,
      borderStartIndex: borderStartIndex,
      borderSubviewCount: max(0, subviews.count - borderStartIndex)
    )
  }

  fileprivate func updateCacheStructureIfNeeded(_ cache: inout Cache, subviews: Subviews) {
    let structure = self.structure(subviews: subviews)
    guard cache.structure != structure else {
      return
    }

    cache.generation &+= 1
    cache.structure = structure
    cache.pendingLayout = nil
  }

  fileprivate func pendingLayoutKey(
    generation: Int,
    proposal: ProposedViewSize,
    resolvedTableWidth: CGFloat,
    structure: Structure
  ) -> PendingLayoutKey {
    .init(
      generation: generation,
      proposalWidth: proposal.width,
      resolvedTableWidth: resolvedTableWidth,
      structure: structure,
      inputs: .init(
        columnAlignments: self.columnAlignments,
        widthBehavior: self.widthBehavior,
        layoutBorderWidth: self.layoutBorderWidth,
        decorationBorderWidth: self.decorationBorderWidth,
        displayScale: self.displayScale
      )
    )
  }

  fileprivate func reusableLayout(
    _ pendingLayout: PendingLayout,
    matching key: PendingLayoutKey
  ) -> ComputedLayout? {
    guard pendingLayout.key == key else {
      return nil
    }

    let currentBorderRects = self.visibleBorders.rectangles(
      pendingLayout.layout.tableBounds,
      self.decorationBorderWidth
    )
    guard pendingLayout.layout.borderRects == currentBorderRects else {
      return nil
    }

    return pendingLayout.layout
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
    minimumCellSizes: [[CGSize]],
    fixedTableWidth: CGFloat?
  ) -> [CGFloat] {
    let naturalWidths = self.naturalColumnWidths(cellSizes: cellSizes)
    let readableWidths = self.readableColumnWidths(cellSizes: cellSizes)
    let minimumWidths = self.naturalColumnWidths(cellSizes: minimumCellSizes)
    let preferredWidths: [CGFloat]

    switch self.widthBehavior {
    case .compact:
      preferredWidths = readableWidths
    case .fillAvailable, .balancedFillAvailable:
      preferredWidths = naturalWidths
    }

    let proposedWidth = fixedTableWidth ?? proposal.width
    guard let proposedWidth else {
      return preferredWidths
    }

    let availableWidth =
      proposedWidth - 2 * self.layoutBorderWidth - CGFloat(max(0, self.columnCount - 1))
      * self.layoutBorderWidth
    guard availableWidth > 0 else {
      return preferredWidths
    }

    switch self.widthBehavior {
    case .compact:
      let compactWidth =
        fixedTableWidth == nil && availableWidth >= 300
        ? min(availableWidth, max(readableWidths.reduce(0, +), availableWidth * 0.72))
        : availableWidth
      return self.balancedColumnWidths(
        readableWidths: readableWidths,
        naturalWidths: naturalWidths,
        minimumWidths: minimumWidths,
        availableWidth: compactWidth
      )
    case .fillAvailable:
      if self.columnCount > 2 {
        if readableWidths.reduce(0, +) <= availableWidth {
          return readableWidths
        }

        return self.balancedColumnWidths(
          readableWidths: readableWidths,
          naturalWidths: naturalWidths,
          minimumWidths: minimumWidths,
          availableWidth: availableWidth
        )
      }

      if self.hasDominantColumn(naturalWidths, availableWidth: availableWidth) {
        return self.balancedColumnWidths(
          readableWidths: readableWidths,
          naturalWidths: naturalWidths,
          minimumWidths: minimumWidths,
          availableWidth: availableWidth
        )
      }

      return self.candidateColumnWidths(
        cellSizes: cellSizes,
        naturalWidths: naturalWidths,
        minimumWidths: minimumWidths,
        availableWidth: availableWidth
      )
    case .balancedFillAvailable(let maxWidthFraction, let widthAdjustment):
      let balancedWidth =
        fixedTableWidth == nil
        ? availableWidth * maxWidthFraction + widthAdjustment
        : availableWidth
      return self.balancedColumnWidths(
        readableWidths: readableWidths,
        naturalWidths: naturalWidths,
        minimumWidths: minimumWidths,
        availableWidth: balancedWidth
      )
    }
  }

  private func candidateColumnWidths(
    cellSizes: [[CGSize]],
    naturalWidths: [CGFloat],
    minimumWidths: [CGFloat],
    availableWidth: CGFloat
  ) -> [CGFloat] {
    var widths = naturalWidths
    var widthCandidates = Array(repeating: [CGFloat](), count: self.columnCount)

    for column in 0..<self.columnCount {
      widthCandidates[column] = self.widthCandidates(
        naturalWidths: cellSizes.map { $0[column].width },
        minimumWidth: minimumWidths[column]
      )
    }

    guard widths.reduce(0, +) > availableWidth else {
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
      widths[shrinkableColumn] = widthCandidates[shrinkableColumn][
        candidateIndices[shrinkableColumn]
      ]
    }

    return self.fittingColumnWidths(
      widths,
      minimumWidths: minimumWidths,
      availableWidth: availableWidth
    )
  }

  private func balancedColumnWidths(
    readableWidths: [CGFloat],
    naturalWidths: [CGFloat],
    minimumWidths: [CGFloat],
    availableWidth: CGFloat
  ) -> [CGFloat] {
    var widths = readableWidths
    let remainingWidth = availableWidth - widths.reduce(0, +)

    if remainingWidth > 0 {
      let demand = zip(naturalWidths, readableWidths).map { max(0, $0 - $1) }
      let totalDemand = demand.reduce(0, +)

      if totalDemand > 0 {
        let readableWidth = readableWidths.reduce(0, +)
        let balancesReadableColumns = readableWidth > 0 && demand.allSatisfy { $0 > 0 }

        for column in widths.indices {
          let demandShare = demand[column] / totalDemand
          let readableShare = readableWidth > 0 ? readableWidths[column] / readableWidth : 0
          let share =
            balancesReadableColumns
            ? demandShare * 0.84 + readableShare * 0.16
            : demandShare
          widths[column] += min(demand[column], remainingWidth * share)
        }
      }
    }

    return self.fittingColumnWidths(
      widths,
      minimumWidths: minimumWidths,
      availableWidth: availableWidth
    )
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

  private func hasDominantColumn(_ widths: [CGFloat], availableWidth: CGFloat) -> Bool {
    widths.contains { width in
      width > availableWidth * 1.2
    }
  }

  private func naturalColumnWidths(cellSizes: [[CGSize]]) -> [CGFloat] {
    (0..<self.columnCount).map { column in
      cellSizes.map { $0[column].width }.max() ?? 0
    }
  }

  private func readableColumnWidths(cellSizes: [[CGSize]]) -> [CGFloat] {
    guard let header = cellSizes.first else {
      return Array(repeating: 0, count: self.columnCount)
    }

    return (0..<self.columnCount).map { column in
      header[column].width
    }
  }

  private func fittingColumnWidths(
    _ widths: [CGFloat],
    minimumWidths: [CGFloat],
    availableWidth: CGFloat
  ) -> [CGFloat] {
    let totalWidth = widths.reduce(0, +)
    guard totalWidth > availableWidth else {
      return widths
    }

    let overflow = totalWidth - availableWidth
    let shrinkCapacity = zip(widths, minimumWidths).map { max(0, $0 - $1) }
    let totalShrinkCapacity = shrinkCapacity.reduce(0, +)

    guard totalShrinkCapacity > 0 else {
      return widths
    }

    return widths.indices.map { column in
      widths[column] - min(
        shrinkCapacity[column],
        overflow * shrinkCapacity[column] / totalShrinkCapacity
      )
    }
  }

  private func rowHeights(cellSizes: [[CGSize]]) -> [CGFloat] {
    cellSizes.map { row in
      row.map(\.height).max() ?? 0
    }
  }

  private func tableBounds(
    columnWidths: [CGFloat],
    rowHeights: [CGFloat],
    snapsWidthToDisplayScale: Bool
  ) -> TableBounds {
    var minX = self.layoutBorderWidth
    let columns = columnWidths.map { width -> (minX: CGFloat, width: CGFloat) in
      defer { minX += width + self.layoutBorderWidth }
      return (minX: minX, width: width)
    }

    var minY = self.layoutBorderWidth
    let rows = rowHeights.map { height -> (minY: CGFloat, height: CGFloat) in
      defer { minY += height + self.layoutBorderWidth }
      return (minY: minY, height: height)
    }

    let width = columns.last.map { $0.minX + $0.width + self.layoutBorderWidth } ?? 0
    let height = rows.last.map { $0.minY + $0.height + self.layoutBorderWidth } ?? 0

    return .init(
      bounds: .init(
        origin: .zero,
        size: .init(
          width: snapsWidthToDisplayScale ? self.snappedToDisplayScale(width) : width,
          height: height
        )
      ),
      rows: rows,
      columns: columns
    )
  }

  private func snappedToDisplayScale(_ value: CGFloat) -> CGFloat {
    guard self.displayScale > 0 else {
      return value
    }

    return (value * self.displayScale).rounded() / self.displayScale
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
}

enum TableLayoutWidthBehavior {
  case compact
  case fillAvailable
  case balancedFillAvailable(maxWidthFraction: CGFloat, widthAdjustment: CGFloat)
}

extension TableLayoutWidthBehavior: Equatable {}

extension View {
  func markdownTableLayoutWidthBehavior(_ behavior: TableLayoutWidthBehavior) -> some View {
    self.environment(\.tableLayoutWidthBehavior, behavior)
  }
}

extension EnvironmentValues {
  var tableLayoutWidthBehavior: TableLayoutWidthBehavior {
    get { self[TableLayoutWidthBehaviorKey.self] }
    set { self[TableLayoutWidthBehaviorKey.self] = newValue }
  }
}

private struct TableLayoutWidthBehaviorKey: EnvironmentKey {
  static let defaultValue = TableLayoutWidthBehavior.compact
}
