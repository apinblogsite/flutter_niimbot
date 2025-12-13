import Flutter
import CoreBluetooth

public class FlutterNiimbotPlugin: NSObject, FlutterPlugin, CBCentralManagerDelegate, CBPeripheralDelegate, FlutterStreamHandler {
    
    private var centralManager: CBCentralManager?
    private var peripherals: [String: CBPeripheral] = [:] // Map deviceId -> CBPeripheral
    private var activePeripheral: CBPeripheral?
    private var activeCharacteristic: CBCharacteristic?
    
    private var methodChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?
    
    private var scanResult: FlutterResult?
    private var connectResult: FlutterResult?
    
    private var scannedDevices: [[String: String]] = []
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_niimbot", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "flutter_niimbot/events", binaryMessenger: registrar.messenger())
        
        let instance = FlutterNiimbotPlugin()
        instance.methodChannel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }
    
    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scan":
            startScan(result: result)
        case "connect":
            if let args = call.arguments as? [String: Any], let deviceId = args["deviceId"] as? String {
                connect(deviceId: deviceId, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Device ID is required", details: nil))
            }
        case "disconnect":
            disconnect(result: result)
        case "sendPacket":
            if let args = call.arguments as? [String: Any],
               let cmd = args["cmd"] as? Int,
               let payload = args["payload"] as? FlutterStandardTypedData {
                sendPacket(cmd: UInt8(cmd), payload: payload.data, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "cmd and payload required", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startScan(result: @escaping FlutterResult) {
        guard centralManager?.state == .poweredOn else {
            result(FlutterError(code: "BLUETOOTH_OFF", message: "Bluetooth is not enabled", details: nil))
            return
        }
        
        scanResult = result
        scannedDevices.removeAll()
        peripherals.removeAll()
        
        centralManager?.scanForPeripherals(withServices: nil, options: nil)
        
        // Stop scan after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.centralManager?.stopScan()
            if let scanResult = self.scanResult {
                scanResult(self.scannedDevices)
                self.scanResult = nil
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceId = peripheral.identifier.uuidString
        if peripherals[deviceId] == nil {
            peripherals[deviceId] = peripheral
            if let name = peripheral.name {
                 scannedDevices.append(["name": name, "id": deviceId])
            }
        }
    }
    
    private func connect(deviceId: String, result: @escaping FlutterResult) {
        guard let peripheral = peripherals[deviceId] else {
            result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Device not found in scan results", details: nil))
            return
        }
        
        connectResult = result
        activePeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                let props = characteristic.properties
                if props.contains(.notify) && props.contains(.writeWithoutResponse) {
                    activeCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                    
                    if let result = connectResult {
                        result(true)
                        connectResult = nil
                    }
                    return
                }
            }
        }
    }
    
    private func disconnect(result: @escaping FlutterResult) {
        if let peripheral = activePeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
            activePeripheral = nil
            activeCharacteristic = nil
        }
        result(true)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        eventSink?(["type": "disconnected"])
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            eventSink?(["type": "packet", "data": FlutterStandardTypedData(bytes: data)])
        }
    }
    
    private func sendPacket(cmd: UInt8, payload: Data, result: @escaping FlutterResult) {
        guard let peripheral = activePeripheral, let characteristic = activeCharacteristic else {
             result(FlutterError(code: "NOT_CONNECTED", message: "Not connected", details: nil))
             return
        }
        
        let packet = buildPacket(cmd: cmd, payload: payload)
        peripheral.writeValue(packet, for: characteristic, type: .withoutResponse)
        result(nil)
    }
    
    private func buildPacket(cmd: UInt8, payload: Data) -> Data {
        let head: [UInt8] = [0x55, 0x55]
        let tail: [UInt8] = [0xAA, 0xAA]
        
        var checksum: UInt8 = 0
        checksum ^= cmd
        checksum ^= UInt8(payload.count)
        for byte in payload {
            checksum ^= byte
        }
        
        var packet = Data()
        packet.append(contentsOf: head)
        packet.append(cmd)
        packet.append(UInt8(payload.count))
        packet.append(payload)
        packet.append(checksum)
        packet.append(contentsOf: tail)
        
        if cmd == 0xC1 {
            var prefixed = Data([0x03])
            prefixed.append(packet)
            return prefixed
        }
        
        return packet
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
