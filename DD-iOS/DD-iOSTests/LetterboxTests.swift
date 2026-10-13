//
//  LetterboxTests.swift
//  DD-iOS
//
//  Pure-math tests for LetterboxGeometry. Expected values were cross-checked
//  against ultralytics.data.augment.LetterBox (content rect + pad) in Python.
//

import XCTest
import CoreGraphics
@testable import DD_iOS

final class LetterboxTests: XCTestCase {

    private let eps: CGFloat = 1e-9

    private func assertRect(_ a: CGRect?, _ b: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        guard let a else {
            XCTFail("rect is nil, expected \(b)", file: file, line: line)
            return
        }
        XCTAssertEqual(a.minX, b.minX, accuracy: eps, "minX", file: file, line: line)
        XCTAssertEqual(a.minY, b.minY, accuracy: eps, "minY", file: file, line: line)
        XCTAssertEqual(a.width, b.width, accuracy: eps, "width", file: file, line: line)
        XCTAssertEqual(a.height, b.height, accuracy: eps, "height", file: file, line: line)
    }

    // MARK: - Geometry

    func testLandscapeGeometry() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1280, height: 720))
        XCTAssertEqual(g.scale, 0.5, accuracy: eps)
        XCTAssertEqual(g.scaledSize, CGSize(width: 640, height: 360))
        XCTAssertEqual(g.padding, CGPoint(x: 0, y: 140))
        XCTAssertEqual(g.contentRect, CGRect(x: 0, y: 140, width: 640, height: 360))
    }

    func testPortraitGeometry() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 720, height: 1280))
        XCTAssertEqual(g.scaledSize, CGSize(width: 360, height: 640))
        XCTAssertEqual(g.padding, CGPoint(x: 140, y: 0))
    }

    func testSquareGeometryIsIdentity() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1000, height: 1000))
        XCTAssertEqual(g.scale, 0.64, accuracy: eps)
        XCTAssertEqual(g.scaledSize, CGSize(width: 640, height: 640))
        XCTAssertEqual(g.padding, .zero)
    }

    func testPhonePhotoGeometry() {
        // 12 MP iPhone photo, both orientations
        let landscape = LetterboxGeometry(sourceSize: CGSize(width: 4032, height: 3024))
        XCTAssertEqual(landscape.contentRect, CGRect(x: 0, y: 80, width: 640, height: 480))
        let portrait = LetterboxGeometry(sourceSize: CGSize(width: 3024, height: 4032))
        XCTAssertEqual(portrait.contentRect, CGRect(x: 80, y: 0, width: 480, height: 640))
    }

    func testOddSizeRoundsLikeUltralytics() {
        // 1000x333 -> 640x213.12 -> 213 rows, dh = 213.5 -> top = round(213.4) = 213
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1000, height: 333))
        XCTAssertEqual(g.contentRect, CGRect(x: 0, y: 213, width: 640, height: 213))
    }

    func testSmallImageIsUpscaled() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 320, height: 240))
        XCTAssertEqual(g.scale, 2, accuracy: eps)
        XCTAssertEqual(g.contentRect, CGRect(x: 0, y: 80, width: 640, height: 480))
    }

    // MARK: - Box remapping

    func testLandscapeBoxRemap() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1280, height: 720))
        // Square-normalized box -> source-normalized box
        let square = CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.140625)
        assertRect(g.unletterbox(square), CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25))
    }

    func testPortraitBoxRemap() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 720, height: 1280))
        let square = CGRect(x: 0.359375, y: 0.5, width: 0.28125, height: 0.25)
        assertRect(g.unletterbox(square), CGRect(x: 0.25, y: 0.5, width: 0.5, height: 0.25))
    }

    func testSquareBoxRemapIsIdentity() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1000, height: 1000))
        let box = CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        assertRect(g.unletterbox(box), box)
    }

    func testRoundTrip() {
        let sizes = [CGSize(width: 1280, height: 720), CGSize(width: 720, height: 1280),
                     CGSize(width: 1000, height: 1000), CGSize(width: 4032, height: 3024),
                     CGSize(width: 1000, height: 333)]
        let box = CGRect(x: 0.12, y: 0.34, width: 0.4, height: 0.5)
        for size in sizes {
            let g = LetterboxGeometry(sourceSize: size)
            assertRect(g.unletterbox(g.letterbox(box)), box)
        }
    }

    func testBoxOverlappingPaddingIsClipped() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1280, height: 720))
        // y from 96px to 224px in the square; content starts at 140px
        let square = CGRect(x: 0.1, y: 0.15, width: 0.2, height: 0.2)
        let expected = CGRect(x: 0.1, y: 0, width: 0.2, height: (224.0 - 140.0) / 360.0)
        assertRect(g.unletterbox(square), expected)
    }

    func testBoxEntirelyInPaddingIsDropped() {
        let g = LetterboxGeometry(sourceSize: CGSize(width: 1280, height: 720))
        XCTAssertNil(g.unletterbox(CGRect(x: 0.1, y: 0.0, width: 0.2, height: 0.1)))
    }

    // MARK: - Vision flip

    func testVisionFlipToTopLeft() {
        let flipped = Letterbox.topLeftFromVision(CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4))
        assertRect(flipped, CGRect(x: 0.1, y: 0.4, width: 0.3, height: 0.4))
    }
}
