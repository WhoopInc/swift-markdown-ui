import SwiftUI

struct ListBullet: View {
  private let image: Image
  let verticalOffset: CGFloat

  var body: some View {
    TextStyleAttributesReader { attributes in
      let fontSize = attributes.fontProperties?.scaledSize ?? FontProperties.defaultSize
      self.image.font(.system(size: round(fontSize / 3)))
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
