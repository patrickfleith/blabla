import Foundation
import Testing
@testable import BlablaApp

struct MultipartFormDataBuilderTests {
    @Test
    func builderProducesMultipartBodyWithFieldsAndFile() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try Data("hello".utf8).write(to: fileURL)
        defer {
            try? FileManager.default.removeItem(at: fileURL)
        }

        var builder = MultipartFormDataBuilder(boundary: "Boundary-Tests")
        builder.addTextField(name: "model", value: "gpt-4o-transcribe")
        try builder.addFileField(name: "file", fileURL: fileURL, mimeType: "text/plain")

        let body = builder.finalize()
        let bodyString = String(decoding: body, as: UTF8.self)

        #expect(bodyString.contains("Content-Disposition: form-data; name=\"model\""))
        #expect(bodyString.contains("gpt-4o-transcribe"))
        #expect(bodyString.contains("filename=\"\(fileURL.lastPathComponent)\""))
        #expect(bodyString.contains("Content-Type: text/plain"))
        #expect(bodyString.contains("hello"))
        #expect(bodyString.contains("--Boundary-Tests--"))
    }
}
