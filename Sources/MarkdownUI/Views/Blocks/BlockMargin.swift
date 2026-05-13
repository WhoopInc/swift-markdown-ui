import SwiftUI

struct BlockMargin: Equatable {
  var top: CGFloat?
  var bottom: CGFloat?

  static let unspecified = BlockMargin()
}

extension View {
  /// Sets the preferred top margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top spacing
  /// of the block content. Apply it to the outermost view returned by the block style.
  ///
  /// - Parameter top: The minimum relative top spacing to use when laying out this block
  ///                  together with other blocks.
  public func markdownMargin(top: RelativeSize) -> some View {
    self.markdownMargin(top: top, bottom: nil)
  }

  /// Sets the preferred bottom margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the bottom spacing
  /// of the block content. Apply it to the outermost view returned by the block style.
  ///
  /// - Parameter bottom: The minimum relative bottom spacing to use when laying out this
  ///                     block together with other blocks.
  public func markdownMargin(bottom: RelativeSize) -> some View {
    self.markdownMargin(top: nil, bottom: bottom)
  }

  /// Sets the preferred top and bottom margins for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top and
  /// bottom spacing of the block content. Apply it to the outermost view returned by the block style.
  ///
  /// - Parameters:
  ///   - top: The minimum relative top spacing to use when laying out this block together with
  ///          other blocks. If you set the value to `nil`, MarkdownUI uses the preferred
  ///          maximum value of the child blocks or the system's default padding amount
  ///          if no preference has been set.
  ///   - bottom: The minimum relative bottom spacing to use when laying out this block
  ///             together with other blocks. If you set the value to `nil`, MarkdownUI
  ///             uses the preferred maximum value of the child blocks or the system's
  ///             default padding amount if no preference has been set.
  public func markdownMargin(top: RelativeSize?, bottom: RelativeSize?) -> some View {
    self.modifier(RelativeBlockMarginModifier(top: top, bottom: bottom))
  }

  /// Sets the preferred top margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top spacing
  /// of the block content. Apply it to the outermost view returned by the block style.
  ///
  /// - Parameter top: The minimum top spacing, given in points, to use when laying out this block
  ///                  together with other blocks.
  public func markdownMargin(top: CGFloat) -> some View {
    self.markdownMargin(top: top, bottom: nil)
  }

  /// Sets the preferred bottom margin for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the bottom spacing
  /// of the block content. Apply it to the outermost view returned by the block style.
  ///
  /// - Parameter bottom: The minimum bottom spacing, given in points, to use when laying out this
  ///                     block together with other blocks.
  public func markdownMargin(bottom: CGFloat) -> some View {
    self.markdownMargin(top: nil, bottom: bottom)
  }

  /// Sets the preferred top and bottom margins for the block content in this view.
  ///
  /// Use this modifier inside a ``BlockStyle`` `body` closure to customize the top and
  /// bottom spacing of the block content. Apply it to the outermost view returned by the block style.
  ///
  /// - Parameters:
  ///   - top: The minimum top spacing, given in points, to use when laying out this block
  ///          together with other blocks. If you set the value to `nil`, MarkdownUI uses
  ///          the preferred maximum value of the child blocks or the system's default
  ///          padding amount if no preference has been set.
  ///   - bottom: The minimum bottom spacing, given in points, to use when laying out
  ///             this block together with other blocks. If you set the value to `nil`,
  ///             MarkdownUI uses the preferred maximum value of the child blocks or
  ///             the system's default padding amount if no preference has been set.
  public func markdownMargin(top: CGFloat?, bottom: CGFloat?) -> some View {
    self.modifier(BlockMarginModifier(margin: .init(top: top, bottom: bottom)))
  }
}

private struct RelativeBlockMarginModifier: ViewModifier {
  @Environment(\.textStyle) private var textStyle

  let top: RelativeSize?
  let bottom: RelativeSize?

  @ViewBuilder
  func body(content: Content) -> some View {
    let margin = BlockMargin(
      top: self.top?.points(relativeTo: self.fontProperties),
      bottom: self.bottom?.points(relativeTo: self.fontProperties)
    )

    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      content.layoutValue(key: BlockMarginLayoutValueKey.self, value: margin)
    } else {
      content.transformPreference(BlockMarginsPreference.self) { value in
        value.merge(margin)
      }
    }
  }

  private var fontProperties: FontProperties? {
    var attributes = AttributeContainer()
    self.textStyle._collectAttributes(in: &attributes)
    return attributes.fontProperties
  }
}

private struct BlockMarginModifier: ViewModifier {
  let margin: BlockMargin

  @ViewBuilder
  func body(content: Content) -> some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      content.layoutValue(key: BlockMarginLayoutValueKey.self, value: self.margin)
    } else {
      content.transformPreference(BlockMarginsPreference.self) { value in
        value.merge(self.margin)
      }
    }
  }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct BlockMarginLayoutValueKey: LayoutValueKey {
  static let defaultValue = BlockMargin.unspecified
}

struct BlockMarginsPreference: PreferenceKey {
  static let defaultValue: BlockMargin = .unspecified

  static func reduce(value: inout BlockMargin, nextValue: () -> BlockMargin) {
    value.merge(nextValue())
  }
}

extension BlockMargin {
  mutating func merge(_ margin: BlockMargin) {
    self.top = [self.top, margin.top].compactMap { $0 }.max()
    self.bottom = [self.bottom, margin.bottom].compactMap { $0 }.max()
  }
}
