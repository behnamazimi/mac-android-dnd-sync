import Foundation
import Security

/// One row of the persisted "Recent activity" trail. Kept as its own Codable
/// type (rather than reusing `SyncEvent` from `ProductRouting.swift`) so this
/// storage layer doesn't depend on UI-layer types.
struct PersistedSyncEvent: Codable, Equatable {
    var unixMs: Int64
    var on: Bool
    var sender: String
}

struct PersistedPair: Codable {
    var pairId: String
    var pairSecret: String
    var forwarderURL: String
    var privateKeyB64: String
    var publicKeyB64: String
    var peerPublicKeyB64: String?
    var lastSyncUnixMs: Int64
    var lastSyncOn: Bool
    var lastSyncSender: String
    var lastSyncViaLan: Bool
    /// Full Home "Recent activity" trail (max 5, newest first), local to this
    /// device only. Kept alongside `lastSync*` so quitting and relaunching
    /// the app doesn't drop the trail back to a single row.
    var recentActivity: [PersistedSyncEvent]
    /// What this Mac last registered with the forwarder (pair id, APNs token,
    /// environment, E2E key). An unchanged fingerprint skips the PUT that
    /// every APNs re-registration on app activation would otherwise send.
    var registeredFingerprint: String?

    init(
        pairId: String,
        pairSecret: String,
        forwarderURL: String,
        privateKeyB64: String,
        publicKeyB64: String,
        peerPublicKeyB64: String?,
        lastSyncUnixMs: Int64 = 0,
        lastSyncOn: Bool = false,
        lastSyncSender: String = "",
        lastSyncViaLan: Bool = false,
        recentActivity: [PersistedSyncEvent] = [],
        registeredFingerprint: String? = nil
    ) {
        self.pairId = pairId
        self.pairSecret = pairSecret
        self.forwarderURL = forwarderURL
        self.privateKeyB64 = privateKeyB64
        self.publicKeyB64 = publicKeyB64
        self.peerPublicKeyB64 = peerPublicKeyB64
        self.lastSyncUnixMs = lastSyncUnixMs
        self.lastSyncOn = lastSyncOn
        self.lastSyncSender = lastSyncSender
        self.lastSyncViaLan = lastSyncViaLan
        self.recentActivity = recentActivity
        self.registeredFingerprint = registeredFingerprint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pairId = try container.decode(String.self, forKey: .pairId)
        pairSecret = try container.decode(String.self, forKey: .pairSecret)
        forwarderURL = try container.decode(String.self, forKey: .forwarderURL)
        privateKeyB64 = try container.decode(String.self, forKey: .privateKeyB64)
        publicKeyB64 = try container.decode(String.self, forKey: .publicKeyB64)
        peerPublicKeyB64 = try container.decodeIfPresent(String.self, forKey: .peerPublicKeyB64)
        lastSyncUnixMs = try container.decodeIfPresent(Int64.self, forKey: .lastSyncUnixMs) ?? 0
        lastSyncOn = try container.decodeIfPresent(Bool.self, forKey: .lastSyncOn) ?? false
        lastSyncSender = try container.decodeIfPresent(String.self, forKey: .lastSyncSender) ?? ""
        lastSyncViaLan = try container.decodeIfPresent(Bool.self, forKey: .lastSyncViaLan) ?? false
        // Missing for pairs persisted before this trail existed; `restore()`
        // seeds a single row from `lastSync*` in that case.
        recentActivity = try container.decodeIfPresent([PersistedSyncEvent].self, forKey: .recentActivity) ?? []
        registeredFingerprint = try container.decodeIfPresent(String.self, forKey: .registeredFingerprint)
    }
}

final class PairStore {
    private static let service = "com.dndsync.macos.pair"
    private static let account = "current"

    func load() -> PersistedPair? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(PersistedPair.self, from: data)
    }

    func save(_ pair: PersistedPair) {
        guard let data = try? JSONEncoder().encode(pair) else {
            return
        }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        SecItemDelete(base as CFDictionary)
        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(insert as CFDictionary, nil)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
