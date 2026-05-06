import SwiftUI

struct NumberedListView: View {
  @Environment(\.theme.list) private var list
  @Environment(\.theme.numberedListMarker) private var numberedListMarker
  @Environment(\.listLevel) private var listLevel

  @State private var markerWidth: CGFloat?

  private let isTight: Bool
  private let start: Int
  private let items: [RawListItem]

  init(isTight: Bool, start: Int, items: [RawListItem]) {
    self.isTight = isTight
    self.start = start
    self.items = items
  }

  var body: some View {
    self.list.makeBody(
      configuration: .init(
        label: .init(self.label),
        content: .init(
          block: .numberedList(
            isTight: self.isTight,
            start: self.start,
            items: self.items
          )
        )
      )
    )
  }

  @ViewBuilder private var label: some View {
    let sequence = ListItemSequence(
      items: self.items,
      start: self.start,
      markerStyle: self.numberedListMarker,
      markerWidth: self.markerWidth
    )
    .environment(\.listLevel, self.listLevel + 1)
    .environment(\.tightSpacingEnabled, self.isTight)

    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      sequence
    } else {
      sequence.onColumnWidthChange { columnWidths in
        self.markerWidth = columnWidths[0]
      }
    }
  }
}
