enum ForwarderSecrets {
    static var pairId: String { ForwarderLocalSecrets.pairId }
    static var pairSecret: String { ForwarderLocalSecrets.pairSecret }
    static var baseURL: String { ForwarderLocalSecrets.baseURL }
    static var appKey: String { ForwarderLocalSecrets.appKey }

    static var isConfigured: Bool {
        !baseURL.isEmpty && !pairSecret.isEmpty
    }

    static var canCreatePair: Bool {
        !baseURL.isEmpty && !appKey.isEmpty
    }
}
