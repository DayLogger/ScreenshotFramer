//
//  FileController.swift
//  Screenshot Framer
//
//  Created by Patrick Kladek on 15.12.17.
//  Copyright © 2017 Patrick Kladek. All rights reserved.
//

import Foundation

/**
 * This class stores properties that are not known on init
 * projectURL ist only set after a new document is saved
 * most classes need the projectURL property but not directly
 * on init but later eg export
 */
final class FileCapsule {

    var projectURL: URL?
    var projectBaseName: String?

    var rawScreenshotsURL: URL? {
        return projectURL?.appendingPathComponent("raw", isDirectory: true)
    }

}


final class FileController {

    // MARK: - Properties

    let fileCapsule: FileCapsule


    // MARK: Lifecycle

    init(fileCapsule: FileCapsule) {
        self.fileCapsule = fileCapsule
    }


    // MARK: - Functions

    func absoluteURL(for relativePath: String, viewState: ViewState) -> URL? {
        guard relativePath.hasElements else { return nil }

        func extractURL(from language: String = "", with specialization: String? = nil) -> URL? {
            var file = relativePath.replacingOccurrences(of: "$image", with: "\(viewState.imageNumber)")
            file = file.replacingOccurrences(of: "$language", with: language).replacingOccurrences(of: "//", with: "/")
            guard var result = self.fileCapsule.projectURL?.appendingPathComponent(file) else { return nil }
            if let specialization = specialization {
                let ext = result.pathExtension
                let fileName = result.lastPathComponent.replacingOccurrences(of: ".\(ext)", with: "-\(specialization).\(ext)")
                result.deleteLastPathComponent()
                result.appendPathComponent(fileName)
            }
            return result
        }

        let projectName = fileCapsule.projectBaseName
        if let url = extractURL(from: viewState.language, with: projectName), url.fileExists {
            return url
        }
        if let url = extractURL(from: viewState.language), url.fileExists {
            return url
        }
        if let url = extractURL(with: projectName), url.fileExists {
            return url
        }
        return extractURL()
    }

    func localizedTitle(from url: URL?, viewState: ViewState) -> String? {
        guard let url = url else { return nil }
        guard let dict = NSDictionary(contentsOf: url) else { return nil }

        let value = dict["\(viewState.imageNumber)"] as? String
        return value
    }

    func outputURL(for layerState: LayerState, viewState: ViewState) -> URL? {
        guard let base = self.fileCapsule.projectURL else { return nil }
        var file = layerState.outputConfig.output.replacingOccurrences(of: "$image", with: "\(viewState.imageNumber)")
        file = file.replacingOccurrences(of: "$language", with: viewState.language)

        return base.appendingPathComponent(file)
    }
}

extension URL {
    var fileExists: Bool {
        return self.isFileURL && FileManager.default.fileExists(atPath: self.path)
    }
}
