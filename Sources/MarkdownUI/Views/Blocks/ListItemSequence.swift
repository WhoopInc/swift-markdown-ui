import SwiftUI

struct ListItemSequence: View {
  @Environment(\.theme.listItem) private var listItem
  @Environment(\.listLevel) private var listLevel
  @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled

  private let items: [RawListItem]
  private let start: Int
  private let markerStyle: BlockStyle<ListMarkerConfiguration>
  private let markerWidth: CGFloat?
  private let alignsMarkers: Bool
  private let multilineMarkerVerticalOffset: CGFloat

  init(
    items: [RawListItem],
    start: Int = 1,
    markerStyle: BlockStyle<ListMarkerConfiguration>,
    markerWidth: CGFloat? = nil,
    alignsMarkers: Bool = true,
    multilineMarkerVerticalOffset: CGFloat = 0
  ) {
    self.items = items
    self.start = start
    self.markerStyle = markerStyle
    self.markerWidth = markerWidth
    self.alignsMarkers = alignsMarkers
    self.multilineMarkerVerticalOffset = multilineMarkerVerticalOffset
  }

  var body: some View {
    if self.alignsMarkers,
      #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
    {
      TextStyleAttributesReader { attributes in
        let looseListItemSpacing =
          attributes.fontProperties?.scaledSize ?? FontProperties.defaultSize

        MarkdownListItemSequenceLayout(
          tightSpacingEnabled: self.tightSpacingEnabled,
          looseListItemSpacing: looseListItemSpacing
        ) {
          ForEach(self.items.indexed(), id: \.self) { item in
            self.listItem.makeBody(
              configuration: .init(
                label: .init(
                  MarkdownListItemLayout {
                    let marker = self.markerStyle
                      .makeBody(
                        configuration: .init(
                          listLevel: self.listLevel,
                          itemNumber: self.start + item.index
                        )
                      )
                      .textStyleFont()
                    if item.value.children.count == 1 {
                      marker.layoutValue(
                        key: ListMarkerMultilineVerticalOffsetLayoutValueKey.self,
                        value: self.multilineMarkerVerticalOffset
                      )
                    } else {
                      marker
                    }
                    BlockSequence(item.value.children)
                  }
                ),
                content: .init(blocks: item.value.children)
              )
            )
          }
        }
      }
      .labelStyle(.titleAndIcon)
    } else {
      self.legacyBody
    }
  }

  private var legacyBody: some View {
    BlockSequence(self.items) { index, item in
      ListItemView(
        item: item,
        number: self.start + index,
        markerStyle: self.markerStyle,
        markerWidth: self.markerWidth
      )
    }
    .labelStyle(.titleAndIcon)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct MarkdownListItemSequenceLayout: Layout {
  let tightSpacingEnabled: Bool
  let looseListItemSpacing: CGFloat

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    self.computeLayout(proposal: proposal, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let layout = self.computeLayout(proposal: proposal, subviews: subviews)
    var y = bounds.minY

    for item in layout.items {
      y += item.spacingBefore
      subviews[item.index].place(
        at: .init(x: bounds.minX + layout.markerTrailing - item.markerTrailing, y: y),
        anchor: .topLeading,
        proposal: .init(item.size)
      )
      y += item.size.height
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension MarkdownListItemSequenceLayout {
  private struct Item {
    let index: Int
    let size: CGSize
    let markerTrailing: CGFloat
    let spacingBefore: CGFloat
  }

  private struct ComputedLayout {
    var items: [Item] = []
    var markerTrailing: CGFloat = 0
    var size: CGSize = .zero
  }

  private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> ComputedLayout {
    let markerTrailing =
      subviews
      .map { subview in
        subview.dimensions(in: .init(width: proposal.width, height: nil))[
          .markdownListMarkerTrailing
        ]
      }
      .max() ?? 0

    var layout = ComputedLayout(markerTrailing: markerTrailing)

    for index in subviews.indices {
      let unconstrainedDimensions = subviews[index].dimensions(
        in: .init(width: proposal.width, height: nil)
      )
      let itemMarkerTrailing = unconstrainedDimensions[.markdownListMarkerTrailing]
      let leadingOffset = markerTrailing - itemMarkerTrailing
      let proposedWidth = proposal.width.map { max(0, $0 - leadingOffset) }
      let size = subviews[index].sizeThatFits(.init(width: proposedWidth, height: nil))
      let spacing = self.spacingBeforeSubview(at: index, subviews: subviews)
      let trailingWidth = size.width - itemMarkerTrailing

      layout.items.append(
        .init(
          index: index,
          size: size,
          markerTrailing: itemMarkerTrailing,
          spacingBefore: spacing
        )
      )
      layout.size.width = max(layout.size.width, markerTrailing + trailingWidth)
      layout.size.height += spacing + size.height
    }

    return layout
  }

  private func spacingBeforeSubview(at index: Int, subviews: Subviews) -> CGFloat {
    guard index > subviews.startIndex else {
      return 0
    }

    let topSpacing = subviews[index][BlockMarginLayoutValueKey.self].top
    let predecessorIndex = subviews.index(before: index)
    let predecessorBottomSpacing =
      self.tightSpacingEnabled
      ? 0 : subviews[predecessorIndex][BlockMarginLayoutValueKey.self].bottom

    if let spacing = [topSpacing, predecessorBottomSpacing].compactMap({ $0 }).max() {
      return spacing
    }

    if !self.tightSpacingEnabled {
      return self.looseListItemSpacing
    }

    return subviews[predecessorIndex].spacing.distance(
      to: subviews[index].spacing, along: .vertical)
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct MarkdownListItemLayout: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    self.computeLayout(proposal: proposal, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let layout = self.computeLayout(proposal: proposal, subviews: subviews)

    for item in layout.items {
      subviews[item.index].place(
        at: .init(x: bounds.minX + item.origin.x, y: bounds.minY + item.origin.y),
        anchor: .topLeading,
        proposal: .init(item.size)
      )
    }
  }

  func explicitAlignment(
    of guide: HorizontalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    guard guide == .markdownListMarkerTrailing else {
      return nil
    }

    return self.computeLayout(proposal: proposal, subviews: subviews).markerTrailing
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension MarkdownListItemLayout {
  private struct Item {
    let index: Int
    let origin: CGPoint
    let size: CGSize
  }

  private struct ComputedLayout {
    var items: [Item] = []
    var markerTrailing: CGFloat = 0
    var size: CGSize = .zero
  }

  private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> ComputedLayout {
    guard subviews.count >= 2 else {
      return self.singleSubviewLayout(proposal: proposal, subviews: subviews)
    }

    let marker = subviews[subviews.startIndex]
    let contentIndex = subviews.index(after: subviews.startIndex)
    let content = subviews[contentIndex]
    let markerDimensions = marker.dimensions(in: .unspecified)
    let spacing = marker.spacing.distance(to: content.spacing, along: .horizontal)
    let contentWidth = proposal.width.map { max(0, $0 - markerDimensions.width - spacing) }
    let contentDimensions = content.dimensions(in: .init(width: contentWidth, height: nil))
    let markerAlignment = markerDimensions[.centerOfFirstLine]
    let markerAlignmentOffset = marker[ListMarkerAlignmentOffsetLayoutValueKey.self]
    let contentAlignment = contentDimensions[.centerOfFirstLine]
    let alignment = max(markerAlignment + markerAlignmentOffset, contentAlignment)
    let contentWraps = contentDimensions.height > markerDimensions.height * 1.5
    let markerVerticalOffset =
      marker[ListMarkerVerticalOffsetLayoutValueKey.self]
      + (contentWraps ? marker[ListMarkerMultilineVerticalOffsetLayoutValueKey.self] : 0)
    let height = max(
      markerDimensions.height + alignment - markerAlignment,
      contentDimensions.height + alignment - contentAlignment
    )

    return .init(
      items: [
        .init(
          index: subviews.startIndex,
          origin: .init(x: 0, y: alignment - markerAlignment + markerVerticalOffset),
          size: .init(width: markerDimensions.width, height: markerDimensions.height)
        ),
        .init(
          index: contentIndex,
          origin: .init(x: markerDimensions.width + spacing, y: alignment - contentAlignment),
          size: .init(width: contentDimensions.width, height: contentDimensions.height)
        ),
      ],
      markerTrailing: markerDimensions.width,
      size: .init(
        width: markerDimensions.width + spacing + contentDimensions.width,
        height: height
      )
    )
  }

  private func singleSubviewLayout(proposal: ProposedViewSize, subviews: Subviews) -> ComputedLayout
  {
    guard let subview = subviews.first else {
      return .init()
    }

    let size = subview.sizeThatFits(proposal)
    return .init(
      items: [.init(index: subviews.startIndex, origin: .zero, size: size)],
      size: size
    )
  }
}

extension HorizontalAlignment {
  private enum MarkdownListMarkerTrailing: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
      context[.leading]
    }
  }

  fileprivate static let markdownListMarkerTrailing = Self(MarkdownListMarkerTrailing.self)
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
enum ListMarkerVerticalOffsetLayoutValueKey: LayoutValueKey {
  static let defaultValue: CGFloat = 0
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
enum ListMarkerAlignmentOffsetLayoutValueKey: LayoutValueKey {
  static let defaultValue: CGFloat = 0
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
enum ListMarkerMultilineVerticalOffsetLayoutValueKey: LayoutValueKey {
  static let defaultValue: CGFloat = 0
}
