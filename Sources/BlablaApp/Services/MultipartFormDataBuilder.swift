import Foundation
import UniformTypeIdentifiers

struct MultipartFormDataBuilder {
    let boundary: String
    private var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func addTextField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    mutating func addFileField(name: String, fileURL: URL, mimeType: String? = nil) throws {
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        let detectedMimeType = mimeType ?? Self.mimeType(for: fileURL)

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(detectedMimeType)\r\n\r\n")
        body.append(fileData)
        append("\r\n")
    }

    mutating func finalize() -> Data {
        append("--\(boundary)--\r\n")
        return body
    }

    private mutating func append(_ string: String) {
        body.append(Data(string.utf8))
    }

    static func mimeType(for fileURL: URL) -> String {
        guard let type = UTType(filenameExtension: fileURL.pathExtension),
              let mimeType = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mimeType
    }
}
