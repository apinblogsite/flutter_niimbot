import Flutter
import UIKit

public class FlutterNiimbotPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_niimbot", binaryMessenger: registrar.messenger())
    let instance = FlutterNiimbotPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "buildPacket":
        if let args = call.arguments as? [String: Any],
           let cmd = args["cmd"] as? Int,
           let payload = args["payload"] as? FlutterStandardTypedData {
            let packet = buildPacket(cmd: UInt8(cmd), payload: payload.data)
            result(FlutterStandardTypedData(bytes: packet))
        } else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "cmd and payload required", details: nil))
        }
    case "parsePacket":
        if let args = call.arguments as? [String: Any],
           let data = args["data"] as? FlutterStandardTypedData {
            do {
                let parsed = try parsePacket(data: data.data)
                result(parsed)
            } catch {
                result(FlutterError(code: "PARSE_ERROR", message: "\(error)", details: nil))
            }
        } else {
            result(FlutterError(code: "INVALID_ARGUMENT", message: "data required", details: nil))
        }
    default:
        result(FlutterMethodNotImplemented)
    }
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
      
      // Special case: Connect 0xC1 (193) -> prefix 0x03
      if cmd == 0xC1 {
          var prefixed = Data([0x03])
          prefixed.append(packet)
          return prefixed
      }
      
      return packet
  }
  
  private func parsePacket(data: Data) throws -> [String: Any] {
      if data.count < 7 { throw NSError(domain: "Niimbot", code: 1, userInfo: [NSLocalizedDescriptionKey: "Packet too short"]) }
      
      let bytes = [UInt8](data)
      
      if bytes[0] != 0x55 || bytes[1] != 0x55 {
          throw NSError(domain: "Niimbot", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid Header"])
      }
      
      if bytes[bytes.count - 2] != 0xAA || bytes[bytes.count - 1] != 0xAA {
           throw NSError(domain: "Niimbot", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid Tail"])
      }
      
      let cmd = bytes[2]
      let len = bytes[3]
      
      if data.count != 7 + Int(len) {
          throw NSError(domain: "Niimbot", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid Length field"])
      }
      
      let payload = data.subdata(in: 4..<(4 + Int(len)))
      let receivedChecksum = bytes[4 + Int(len)]
      
      var checksum: UInt8 = 0
      checksum ^= cmd
      checksum ^= len
      for byte in payload {
          checksum ^= byte
      }
      
      if checksum != receivedChecksum {
          throw NSError(domain: "Niimbot", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid Checksum"])
      }
      
      return [
          "cmd": Int(cmd),
          "payload": FlutterStandardTypedData(bytes: payload)
      ]
  }
}
