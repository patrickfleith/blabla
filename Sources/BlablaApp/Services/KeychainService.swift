import Foundation
import Security

enum KeychainServiceError: LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .invalidData:
            return "The stored keychain value is corrupted."
        }
    }
}

final class KeychainService {
    private let service = "com.astro.blabla"

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainServiceError.unexpectedStatus(addStatus)
            }
            return
        }

        guard updateStatus == errSecSuccess else {
            throw KeychainServiceError.unexpectedStatus(updateStatus)
        }
    }

    func read(account: String) throws -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let string = String(data: data, encoding: .utf8) else {
                throw KeychainServiceError.invalidData
            }
            return string
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainServiceError.unexpectedStatus(status)
        }
    }

    func delete(account: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainServiceError.unexpectedStatus(status)
        }
    }

    func hasValue(account: String) -> Bool {
        (try? read(account: account))?.isEmpty == false
    }
}
