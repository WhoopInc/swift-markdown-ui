import Foundation

extension InlineNode {
  func renderAttributedString(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) -> AttributedString {
    var renderer = AttributedStringInlineRenderer(
      baseURL: baseURL,
      textStyles: textStyles,
      softBreakMode: softBreakMode,
      attributes: attributes
    )
    renderer.render(self)
    return renderer.result.resolvingFonts()
  }
}

private struct AttributedStringInlineRenderer {
  var result = AttributedString()

  private let baseURL: URL?
  private let textStyles: InlineTextStyles
  private let softBreakMode: SoftBreak.Mode
  private var attributes: AttributeContainer
  private var opacity = 1.0
  private var shouldSkipNextWhitespace = false

  init(
    baseURL: URL?,
    textStyles: InlineTextStyles,
    softBreakMode: SoftBreak.Mode,
    attributes: AttributeContainer
  ) {
    self.baseURL = baseURL
    self.textStyles = textStyles
    self.softBreakMode = softBreakMode
    self.attributes = attributes
  }

  mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      self.renderText(content)
    case .opacity(let opacity, let children):
      self.renderOpacity(opacity, children: children)
    case .softBreak:
      self.renderSoftBreak()
    case .lineBreak:
      self.renderLineBreak()
    case .code(let content):
      self.renderCode(content)
    case .html(let content):
      self.renderHTML(content)
    case .emphasis(let children):
      self.renderEmphasis(children: children)
    case .strong(let children):
      self.renderStrong(children: children)
    case .strikethrough(let children):
      self.renderStrikethrough(children: children)
    case .link(let destination, let children):
      self.renderLink(destination: destination, children: children)
    case .image(let source, let children):
      self.renderImage(source: source, children: children)
    }
  }

  private mutating func renderText(_ text: String) {
    var text = text

    if self.shouldSkipNextWhitespace {
      self.shouldSkipNextWhitespace = false
      text = text.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    }

    self.result += .init(text, attributes: self.attributes.applyingOpacity(self.opacity))
  }

  private mutating func renderOpacity(_ opacity: Double, children: [InlineNode]) {
    let savedOpacity = self.opacity
    self.opacity *= opacity

    for child in children {
      self.render(child)
    }

    self.opacity = savedOpacity
  }

  private mutating func renderSoftBreak() {
    switch softBreakMode {
    case .space where self.shouldSkipNextWhitespace:
      self.shouldSkipNextWhitespace = false
    case .space:
      self.result += .init(" ", attributes: self.attributes.applyingOpacity(self.opacity))
    case .lineBreak:
      self.renderLineBreak()
    }
  }

  private mutating func renderLineBreak() {
    self.result += .init("\n", attributes: self.attributes.applyingOpacity(self.opacity))
  }

  private mutating func renderCode(_ code: String) {
    self.result += .init(
      code,
      attributes: self.textStyles.code.mergingAttributes(self.attributes).applyingOpacity(self.opacity)
    )
  }

  private mutating func renderHTML(_ html: String) {
    let tag = HTMLTag(html)

    switch tag?.name.lowercased() {
    case "br":
      self.renderLineBreak()
      self.shouldSkipNextWhitespace = true
    default:
      self.renderText(html)
    }
  }

  private mutating func renderEmphasis(children: [InlineNode]) {
    let savedAttributes = self.attributes
    self.attributes = self.textStyles.emphasis.mergingAttributes(self.attributes)

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
  }

  private mutating func renderStrong(children: [InlineNode]) {
    let savedAttributes = self.attributes
    self.attributes = self.textStyles.strong.mergingAttributes(self.attributes)

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
  }

  private mutating func renderStrikethrough(children: [InlineNode]) {
    let savedAttributes = self.attributes
    self.attributes = self.textStyles.strikethrough.mergingAttributes(self.attributes)

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
  }

  private mutating func renderLink(destination: String, children: [InlineNode]) {
    let savedAttributes = self.attributes
    self.attributes = self.textStyles.link.mergingAttributes(self.attributes)
    self.attributes.link = URL(string: destination, relativeTo: self.baseURL)

    for child in children {
      self.render(child)
    }

    self.attributes = savedAttributes
  }

  private mutating func renderImage(source: String, children: [InlineNode]) {
    // AttributedString does not support images
  }
}

extension TextStyle {
  fileprivate func mergingAttributes(_ attributes: AttributeContainer) -> AttributeContainer {
    var newAttributes = attributes
    self._collectAttributes(in: &newAttributes)
    return newAttributes
  }
}

extension AttributeContainer {
  fileprivate func applyingOpacity(_ opacity: Double) -> AttributeContainer {
    guard opacity < 1 else { return self }
    var attributes = self
    attributes.foregroundColor = (attributes.foregroundColor ?? .primary).opacity(opacity)
    if let backgroundColor = attributes.backgroundColor {
      attributes.backgroundColor = backgroundColor.opacity(opacity)
    }
    return attributes
  }
}
