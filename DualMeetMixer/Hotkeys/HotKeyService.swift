import Carbon.HIToolbox
import Foundation

final class HotKeyService {

    typealias Handler = () -> Void

    private struct Registration {
        let id: UInt32
        let ref: EventHotKeyRef?
        let handler: Handler
    }

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?
    private static let signature: OSType = "DMMx".fourCharCode

    init() {
        installEventHandler()
    }

    deinit {
        for reg in registrations.values {
            if let ref = reg.ref { UnregisterEventHotKey(ref) }
        }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }
    }

    func unregisterAll() {
        for reg in registrations.values {
            if let ref = reg.ref { UnregisterEventHotKey(ref) }
        }
        registrations.removeAll()
        nextID = 1
    }

    @discardableResult
    func register(_ hotKey: HotKey, handler: @escaping Handler) -> Bool {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            hkID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )
        guard status == noErr else {
            print("[HotKeyService] RegisterEventHotKey failed with status \(status)")
            return false
        }
        registrations[id] = Registration(id: id, ref: ref, handler: handler)
        return true
    }

    private func installEventHandler() {
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                          eventKind: UInt32(kEventHotKeyPressed))
        ]
        let userData = Unmanaged.passUnretained(self).toOpaque()

        let handler: EventHandlerUPP = { (_, eventRef, userData) -> OSStatus in
            guard let userData, let eventRef else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()
            var hkID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           OSType(kEventParamDirectObject),
                                           OSType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hkID)
            guard status == noErr,
                  hkID.signature == HotKeyService.signature else {
                return OSStatus(eventNotHandledErr)
            }
            DispatchQueue.main.async {
                service.registrations[hkID.id]?.handler()
            }
            return noErr
        }

        InstallEventHandler(GetEventDispatcherTarget(),
                            handler,
                            1,
                            eventSpec,
                            userData,
                            &eventHandlerRef)
    }
}

private extension String {
    var fourCharCode: OSType {
        var result: OSType = 0
        for char in utf8.prefix(4) {
            result = (result << 8) + OSType(char)
        }
        return result
    }
}
