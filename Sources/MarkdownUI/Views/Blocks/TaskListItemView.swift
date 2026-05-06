import SwiftUI

struct TaskListItemView: View {
  @Environment(\.theme.listItem) private var listItem
  @Environment(\.theme.taskListMarker) private var taskListMarker

  private let item: RawTaskListItem

  init(item: RawTaskListItem) {
    self.item = item
  }

  var body: some View {
    self.listItem.makeBody(
      configuration: .init(
        label: .init(self.label),
        content: .init(blocks: item.children)
      )
    )
  }

  @ViewBuilder private var label: some View {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
      MarkdownListItemLayout {
        self.taskListMarker.makeBody(configuration: .init(isCompleted: self.item.isCompleted))
          .textStyleFont()
        BlockSequence(self.item.children)
      }
    } else {
      Label {
        BlockSequence(self.item.children)
      } icon: {
        self.taskListMarker.makeBody(configuration: .init(isCompleted: self.item.isCompleted))
          .textStyleFont()
      }
    }
  }
}
