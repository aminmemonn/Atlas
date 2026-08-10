import Foundation

/// A device capability the agent can be granted access to, one at a time.
///
/// Every capability is opt-in and revocable from Settings. Toggling a capability
/// on triggers the corresponding native permission request; nothing is enabled
/// without explicit user action.
enum DeviceCapability: String, CaseIterable, Identifiable, Codable, Sendable {
    case camera
    case microphone
    case location
    case photos
    case contacts
    case calendar
    case reminders
    case screen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .location: "Location"
        case .photos: "Photos"
        case .contacts: "Contacts"
        case .calendar: "Calendar"
        case .reminders: "Reminders"
        case .screen: "Screen Sharing"
        }
    }

    var symbolName: String {
        switch self {
        case .camera: "camera"
        case .microphone: "mic"
        case .location: "location"
        case .photos: "photo.on.rectangle"
        case .contacts: "person.crop.circle"
        case .calendar: "calendar"
        case .reminders: "checklist"
        case .screen: "rectangle.on.rectangle"
        }
    }

    /// Plain-language explanation of what granting this allows the agent to do.
    var explanation: String {
        switch self {
        case .camera:
            "Lets the agent capture photos or analyze what your camera sees when you ask."
        case .microphone:
            "Enables voice conversations and lets the agent transcribe what you say."
        case .location:
            "Shares your location so the agent can answer location-aware questions."
        case .photos:
            "Allows the agent to read and reference photos you explicitly choose."
        case .contacts:
            "Lets the agent look up people you mention to draft messages or schedule."
        case .calendar:
            "Allows the agent to read events and propose new ones for your approval."
        case .reminders:
            "Lets the agent create and complete reminders on your behalf."
        case .screen:
            "Streams your screen to the gateway only while you are actively sharing."
        }
    }

    /// Whether granting requires a system permission prompt (vs. app-level only).
    var requiresSystemPrompt: Bool {
        switch self {
        case .screen: false
        default: true
        }
    }
}

/// Authorization outcome for a capability, mirrored from the relevant system API.
enum CapabilityAuthorization: String, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var isGranted: Bool { self == .authorized }
}
