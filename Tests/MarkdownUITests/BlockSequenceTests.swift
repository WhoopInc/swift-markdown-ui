#if os(macOS)
  import AppKit
  import SwiftUI
  import XCTest

  @testable import MarkdownUI

  @MainActor
  final class BlockSequenceTests: XCTestCase {
    func testUpdatingAndAppendingBlocksPreservesExistingViews() throws {
      let model = BlocksModel()
      let recorder = ViewRecorder()
      let hostingView = NSHostingView(rootView: BlocksView(model: model, recorder: recorder))
      hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 480)
      hostingView.layoutSubtreeIfNeeded()
      let originalView = try XCTUnwrap(recorder.views[0])

      model.blocks = ["First block with streamed content", "Second block"]
      let update = expectation(description: "Blocks update without replacing existing views")
      recorder.didUpdate = {
        if recorder.views[0]?.stringValue == model.blocks[0], recorder.views[1] != nil {
          update.fulfill()
          recorder.didUpdate = nil
        }
      }
      hostingView.layoutSubtreeIfNeeded()
      wait(for: [update], timeout: 2)

      XCTAssertTrue(recorder.views[0] === originalView)
      XCTAssertEqual(recorder.views[0]?.stringValue, model.blocks[0])
      XCTAssertEqual(recorder.views[1]?.stringValue, model.blocks[1])
    }
  }

  private final class BlocksModel: ObservableObject {
    @Published var blocks = ["First block"]
  }

  private final class ViewRecorder {
    var views: [Int: NSTextField] = [:]
    var didUpdate: (() -> Void)?
  }

  private struct BlocksView: View {
    @ObservedObject var model: BlocksModel
    let recorder: ViewRecorder

    var body: some View {
      BlockSequence(model.blocks) { index, text in
        BlockView(index: index, text: text, recorder: recorder)
      }
    }
  }

  private struct BlockView: NSViewRepresentable {
    let index: Int
    let text: String
    let recorder: ViewRecorder

    func makeNSView(context: Context) -> NSTextField {
      let view = NSTextField(labelWithString: text)
      recorder.views[index] = view
      return view
    }

    func updateNSView(_ view: NSTextField, context: Context) {
      view.stringValue = text
      recorder.didUpdate?()
    }
  }
#endif
