import SwiftUI

struct TableBounds {
  var rowCount: Int {
    self.rows.count
  }

  var columnCount: Int {
    self.columns.count
  }

  let bounds: CGRect

  private let rows: [(minY: CGFloat, height: CGFloat)]
  private let columns: [(minX: CGFloat, width: CGFloat)]

  init(
    bounds: CGRect,
    rows: [(minY: CGFloat, height: CGFloat)],
    columns: [(minX: CGFloat, width: CGFloat)]
  ) {
    self.bounds = bounds
    self.rows = rows
    self.columns = columns
  }

  func bounds(forRow row: Int, column: Int) -> CGRect {
    CGRect(
      origin: .init(x: self.columns[column].minX, y: self.rows[row].minY),
      size: .init(width: self.columns[column].width, height: self.rows[row].height)
    )
  }

  func bounds(forRow row: Int) -> CGRect {
    (0..<self.columnCount)
      .map { self.bounds(forRow: row, column: $0) }
      .reduce(.null, CGRectUnion)
  }

  func bounds(forColumn column: Int) -> CGRect {
    (0..<self.rowCount)
      .map { self.bounds(forRow: $0, column: column) }
      .reduce(.null, CGRectUnion)
  }
}
