@testable import MarkdownUI
import SwiftUI
import XCTest

final class MarkdownContentTrailingTextOpacityTests: XCTestCase {
  func testAppliesLinearOpacityToTrailingCharacterCount() {
    let content = MarkdownContent("0123456789")

    let transformed = content.applyingTrailingTextOpacity(fadeCharacterCount: 4, minimumOpacity: 0.2)

    let runs = transformed.opacityRuns
    XCTAssertEqual(runs.map(\.text), ["6", "7", "8", "9"])
    assertEqual(runs.map(\.opacity), [1, 0.7333333333, 0.4666666667, 0.2], accuracy: 0.0001)
    XCTAssertEqual(transformed.renderPlainText(), content.renderPlainText())
    XCTAssertEqual(transformed.renderMarkdown(), content.renderMarkdown())
  }

  func testCountsExtendedGraphemeClusters() {
    let content = MarkdownContent("A👨‍👩‍👧‍👦B")

    let transformed = content.applyingTrailingTextOpacity(fadeCharacterCount: 3, minimumOpacity: 0.2)

    XCTAssertEqual(transformed.opacityRuns.map(\.text), ["A", "👨‍👩‍👧‍👦", "B"])
  }

  func testFadesSoftAndHardLineBreaks() {
    let content = MarkdownContent("A\nB  \nC")

    let transformed = content.applyingTrailingTextOpacity(
      fadeCharacterCount: 5,
      minimumOpacity: 0.2
    )

    XCTAssertEqual(transformed.opacityRuns.map(\.text), ["A", " ", "B", "\n", "C"])
    assertEqual(
      transformed.opacityRuns.map(\.opacity),
      [1, 0.8, 0.6, 0.4, 0.2],
      accuracy: 0.0001
    )
  }

  func testFadesInlineHTMLWithoutChangingMarkdown() {
    let content = MarkdownContent("A<kbd>B<br>C")

    let transformed = content.applyingTrailingTextOpacity(
      fadeCharacterCount: 9,
      minimumOpacity: 0.2
    )

    XCTAssertEqual(
      transformed.opacityRuns.map(\.text),
      ["A", "<", "k", "b", "d", ">", "B", "<br>", "C"]
    )
    XCTAssertEqual(transformed.renderMarkdown(), content.renderMarkdown())
  }

  func testNormalizesOpacityWhenContentIsShorterThanFadeCharacterCount() {
    let content = MarkdownContent("Hi")

    let transformed = content.applyingTrailingTextOpacity(
      fadeCharacterCount: 8,
      minimumOpacity: 0.2
    )

    XCTAssertEqual(transformed.opacityRuns.map(\.text), ["H", "i"])
    assertEqual(transformed.opacityRuns.map(\.opacity), [1, 0.2], accuracy: 0.0001)
  }

  func testAppliesMinimumOpacityToSingleCharacterContent() {
    let content = MarkdownContent("H")

    let transformed = content.applyingTrailingTextOpacity(
      fadeCharacterCount: 8,
      minimumOpacity: 0.2
    )

    XCTAssertEqual(transformed.opacityRuns.map(\.text), ["H"])
    XCTAssertEqual(transformed.opacityRuns.first?.opacity ?? 0, 0.2, accuracy: 0.0001)
  }

  func testPreservesNestedInlineStyles() {
    let content = MarkdownContent("Start **bold** [link](https://whoop.com) `code`")

    let transformed = content.applyingTrailingTextOpacity(fadeCharacterCount: 8, minimumOpacity: 0.12)

    XCTAssertEqual(transformed.renderPlainText(), content.renderPlainText())
    XCTAssertEqual(transformed.renderMarkdown(), content.renderMarkdown())
    XCTAssertEqual(transformed.opacityRuns.last?.text, "e")
    XCTAssertEqual(transformed.opacityRuns.last?.opacity ?? 0, 0.12, accuracy: 0.0001)
  }

  func testPreservesOpaquePrefixOfInlineCode() {
    let content = MarkdownContent("Before `abcdefghij`")

    let transformed = content.applyingTrailingTextOpacity(fadeCharacterCount: 2, minimumOpacity: 0.12)

    XCTAssertEqual(transformed.renderPlainText(), content.renderPlainText())
    XCTAssertEqual(transformed.renderMarkdown(), content.renderMarkdown())
  }

  func testFadesOnlyTheDocumentTailAcrossBlocks() {
    let content = MarkdownContent("First paragraph.\n\nSecond paragraph.")

    let transformed = content.applyingTrailingTextOpacity(fadeCharacterCount: 6, minimumOpacity: 0.2)

    XCTAssertEqual(transformed.opacityRuns.map(\.text).joined(), "graph.")
  }

  func testFencedCodeCountsTowardTailWithoutChangingTheBlock() {
    let content = MarkdownContent("Before\n\n```\n1234567890\n```")

    let transformed = content.applyingTrailingTextOpacity(fadeCharacterCount: 8, minimumOpacity: 0.12)

    XCTAssertTrue(transformed.opacityRuns.isEmpty)
    XCTAssertEqual(transformed.renderPlainText(), content.renderPlainText())
    XCTAssertEqual(transformed.renderMarkdown(), content.renderMarkdown())
  }

  func testFadeCharacterCountBelowTwoLeavesContentUnchanged() {
    let content = MarkdownContent("Hello")

    XCTAssertEqual(
      content.applyingTrailingTextOpacity(fadeCharacterCount: 0, minimumOpacity: 0.2),
      content
    )
    XCTAssertEqual(
      content.applyingTrailingTextOpacity(fadeCharacterCount: 1, minimumOpacity: 0.2),
      content
    )
  }

  func testClampsMinimumOpacity() {
    let content = MarkdownContent("Hello")

    let belowZero = content.applyingTrailingTextOpacity(fadeCharacterCount: 2, minimumOpacity: -1)
    let aboveOne = content.applyingTrailingTextOpacity(fadeCharacterCount: 2, minimumOpacity: 2)

    XCTAssertEqual(belowZero.opacityRuns.last?.opacity, 0)
    XCTAssertEqual(aboveOne.opacityRuns.last?.opacity, 1)
  }

  func testSerializesOpacityNodesWithoutDroppingContent() {
    let blocks: [BlockNode] = [
      .paragraph(content: [
        .text("A"),
        .opacity(0.5, children: [.text("B"), .text("C")]),
      ])
    ]

    XCTAssertEqual(blocks.renderMarkdown(), "ABC\n")
  }

  func testAppliesOpacityToForegroundAndBackgroundColors() throws {
    let emptyStyle = EmptyTextStyle()
    let textStyles = InlineTextStyles(
      code: BackgroundColor(.cyan),
      emphasis: emptyStyle,
      strong: emptyStyle,
      strikethrough: emptyStyle,
      link: emptyStyle
    )
    let attributedString = InlineNode.opacity(0.2, children: [.code("code")])
      .renderAttributedString(
        baseURL: nil,
        textStyles: textStyles,
        softBreakMode: .space,
        attributes: AttributeContainer().foregroundColor(.red)
      )

    let attributes = try XCTUnwrap(attributedString.runs.first?.attributes)
    XCTAssertEqual(attributes.foregroundColor, Color.red.opacity(0.2))
    XCTAssertEqual(attributes.backgroundColor, Color.cyan.opacity(0.2))
  }
}

private extension MarkdownContent {
  var opacityRuns: [(text: String, opacity: Double)] {
    self.blocks.flatMap(\.opacityRuns)
  }
}

private extension BlockNode {
  var opacityRuns: [(text: String, opacity: Double)] {
    switch self {
    case .blockquote(let children):
      return children.flatMap(\.opacityRuns)
    case .bulletedList(_, let items), .numberedList(_, _, let items):
      return items.flatMap { $0.children.flatMap(\.opacityRuns) }
    case .taskList(_, let items):
      return items.flatMap { $0.children.flatMap(\.opacityRuns) }
    case .paragraph(let content), .heading(_, let content):
      return content.flatMap(\.opacityRuns)
    case .table(_, let rows):
      return rows.flatMap { row in
        row.cells.flatMap { $0.content.flatMap(\.opacityRuns) }
      }
    case .codeBlock, .htmlBlock, .thematicBreak:
      return []
    }
  }
}

private extension InlineNode {
  var opacityRuns: [(text: String, opacity: Double)] {
    switch self {
    case .opacity(let opacity, let children):
      return [(children.renderPlainText(), opacity)]
    default:
      return self.children.flatMap(\.opacityRuns)
    }
  }
}

private extension XCTestCase {
  func assertEqual(
    _ actual: [Double],
    _ expected: [Double],
    accuracy: Double,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(actual.count, expected.count, file: file, line: line)
    for (actual, expected) in zip(actual, expected) {
      XCTAssertEqual(actual, expected, accuracy: accuracy, file: file, line: line)
    }
  }
}
