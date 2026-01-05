import Foundation
import Security

/// Secure storage for API keys using Keychain
class KeychainService {
    static let shared = KeychainService()
    
    private let service = "com.salescoach.api"
    private let apiKeyAccount = "cloud-api-key"
    private let langfusePublicKeyAccount = "langfuse-public-key"
    private let langfuseSecretKeyAccount = "langfuse-secret-key"
    
    private init() {}
    
    // MARK: - API Key Management
    
    /// Store the API key securely
    func setAPIKey(_ apiKey: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }
        
        // Delete existing key first
        deleteAPIKey()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieve the stored API key
    func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
    
    /// Delete the stored API key
    @discardableResult
    func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: apiKeyAccount
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if an API key is stored
    var hasAPIKey: Bool {
        getAPIKey() != nil
    }
    
    // MARK: - Langfuse Key Management
    
    /// Store the Langfuse public key securely
    func setLangfusePublicKey(_ key: String) -> Bool {
        setKey(key, account: langfusePublicKeyAccount)
    }
    
    /// Retrieve the stored Langfuse public key
    func getLangfusePublicKey() -> String? {
        getKey(account: langfusePublicKeyAccount)
    }
    
    /// Delete the stored Langfuse public key
    @discardableResult
    func deleteLangfusePublicKey() -> Bool {
        deleteKey(account: langfusePublicKeyAccount)
    }
    
    /// Store the Langfuse secret key securely
    func setLangfuseSecretKey(_ key: String) -> Bool {
        setKey(key, account: langfuseSecretKeyAccount)
    }
    
    /// Retrieve the stored Langfuse secret key
    func getLangfuseSecretKey() -> String? {
        getKey(account: langfuseSecretKeyAccount)
    }
    
    /// Delete the stored Langfuse secret key
    @discardableResult
    func deleteLangfuseSecretKey() -> Bool {
        deleteKey(account: langfuseSecretKeyAccount)
    }
    
    /// Check if Langfuse keys are stored
    var hasLangfuseKeys: Bool {
        getLangfusePublicKey() != nil && getLangfuseSecretKey() != nil
    }
    
    // MARK: - Private Helpers
    
    private func setKey(_ key: String, account: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        // Delete existing key first
        deleteKey(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func getKey(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return key
    }
    
    @discardableResult
    private func deleteKey(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

