import Foundation
import UniversalControlCore

enum ComputerRole: String {
    case source
    case target
}

final class Preferences {
    private enum Key {
        static let role = "computerRole"
        static let pairingCode = "pairingCode"
        static let relayActive = "relayActive"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.string(forKey: Key.role) == nil {
            defaults.set(ComputerRole.source.rawValue, forKey: Key.role)
        }
        if let code = defaults.string(forKey: Key.pairingCode), PairingCode.isValid(code) {
            return
        }
        defaults.set(PairingCode.generate(), forKey: Key.pairingCode)
    }

    var role: ComputerRole {
        get { ComputerRole(rawValue: defaults.string(forKey: Key.role) ?? "") ?? .source }
        set { defaults.set(newValue.rawValue, forKey: Key.role) }
    }

    var pairingCode: String {
        get { defaults.string(forKey: Key.pairingCode) ?? "000000" }
        set {
            precondition(PairingCode.isValid(newValue))
            defaults.set(newValue, forKey: Key.pairingCode)
        }
    }

    var relayActive: Bool {
        get { defaults.bool(forKey: Key.relayActive) }
        set { defaults.set(newValue, forKey: Key.relayActive) }
    }
}
