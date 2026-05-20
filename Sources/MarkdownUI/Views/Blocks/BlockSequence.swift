import SwiftUI

struct BlockSequence<Data, Content>: View
where
  Data: Sequence,
  Data.Element: Hashable,
  Content: View
{
  @Environment(\.multilineTextAlignment) private var textAlignment
  @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled

  @State private var blockMargins: [Int: BlockMargin] = [:]

  private let data: [Indexed<Data.Element>]
  private let content: (Int, Data.Element) -> Content

  init(
    _ data: Data,
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.data = data.indexed()
    self.content = content
  }

  var body: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      MarkdownBlockSequenceLayout(
        alignment: .init(self.textAlignment),
        tightSpacingEnabled: self.tightSpacingEnabled
      ) {
        ForEach(self.data, id: \.self) { element in
          self.content(element.index, element.value)
        }
      }
    } else {
      self.legacyBody
    }
  }

  private var legacyBody: some View {
    VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
      ForEach(self.data, id: \.self) { element in
        self.content(element.index, element.value)
          .onPreferenceChange(BlockMarginsPreference.self) { value in
            self.blockMargins[element.hashValue] = value
          }
          .padding(.top, self.topPaddingLength(for: element))
      }
    }
  }

  private func topPaddingLength(for element: Indexed<Data.Element>) -> CGFloat? {
    guard element.index > 0 else {
      return 0
    }

    let topSpacing = self.blockMargins[element.hashValue]?.top
    let predecessor = self.data[element.index - 1]
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : self.blockMargins[predecessor.hashValue]?.bottom

    return [topSpacing, predecessorBottomSpacing]
      .compactMap { $0 }
      .max()
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct MarkdownBlockSequenceLayout: Layout {
  let alignment: HorizontalLayoutAlignment
  let tightSpacingEnabled: Bool

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    self.computeLayout(proposal: proposal, subviews: subviews).size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let layout = self.computeLayout(proposal: proposal, subviews: subviews)
    let childProposal = ProposedViewSize(width: proposal.width, height: nil)
    var y = bounds.minY

    for item in layout.items {
      y += item.spacingBefore

      subviews[item.index].place(
        at: CGPoint(
          x: self.alignment.xPosition(in: bounds, subviewWidth: item.size.width),
          y: y
        ),
        anchor: .topLeading,
        proposal: childProposal
      )
      y += item.size.height
    }
  }

  func explicitAlignment(
    of guide: VerticalAlignment,
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    let layout = self.computeLayout(proposal: proposal, subviews: subviews)

    switch guide {
    case .firstTextBaseline, .centerOfFirstLine:
      guard let item = layout.items.first else {
        return nil
      }
      return item.spacingBefore
        + subviews[item.index].dimensions(in: .init(item.size))[guide]
    case .lastTextBaseline:
      guard let item = layout.items.last else {
        return nil
      }
      return item.originY
        + subviews[item.index].dimensions(in: .init(item.size))[guide]
    default:
      return nil
    }
  }

}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
extension MarkdownBlockSequenceLayout {
  private struct Item {
    let index: Int
    let size: CGSize
    let spacingBefore: CGFloat
    let originY: CGFloat
  }

  private struct ComputedLayout {
    var items: [Item] = []
    var size: CGSize = .zero
  }

  private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> ComputedLayout {
    var layout = ComputedLayout()
    let childProposal = ProposedViewSize(width: proposal.width, height: nil)

    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(childProposal)
      let spacing = self.spacingBeforeSubview(at: index, subviews: subviews)
      let originY = layout.size.height + spacing

      layout.items.append(.init(index: index, size: size, spacingBefore: spacing, originY: originY))
      layout.size.width = max(layout.size.width, size.width)
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

    let systemSpacing = subviews[predecessorIndex].spacing.distance(
      to: subviews[index].spacing, along: .vertical)

    if systemSpacing > 0 {
      return systemSpacing
    }

    return 16
  }
}

private enum HorizontalLayoutAlignment {
  case leading
  case center
  case trailing

  init(_ textAlignment: TextAlignment) {
    switch textAlignment {
    case .leading:
      self = .leading
    case .center:
      self = .center
    case .trailing:
      self = .trailing
    }
  }

  func xPosition(in bounds: CGRect, subviewWidth: CGFloat) -> CGFloat {
    switch self {
    case .leading:
      return bounds.minX
    case .center:
      return bounds.minX + (bounds.width - subviewWidth) / 2
    case .trailing:
      return bounds.maxX - subviewWidth
    }
  }
}

extension BlockSequence where Data == [BlockNode], Content == BlockNode {
  init(_ blocks: [BlockNode]) {
    self.init(blocks) { $1 }
  }
}

extension TextAlignment {
  fileprivate var alignment: Alignment {
    switch self {
    case .leading:
      return .leading
    case .center:
      return .center
    case .trailing:
      return .trailing
    }
  }
}
