//
//  DamageDoctorFlowUITests.swift
//  DD-iOSUITests
//
//  UI tests for the real app flow: photo input -> v7 detector -> Results.
//  (No classifier gate: the app runs the detector only.)
//
//  This file is NOT part of any target yet. Add a UI Testing Bundle target
//  named "DD-iOSUITests" in Xcode (see the PR description) so it compiles.
//
//  Accessibility identifiers used (set in the app's views):
//    Home:    takePhotoButton, choosePhotoButton, chooseFileButton, historyCard
//    Results: annotatedImage, resultImage, boundingBox, analyzingState,
//             resultState ("No damage detected" / "Damage Found"),
//             detectionList, detectionRow, shareButton
//    History: historyEmptyState
//
//  The camera is never opened: UIImagePickerController's camera source does
//  not exist in the simulator. Results tests inject a photo through the
//  Debug-only DD_UITEST_IMAGE launch environment variable (see HomeView).
//

import XCTest
import UIKit

// XCUIApplication / XCUIElement are @MainActor in the iOS 18+ SDKs, so the whole
// class is main-actor isolated. No setUp/tearDown overrides on purpose: overriding
// XCTestCase's nonisolated setUp from a @MainActor class is an isolation mismatch.
@MainActor
final class DamageDoctorFlowUITests: XCTestCase {

    // Set by launch(); not initialized inline because XCTestCase's init is nonisolated.
    private var app: XCUIApplication!

    /// Generous: the first CoreML load on a cold simulator can be slow.
    private let resultTimeout: TimeInterval = 60

    // MARK: - Home

    func testHomeShowsAllEntryPoints() throws {
        launch()

        XCTAssertTrue(element("takePhotoButton").waitForExistence(timeout: 10))
        XCTAssertTrue(element("choosePhotoButton").exists)
        XCTAssertTrue(element("chooseFileButton").exists)
        XCTAssertTrue(element("historyCard").exists)
    }

    func testHistoryShowsEmptyState() throws {
        launch()

        let history = element("historyCard")
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()

        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        XCTAssertTrue(element("historyEmptyState").exists)
    }

    func testLibraryButtonOpensPhotoPicker() throws {
        launch()

        let library = element("choosePhotoButton")
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.tap()

        // PHPickerViewController runs out of process; its Cancel button is still
        // reachable through the app's element tree.
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "Photo picker did not appear")
        cancel.tap()
        XCTAssertTrue(library.waitForExistence(timeout: 5))
    }

    // MARK: - Results (injected photo)

    func testDamagedPhotoShowsDetections() throws {
        let path = try cardDDFixturePath()
        launch(withImageAt: path)

        let state = element("resultState")
        XCTAssertTrue(state.waitForExistence(timeout: resultTimeout), "No result appeared")
        XCTAssertTrue(state.label.contains("Damage Found"),
                       "Expected damage on CarDD test image \(path). If the v7 model genuinely misses it "
                       + "(check cardd_ios_benchmark.csv), pick another fixture in cardDDFixturePath().")

        XCTAssertTrue(element("detectionList").exists)
        XCTAssertGreaterThan(elements("detectionRow").count, 0)

        // Rows show the detector's class names, capitalized by ResultsView
        let classNames = ["Dent", "Scratch", "Crack", "Glass Shatter", "Lamp Broken", "Tire Flat"]
        let rowLabels = elements("detectionRow").allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(rowLabels.contains { row in classNames.contains { row.contains($0) } },
                      "No known damage class in rows: \(rowLabels)")

        XCTAssertTrue(element("annotatedImage").exists)
        XCTAssertGreaterThan(elements("boundingBox").count, 0)
        XCTAssertTrue(element("shareButton").exists)
    }

    func testPlainImageShowsAResult() throws {
        // A uniform gray image: we only require that analysis finishes and the
        // Results screen is internally consistent, not a specific verdict.
        let path = try writePlainImage()
        launch(withImageAt: path)

        let state = element("resultState")
        XCTAssertTrue(state.waitForExistence(timeout: resultTimeout), "No result appeared")
        XCTAssertTrue(element("annotatedImage").exists)

        if state.label.contains("No damage") {
            XCTAssertFalse(element("detectionList").exists)
            XCTAssertEqual(elements("boundingBox").count, 0)
            XCTAssertFalse(element("shareButton").exists)
        } else {
            XCTAssertTrue(state.label.contains("Damage Found"), "Unexpected result state: \(state.label)")
            XCTAssertTrue(element("detectionList").exists)
        }
    }

    // MARK: - Helpers

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func elements(_ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    private func launch(withImageAt path: String? = nil) {
        continueAfterFailure = false
        app = XCUIApplication()
        if let path {
            app.launchEnvironment["DD_UITEST_IMAGE"] = path
        }
        app.launch()
    }

    /// A CarDD test image from the unit-test folder, read straight from the Mac's
    /// file system. Works on the simulator (it shares the host file system), not on
    /// a physical device.
    private func cardDDFixturePath() throws -> String {
        let imagesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // DD-iOSUITests/
            .deletingLastPathComponent()          // DD-iOS/
            .appendingPathComponent("DD-iOSTests/images")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: imagesDir.path)) ?? []
        guard let first = names.filter({ $0.lowercased().hasSuffix(".jpg") }).sorted().first else {
            throw XCTSkip("No CarDD images at \(imagesDir.path) (run on the simulator from a checkout)")
        }
        return imagesDir.appendingPathComponent(first).path
    }

    private func writePlainImage() throws -> String {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 600), format: format).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        }
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw XCTSkip("Could not encode the plain test image")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dd_uitest_plain.jpg")
        try data.write(to: url)
        return url.path
    }
}
