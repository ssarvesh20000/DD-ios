//
//  DetectorBenchmarkTests.swift
//  DD-iOS
//
//  Created by Sarvesh Shanmugam on 4/22/26.
//

import XCTest
import UIKit
@testable import DD_iOS   // replace DD_iOS with your actual app module name

final class DetectorBenchmarkTests: XCTestCase {

    func testBenchmarkCarDDTestSplit() async throws {
        // Load all jpg/png images from the bundled folder
        let bundle = Bundle(for: type(of: self))
        let jpgs = bundle.urls(forResourcesWithExtension: "jpg", subdirectory: nil) ?? []
        let pngs = bundle.urls(forResourcesWithExtension: "png", subdirectory: "images") ?? []
        let imageURLs = (jpgs + pngs).sorted { $0.lastPathComponent < $1.lastPathComponent }

        XCTAssertFalse(imageURLs.isEmpty, "No test images found. Check that the 'images' folder is a blue folder reference in the test target.")
        print("[Benchmark] Found \(imageURLs.count) images")

        // CSV header
        var rows: [String] = ["filename,state,detection_count,top_label,top_confidence,all_labels"]

        // One view model for the whole run — avoids reloading the CoreML model 400 times
        let vm = await DamageDetectionViewModel()

        for (i, url) in imageURLs.enumerated() {
            guard let image = UIImage(contentsOfFile: url.path) else {
                rows.append("\(url.lastPathComponent),load_failed,0,,,")
                continue
            }

            await vm.analyze(image: image)

            let filename = url.lastPathComponent
            switch vm.state {
            case .damageFound(let detections):
                let top = detections.max(by: { $0.confidence < $1.confidence })
                let allLabels = detections.map { "\($0.label):\(Int($0.confidence * 100))" }.joined(separator: "|")
                rows.append("\(filename),damage,\(detections.count),\(top?.label ?? ""),\(top?.confidence ?? 0),\(allLabels)")
            case .noDamage:
                rows.append("\(filename),no_damage,0,,,")
            case .analyzing:
                rows.append("\(filename),stuck_analyzing,0,,,")
            case .idle:
                rows.append("\(filename),idle,0,,,")
            }

            if (i + 1) % 25 == 0 {
                print("[Benchmark] Processed \(i + 1)/\(imageURLs.count)")
            }
        }

        // Write CSV to a location we can find after the test ends
        let csv = rows.joined(separator: "\n")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("cardd_ios_benchmark.csv")
        try csv.write(to: out, atomically: true, encoding: .utf8)

        print("[Benchmark] ---- DONE ----")
        print("[Benchmark] Results written to: \(out.path)")
        print("[Benchmark] Total images: \(imageURLs.count)")
    }
}
