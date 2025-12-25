//
//  CallKitController.swift
//  connectycube_flutter_call_kit
//
//  Created by Tereha on 19.11.2021.
//

import Foundation
import AVFoundation
import CallKit

enum CallEvent : String {
    case incomingCall = "incomingCall"
    case answerCall = "answerCall"
    case endCall = "endCall"
    case setHeld = "setHeld"
    case reset = "reset"
    case startCall = "startCall"
    case setMuted = "setMuted"
    case setUnMuted = "setUnMuted"
}

enum CallEndedReason : String {
    case failed = "failed"
    case unanswered = "unanswered"
    case remoteEnded = "remoteEnded"
}

enum CallState : String {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case unknown = "unknown"
}

class CallKitController : NSObject {
    private let provider : CXProvider
    private let callController : CXCallController
    var actionListener : ((CallEvent, UUID, [String:Any]?)->Void)?

    // Thread-safe access to call data using serial queue
    private let callDataQueue = DispatchQueue(label: "com.connectycube.callkit.calldata")
    private var _currentCallData: [String: Any] = [:]
    private var _callStates: [String:CallState] = [:]
    private var _callsData: [String:[String:Any]] = [:]

    var currentCallData: [String: Any] {
        get { callDataQueue.sync { _currentCallData } }
        set { callDataQueue.async(flags: .barrier) { self._currentCallData = newValue } }
    }

    // Thread-safe methods for call states
    func getCallState(uuid: String) -> CallState {
        return callDataQueue.sync {
            _callStates[uuid.lowercased()] ?? .unknown
        }
    }

    func setCallState(uuid: String, state: CallState) {
        callDataQueue.async(flags: .barrier) {
            self._callStates[uuid.lowercased()] = state
        }
    }

    func removeCallState(uuid: String) {
        callDataQueue.async(flags: .barrier) {
            self._callStates.removeValue(forKey: uuid.lowercased())
        }
    }

    // Thread-safe methods for call data
    func getCallData(uuid: String) -> [String:Any] {
        // First try to get from memory (thread-safe)
        let memoryData = callDataQueue.sync {
            _callsData[uuid.lowercased()] ?? [:]
        }

        if !memoryData.isEmpty {
            return memoryData
        }

        // Try to get from UserDefaults as fallback
        if let persistedData = UserDefaults.standard.object(forKey: "connectycube_call_\(uuid)") as? [String: Any] {
            print("[CallKitController][getCallData] Retrieved persisted call data for: \(uuid), caller: \(persistedData["caller_name"] ?? "Unknown")")
            return persistedData
        }

        return [:]
    }

    func setCallData(uuid: String, data: [String:Any]) {
        callDataQueue.async(flags: .barrier) {
            self._callsData[uuid.lowercased()] = data
        }
    }

    func removeCallData(uuid: String) {
        callDataQueue.async(flags: .barrier) {
            self._callsData.removeValue(forKey: uuid.lowercased())
        }
    }

    func removeAllCallData() {
        callDataQueue.async(flags: .barrier) {
            self._callsData.removeAll()
        }
    }

    override init() {
        self.provider = CXProvider(configuration: CallKitController.providerConfiguration)
        self.callController = CXCallController()

        super.init()
        self.provider.setDelegate(self, queue: nil)
    }
    
    //TODO: construct configuration from flutter. pass into init over method channel
    static var providerConfiguration: CXProviderConfiguration = {
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "Call"
        var providerConfiguration: CXProviderConfiguration
        if #available(iOS 14.0, *) {
            providerConfiguration = CXProviderConfiguration.init()
        } else {
            providerConfiguration = CXProviderConfiguration(localizedName: appName)
        }
        
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1;
        providerConfiguration.supportedHandleTypes = [.generic]
        
        if #available(iOS 11.0, *) {
            providerConfiguration.includesCallsInRecents = false
        }
        
        return providerConfiguration
    }()
    
    static func updateConfig(
        ringtone: String?,
        icon: String?
        
    ) {
        if(ringtone != nil){
            providerConfiguration.ringtoneSound = ringtone
        }
        
        if(icon != nil){
            let iconImage = UIImage(named: icon!)
            let iconData = iconImage?.pngData()
            
            providerConfiguration.iconTemplateImageData = iconData
        }
    }
    
    @objc func reportIncomingCall(
        uuid: String,
        callType: Int,
        callInitiatorId: Int,
        callInitiatorName: String,
        opponents: [Int],
        userInfo: String?,
        completion: ((Error?) -> Void)?
    ) {
        print("[CallKitController][reportIncomingCall] call data: \(uuid), \(callType), \(callInitiatorId), \(callInitiatorName), \(opponents), \(userInfo ?? "nil")")

        // Validate UUID string
        guard let callUUID = UUID(uuidString: uuid) else {
            print("[CallKitController][reportIncomingCall] Invalid UUID string: \(uuid)")
            completion?(NSError(domain: "CallKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid UUID string"]))
            return
        }

        let update = CXCallUpdate()
        update.localizedCallerName = callInitiatorName
        update.remoteHandle = CXHandle(type: .generic, value: uuid)
        update.hasVideo = callType == 1
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false

        let currentSessionId = self.currentCallData["session_id"] as? String
        if (currentSessionId == nil || currentSessionId != uuid) {
            print("[CallKitController][reportIncomingCall] report new call: \(uuid)")

            provider.reportNewIncomingCall(with: callUUID, update: update) { error in
                completion?(error)
                
                if(error == nil){
                    self.configureAudioSession(active: true)
                    
                    // Ensure comprehensive call data storage for persistence
                    let callData: [String: Any] = [
                        "session_id": uuid,
                        "call_type": callType,
                        "caller_id": callInitiatorId,
                        "caller_name": callInitiatorName,
                        "call_opponents": opponents.map { String($0) }.joined(separator: ","),
                        "user_info": userInfo ?? ""
                    ]
                    
                    self.currentCallData = callData
                    self.setCallState(uuid: uuid, state: .pending)
                    self.setCallData(uuid: uuid, data: callData)
                    
                    // Store in UserDefaults for cross-session persistence
                    UserDefaults.standard.set(callData, forKey: "connectycube_call_\(uuid)")
                    UserDefaults.standard.set(uuid, forKey: "connectycube_last_call_id")
                    UserDefaults.standard.synchronize()
                    
                    print("[CallKitController][reportIncomingCall] Persisted call data for: \(uuid), caller: \(callInitiatorName)")
                    self.actionListener?(.incomingCall, callUUID, callData)
                }
            }
        } else if (currentSessionId == uuid) {
            print("[CallKitController][reportIncomingCall] update existing call: \(uuid)")

            // Update the caller name in case it changed (thread-safe)
            self.currentCallData["caller_name"] = callInitiatorName
            var existingCallData = self.getCallData(uuid: uuid)
            existingCallData["caller_name"] = callInitiatorName
            self.setCallData(uuid: uuid, data: existingCallData)
            UserDefaults.standard.set(self.currentCallData, forKey: "connectycube_call_\(uuid)")

            provider.reportCall(with: callUUID, updated: update)

            completion?(nil)
        }
    }
    
    func reportOutgoingCall(uuid : UUID, finishedConnecting: Bool){
        print("[CallKitController][reportOutgoingCall] uuid: \(uuid.uuidString.lowercased()) connected: \(finishedConnecting)")
        
        if !finishedConnecting {
            self.provider.reportOutgoingCall(with: uuid, startedConnectingAt: nil)
        } else {
            self.provider.reportOutgoingCall(with: uuid, connectedAt: nil)
        }
    }
    
    func reportCallEnded(uuid : UUID, reason: CallEndedReason){
        let uuidString = uuid.uuidString.lowercased()
        print("[CallKitController][reportCallEnded] uuid: \(uuidString), reason: \(reason)")
        
        var cxReason : CXCallEndedReason
        switch reason {
        case .unanswered:
            cxReason = CXCallEndedReason.unanswered
        case .remoteEnded:
            cxReason = CXCallEndedReason.remoteEnded
        default:
            cxReason = CXCallEndedReason.failed
        }
        
        self.setCallState(uuid: uuidString, state: .rejected)
        self.provider.reportCall(with: uuid, endedAt: Date.init(), reason: cxReason)

        // Cleanup audio session when call ends
        configureAudioSession(active: false)

        // Clear call data for the ended call
        self.removeCallData(uuid: uuidString)
        if self.currentCallData["session_id"] as? String == uuidString {
            self.currentCallData = [:]
        }
        
        // Clear persisted data
        UserDefaults.standard.removeObject(forKey: "connectycube_call_\(uuidString)")
        UserDefaults.standard.synchronize()
        
        print("[CallKitController][reportCallEnded] Cleared call data for ended call: \(uuidString)")
    }
    
    // Thread-safe getCallState, setCallState, and getCallData methods are defined above (lines 53-89)

    func clearCallData(uuid: String){
        // Remove call state (thread-safe)
        self.removeCallState(uuid: uuid)

        // Remove all call data (thread-safe)
        self.removeAllCallData()
        
        // Clear persisted data
        UserDefaults.standard.removeObject(forKey: "connectycube_call_\(uuid)")
        UserDefaults.standard.removeObject(forKey: "connectycube_last_call_id")
        UserDefaults.standard.synchronize()
        
        print("[CallKitController][clearCallData] Cleared all call data for: \(uuid)")
    }
    
    func sendAudioInterruptionNotification(){
        print("[CallKitController][sendAudioInterruptionNotification]")
        var userInfo : [AnyHashable : Any] = [:]
        let intrepEndeRaw = AVAudioSession.InterruptionType.ended.rawValue
        userInfo[AVAudioSessionInterruptionTypeKey] = intrepEndeRaw
        userInfo[AVAudioSessionInterruptionOptionKey] = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: self, userInfo: userInfo)
    }
    
    func configureAudioSession(active: Bool){
        print("[CallKitController][configureAudioSession] active: \(active)")
        
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(
                AVAudioSession.Category.playAndRecord,
                options: [
                    .allowBluetooth,
                    .allowBluetoothA2DP,
                ])
            try audioSession.setMode(AVAudioSession.Mode.videoChat)
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.005)
            try audioSession.setActive(active)
        } catch {
            print(error)
        }
    }
}

//MARK: user actions
extension CallKitController {
    
    func end(uuid: UUID) {
        print("[CallKitController][end] uuid: \(uuid.uuidString.lowercased())")
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        self.setCallState(uuid: uuid.uuidString.lowercased(), state: .rejected)

        requestTransaction(transaction)
    }
    
    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                print("[CallKitController][requestTransaction] Error: \(error.localizedDescription)")
            } else {
                print("[CallKitController][requestTransaction] successfully")
            }
        }
    }
    
    func setHeld(uuid: UUID, onHold: Bool) {
        print("[CallKitController][setHeld] uuid: \(uuid.uuidString.lowercased()), onHold: \(onHold)")
        
        let setHeldCallAction = CXSetHeldCallAction(call: uuid, onHold: onHold)
        
        let transaction = CXTransaction()
        transaction.addAction(setHeldCallAction)
        
        requestTransaction(transaction)
    }
    
    func setMute(uuid: UUID, muted: Bool){
        print("[CallKitController][setMute] uuid: \(uuid.uuidString.lowercased()), muted: \(muted)")
        
        let muteCallAction = CXSetMutedCallAction(call: uuid, muted: muted);
        let transaction = CXTransaction()
        transaction.addAction(muteCallAction)
        
        requestTransaction(transaction)
    }
    
    func startCall(handle: String, videoEnabled: Bool, uuid: String? = nil) {
        print("[CallKitController][startCall] handle:\(handle), videoEnabled: \(videoEnabled) uuid: \(uuid ?? "nil")")

        let handle = CXHandle(type: .generic, value: handle)

        // Generate or validate UUID
        let callUUID: UUID
        if let uuidString = uuid, let parsedUUID = UUID(uuidString: uuidString) {
            callUUID = parsedUUID
        } else {
            callUUID = UUID()
            print("[CallKitController][startCall] Generated new UUID: \(callUUID.uuidString)")
        }

        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
        startCallAction.isVideo = videoEnabled

        let transaction = CXTransaction(action: startCallAction)

        self.setCallState(uuid: callUUID.uuidString.lowercased(), state: .accepted)

        requestTransaction(transaction)
    }
    
    func answerCall(uuid: String) {
        print("[CallKitController][answerCall] uuid: \(uuid)")

        guard let callUUID = UUID(uuidString: uuid) else {
            print("[CallKitController][answerCall] Invalid UUID string: \(uuid)")
            return
        }

        let answerCallAction = CXAnswerCallAction(call: callUUID)
        let transaction = CXTransaction(action: answerCallAction)

        self.setCallState(uuid: uuid.lowercased(), state: .accepted)

        requestTransaction(transaction)
    }
}

//MARK: System notifications
extension CallKitController: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallKitController][CXAnswerCallAction] callUUID: \(action.callUUID.uuidString.lowercased())")

        configureAudioSession(active: true)
        setCallState(uuid: action.callUUID.uuidString.lowercased(), state: .accepted)
        actionListener?(.answerCall, action.callUUID, self.currentCallData)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("[CallKitController] Audio session activated")
        
        sendAudioInterruptionNotification()
        configureAudioSession(active: true)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("[CallKitController] Audio session deactivated")

        // Properly deactivate audio session to prevent audio routing issues
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("[CallKitController] Audio session deactivated successfully")
        } catch {
            print("[CallKitController] Failed to deactivate audio session: \(error)")
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallKitController][CXEndCallAction]")

        actionListener?(.endCall, action.callUUID, currentCallData)
        setCallState(uuid: action.callUUID.uuidString.lowercased(), state: .rejected)

        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("[CallKitController][CXSetHeldCallAction] callUUID: \(action.callUUID.uuidString.lowercased())")
        
        actionListener?(.setHeld, action.callUUID, ["isOnHold": action.isOnHold])
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("[CallKitController][CXSetMutedCallAction] callUUID: \(action.callUUID.uuidString.lowercased())")
        
        if (action.isMuted){
            actionListener?(.setMuted, action.callUUID, currentCallData)
        } else {
            actionListener?(.setUnMuted, action.callUUID, currentCallData)
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("[CallKitController][CXStartCallAction]: callUUID: \(action.callUUID.uuidString.lowercased())")

        actionListener?(.startCall, action.callUUID, currentCallData)
        setCallState(uuid: action.callUUID.uuidString.lowercased(), state: .accepted)
        configureAudioSession(active: true)

        action.fulfill()
    }
}
