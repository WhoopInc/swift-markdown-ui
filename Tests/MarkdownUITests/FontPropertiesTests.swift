#if !os(tvOS)
  import SwiftUI
  import XCTest

  @testable import MarkdownUI

  final class FontPropertiesTests: XCTestCase {
    func testFontWithProperties() {
      // given
      var fontProperties = FontProperties()

      // then
      XCTAssertFontEqual(
        Font.system(size: FontProperties.defaultSize, design: .default),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(family: .custom("Menlo"))

      // then
      XCTAssertFontEqual(
        Font.custom("Menlo", fixedSize: FontProperties.defaultSize),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(familyVariant: .monospaced)

      // then
      XCTAssertFontEqual(
        Font.system(size: FontProperties.defaultSize, design: .default).monospaced(),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(capsVariant: .lowercaseSmallCaps)

      // then
      XCTAssertFontEqual(
        Font.system(size: FontProperties.defaultSize, design: .default).lowercaseSmallCaps(),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(digitVariant: .monospaced)

      // then
      XCTAssertFontEqual(
        Font.system(size: FontProperties.defaultSize, design: .default).monospacedDigit(),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(style: .italic)

      // then
      XCTAssertFontEqual(
        Font.system(size: FontProperties.defaultSize, design: .default).italic(),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(weight: .heavy)

      // then
      XCTAssertFontEqual(
        Font.system(size: FontProperties.defaultSize, design: .default).weight(.heavy),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(size: 42)

      // then
      XCTAssertFontEqual(
        Font.system(size: 42, design: .default),
        Font.withProperties(fontProperties)
      )

      // when
      fontProperties = FontProperties(scale: 1.5)

      // then
      XCTAssertFontEqual(
        Font.system(size: round(FontProperties.defaultSize * 1.5), design: .default),
        Font.withProperties(fontProperties)
      )
    }

    private func XCTAssertFontEqual(
      _ lhs: Font,
      _ rhs: Font,
      file: StaticString = #filePath,
      line: UInt = #line
    ) {
      #if os(macOS)
        XCTAssertEqual(String(describing: lhs), String(describing: rhs), file: file, line: line)
      #else
        XCTAssertEqual(lhs, rhs, file: file, line: line)
      #endif
    }
  }
#endif
