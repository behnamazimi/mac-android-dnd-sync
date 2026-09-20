enum LanConstants {
    /// Bonjour service type. Must match `NSBonjourServices` in Info.plist.
    static let serviceType = "_dndsync._tcp"
    static let pairId = "dndsync-dev"
    static let pairTxtKey = "pair"
    static let macInstanceName = "dndsync-dev-mac"
    static let androidInstanceName = "dndsync-dev-android"
    static let senderMac = "mac"
    static let senderAndroid = "android"
    static let protoVersion: UInt32 = 1
    static let echoWindowMs: Int64 = 1000
    static let maxFrameBytes = 64 * 1024
}
