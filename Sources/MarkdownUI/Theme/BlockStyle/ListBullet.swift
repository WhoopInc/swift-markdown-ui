import SwiftUI

struct ListBullet: View {
  private let image: Image
  private let verticalOffset: CGFloat

  var body: some View {
    TextStyleAttributesReader { attributes in
      let fontSize = attributes.fontProperties?.scaledSize ?? FontProperties.defaultSize
      let bullet = self.image.font(.system(size: round(fontSize / 3)))

      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        bullet.layoutValue(
          key: ListMarkerVerticalOffsetLayoutValueKey.self,
          value: self.verticalOffset
        )
      } else {
        bullet
      }
    }
  }

  static var disc: Self {
    .init(image: .init(systemName: "circle.fill"), verticalOffset: -1)
  }

  static var circle: Self {
    .init(image: .init(systemName: "circle"), verticalOffset: -1)
  }

  static var square: Self {
    .init(image: .init(systemName: "square.fill"), verticalOffset: -0.5)
  }
}
