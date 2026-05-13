import SwiftUI

struct ResizeToFit<Content>: View where Content: View {
  private let idealSize: CGSize
  private let content: Content

  init(idealSize: CGSize, @ViewBuilder content: () -> Content) {
    self.idealSize = idealSize
    self.content = content()
  }

  var body: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      ResizeToFit2 { self.content }
    } else {
      ResizeToFit1(idealSize: self.idealSize, content: self.content)
    }
  }
}

// MARK: - Aspect ratio based

private struct ResizeToFit1<Content>: View where Content: View {
  let idealSize: CGSize
  let content: Content

  var body: some View {
    self.content
      .aspectRatio(self.idealSize, contentMode: .fit)
      .frame(maxWidth: self.idealSize.width, maxHeight: self.idealSize.height)
  }
}

// MARK: - Layout based

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
private struct ResizeToFit2: Layout {
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let view = subviews.first else {
      return .zero
    }

    var size = view.sizeThatFits(.unspecified)

    if let width = proposal.width, size.width > width {
      let aspectRatio = size.width / size.height
      size.width = width
      size.height = width / aspectRatio
    }
    return size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    guard let view = subviews.first else { return }
    view.place(at: bounds.origin, proposal: .init(bounds.size))
  }
}
