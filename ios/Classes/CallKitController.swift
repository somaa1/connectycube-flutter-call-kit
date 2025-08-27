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
    var currentCallData: [String: Any] = [:]
    private var callStates: [String:CallState] = [:]
    private var callsData: [String:[String:Any]] = [:]
    
    override init() {
        self.provider = CXProvider(configuration: CallKitController.providerConfiguration)
        self.callController = CXCallController()
        
        super.init()
        self.provider.setDelegate(self, queue: nil)
    }
    
    //TODO: construct configuration from flutter. pass into init over method channel
    static var providerConfiguration: CXProviderConfiguration = {
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as! String
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
        
        let update = CXCallUpdate()
        update.localizedCallerName = callInitiatorName
        update.remoteHandle = CXHandle(type: .generic, value: uuid)
        update.hasVideo = callType == 1
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsHolding = false
        update.supportsDTMF = false
        
        if (self.currentCallData["session_id"] == nil || self.currentCallData["session_id"] as! String != uuid) {
            print("[CallKitController][reportIncomingCall] report new call: \(uuid)")
            
            provider.reportNewIncomingCall(with: UUID(uuidString: uuid)!, update: update) { error in
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
                    self.callStates[uuid] = .pending
                    self.callsData[uuid] = callData
                    
                    // Store in UserDefaults for cross-session persistence
                    UserDefaults.standard.set(callData, forKey: "connectycube_call_\(uuid)")
                    UserDefaults.standard.set(uuid, forKey: "connectycube_last_call_id")
                    UserDefaults.standard.synchronize()
                    
                    print("[CallKitController][reportIncomingCall] Persisted call data for: \(uuid), caller: \(callInitiatorName)")
                    self.actionListener?(.incomingCall, UUID(uuidString: uuid)!, callData)
                }
            }
        } else if (self.currentCallData["session_id"] as! String == uuid) {
            print("[CallKitController][reportIncomingCall] update existing call: \(uuid)")
            
            // Update the caller name in case it changed
            self.currentCallData["caller_name"] = callInitiatorName
            self.callsData[uuid]?["caller_name"] = callInitiatorName
            UserDefaults.standard.set(self.currentCallData, forKey: "connectycube_call_\(uuid)")
            
            provider.reportCall(with: UUID(uuidString: uuid)!, updated: update)
            
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
        
        self.callStates[uuidString] = .rejected
        self.provider.reportCall(with: uuid, endedAt: Date.init(), reason: cxReason)
        
        // Clear call data for the ended call
        self.callsData[uuidString] = nil
        if self.currentCallData["session_id"] as? String == uuidString {
            self.currentCallData.removeAll()
        }
        
        // Clear persisted data
        UserDefaults.standard.removeObject(forKey: "connectycube_call_\(uuidString)")
        UserDefaults.standard.synchronize()
        
        print("[CallKitController][reportCallEnded] Cleared call data for ended call: \(uuidString)")
    }
    
    func getCallState(uuid: String) -> CallState {
        print("[CallKitController][getCallState] uuid: \(uuid), state: \(self.callStates[uuid.lowercased()] ?? .unknown)")
        
        return self.callStates[uuid.lowercased()] ?? .unknown
    }
    
    func setCallState(uuid: String, callState: String){
        self.callStates[uuid.lowercased()] = CallState(rawValue: callState)
    }
    
    func getCallData(uuid: String) -> [String: Any]{
        // First try to get from memory
        let memoryData = self.callsData[uuid.lowercased()] ?? [:]
        if !memoryData.isEmpty {
            return memoryData
        }
        
        // Try to get from UserDefaults
        if let persistedData = UserDefaults.standard.object(forKey: "connectycube_call_\(uuid)") as? [String: Any] {
            print("[CallKitController][getCallData] Retrieved persisted call data for: \(uuid), caller: \(persistedData["caller_name"] ?? "Unknown")")
            return persistedData
        }
        
        return [:]
    }
    
    func clearCallData(uuid: String){
        self.callStates.removeAll()
        self.callsData.removeAll()
        
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
        
        self.callStates[uuid.uuidString.lowercased()] = .rejected
        
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
        let callUUID = uuid == nil ? UUID() : UUID(uuidString: uuid!)
        let startCallAction = CXStartCallAction(call: callUUID!, handle: handle)
        startCallAction.isVideo = videoEnabled
        
        let transaction = CXTransaction(action: startCallAction)
        
        self.callStates[uuid!.lowercased()] = .accepted
        
        requestTransaction(transaction);
    }
    
    func answerCall(uuid: String) {
        print("[CallKitController][answerCall] uuid: \(uuid)")
        
        let callUUID = UUID(uuidString: uuid)
        let answerCallAction = CXAnswerCallAction(call: callUUID!)
        let transaction = CXTransaction(action: answerCallAction)
        
        self.callStates[uuid.lowercased()] = .accepted
        
        requestTransaction(transaction);
    }
}

//MARK: System notifications
extension CallKitController: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("[CallKitController][CXAnswerCallAction] callUUID: \(action.callUUID.uuidString.lowercased())")
        
        configureAudioSession(active: true)
        callStates[action.callUUID.uuidString.lowercased()] = .accepted
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
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("[CallKitController][CXEndCallAction]")
        
        actionListener?(.endCall, action.callUUID, currentCallData)
        callStates[action.callUUID.uuidString.lowercased()] = .rejected
        
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
        callStates[action.callUUID.uuidString.lowercased()] = .accepted
        configureAudioSession(active: true)
        
        action.fulfill()
    }
}
