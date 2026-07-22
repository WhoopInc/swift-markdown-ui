import Foundation

public extension MarkdownContent {
  /// Returns content whose trailing inline text gradually transitions from `1` to
  /// `minimumOpacity`, while preserving the original Markdown structure and inline styles.
  ///
  /// The window is measured in extended grapheme clusters. Markdown syntax and block separators
  /// are not counted. Fenced code and raw HTML blocks count toward the document tail but remain
  /// unchanged. A window smaller than two leaves the content unchanged.
  func applyingTrailingTextOpacity(
    window: Int,
    minimumOpacity: Double
  ) -> MarkdownContent {
    guard window > 1 else { return self }

    let totalCount = self.blocks.renderedInlineCharacterCount
    guard totalCount > 0 else { return self }

    let minimumOpacity = min(max(minimumOpacity, 0), 1)
    let windowStart = max(totalCount - window, 0)
    var offset = 0

    let blocks = self.blocks.rewrite { (block: BlockNode) -> [BlockNode] in
      switch block {
      case .paragraph, .heading, .table:
        return block.rewrite { inline -> [InlineNode] in
          switch inline {
          case .text(let content):
            return Self.applyingTrailingTextOpacity(
              to: content,
              offset: &offset,
              totalCount: totalCount,
              windowStart: windowStart,
              window: window,
              minimumOpacity: minimumOpacity,
              makeNode: InlineNode.text
            )
          case .code(let content):
            return Self.applyingTrailingTextOpacity(
              to: content,
              offset: &offset,
              totalCount: totalCount,
              windowStart: windowStart,
              window: window,
              minimumOpacity: minimumOpacity,
              makeNode: InlineNode.code
            )
          case .softBreak, .lineBreak:
            offset += 1
            return [inline]
          case .html(let content):
            offset += content.renderedCharacterCount
            return [inline]
          default:
            return [inline]
          }
        }
      case .codeBlock(_, let content), .htmlBlock(let content):
        offset += content.renderedBlockCharacterCount
        return [block]
      default:
        return [block]
      }
    }

    return MarkdownContent(blocks: blocks)
  }

  private static func applyingTrailingTextOpacity(
    to content: String,
    offset: inout Int,
    totalCount: Int,
    windowStart: Int,
    window: Int,
    minimumOpacity: Double,
    makeNode: (String) -> InlineNode
  ) -> [InlineNode] {
    var nodes: [InlineNode] = []
    var opaquePrefix = ""

    for character in content {
      let globalIndex = offset
      offset += 1

      guard globalIndex >= windowStart else {
        opaquePrefix.append(character)
        continue
      }

      if !opaquePrefix.isEmpty {
        nodes.append(makeNode(opaquePrefix))
        opaquePrefix = ""
      }

      let distanceFromEnd = totalCount - 1 - globalIndex
      let progress = Double(distanceFromEnd) / Double(window - 1)
      let opacity = minimumOpacity + (1 - minimumOpacity) * progress
      nodes.append(.opacity(opacity, children: [makeNode(String(character))]))
    }

    if !opaquePrefix.isEmpty {
      nodes.append(makeNode(opaquePrefix))
    }

    return nodes
  }
}

private extension Sequence where Element == BlockNode {
  var renderedInlineCharacterCount: Int {
    self.flatMap { block in
      block.inlineCharacterCounts
    }
    .reduce(0, +)
  }
}

private extension BlockNode {
  var inlineCharacterCounts: [Int] {
    switch self {
    case .blockquote(let children):
      return children.flatMap(\.inlineCharacterCounts)
    case .bulletedList(_, let items), .numberedList(_, _, let items):
      return items.flatMap { $0.children.flatMap(\.inlineCharacterCounts) }
    case .taskList(_, let items):
      return items.flatMap { $0.children.flatMap(\.inlineCharacterCounts) }
    case .paragraph(let content), .heading(_, let content):
      return content.flatMap(\.renderedCharacterCounts)
    case .table(_, let rows):
      return rows.flatMap { row in
        row.cells.flatMap { cell in
          cell.content.flatMap(\.renderedCharacterCounts)
        }
      }
    case .codeBlock(_, let content), .htmlBlock(let content):
      return [content.renderedBlockCharacterCount]
    case .thematicBreak:
      return []
    }
  }
}

private extension InlineNode {
  var renderedCharacterCounts: [Int] {
    switch self {
    case .text(let content), .code(let content):
      return [content.count]
    case .html(let content):
      return [content.renderedCharacterCount]
    case .opacity(_, let children):
      return children.flatMap(\.renderedCharacterCounts)
    case .softBreak, .lineBreak:
      return [1]
    case .emphasis(let children), .strong(let children), .strikethrough(let children):
      return children.flatMap(\.renderedCharacterCounts)
    case .link(_, let children):
      return children.flatMap(\.renderedCharacterCounts)
    case .image:
      return []
    }
  }
}

private extension String {
  var renderedCharacterCount: Int {
    HTMLTag(self)?.name.lowercased() == "br" ? 1 : self.count
  }

  var renderedBlockCharacterCount: Int {
    self.hasSuffix("\n") ? String(self.dropLast()).count : self.count
  }
}

extension Sequence where Element == BlockNode {
  var removingTextOpacity: [BlockNode] {
    self.map(\.removingTextOpacity)
  }
}

private extension BlockNode {
  var removingTextOpacity: BlockNode {
    switch self {
    case .blockquote(let children):
      return .blockquote(children: children.removingTextOpacity)
    case .bulletedList(let isTight, let items):
      return .bulletedList(
        isTight: isTight,
        items: items.map { RawListItem(children: $0.children.removingTextOpacity) }
      )
    case .numberedList(let isTight, let start, let items):
      return .numberedList(
        isTight: isTight,
        start: start,
        items: items.map { RawListItem(children: $0.children.removingTextOpacity) }
      )
    case .taskList(let isTight, let items):
      return .taskList(
        isTight: isTight,
        items: items.map {
          RawTaskListItem(
            isCompleted: $0.isCompleted,
            children: $0.children.removingTextOpacity
          )
        }
      )
    case .paragraph(let content):
      return .paragraph(content: content.removingTextOpacity)
    case .heading(let level, let content):
      return .heading(level: level, content: content.removingTextOpacity)
    case .table(let columnAlignments, let rows):
      return .table(
        columnAlignments: columnAlignments,
        rows: rows.map { row in
          RawTableRow(
            cells: row.cells.map { cell in
              RawTableCell(content: cell.content.removingTextOpacity)
            }
          )
        }
      )
    case .codeBlock, .htmlBlock, .thematicBreak:
      return self
    }
  }
}

private extension Sequence where Element == InlineNode {
  var removingTextOpacity: [InlineNode] {
    var result: [InlineNode] = []

    for inline in self {
      let nodes: [InlineNode]
      switch inline {
      case .opacity(_, let children):
        nodes = children.removingTextOpacity
      case .emphasis(let children):
        nodes = [.emphasis(children: children.removingTextOpacity)]
      case .strong(let children):
        nodes = [.strong(children: children.removingTextOpacity)]
      case .strikethrough(let children):
        nodes = [.strikethrough(children: children.removingTextOpacity)]
      case .link(let destination, let children):
        nodes = [.link(destination: destination, children: children.removingTextOpacity)]
      case .image(let source, let children):
        nodes = [.image(source: source, children: children.removingTextOpacity)]
      default:
        nodes = [inline]
      }

      for node in nodes {
        if case .text(let text) = node, case .text(let previous)? = result.last {
          result[result.count - 1] = .text(previous + text)
        } else if case .code(let code) = node, case .code(let previous)? = result.last {
          result[result.count - 1] = .code(previous + code)
        } else {
          result.append(node)
        }
      }
    }

    return result
  }
}
