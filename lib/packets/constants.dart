class NiimbotConstants {
  // UUIDs
  // Note: These might vary, but standard Niimbot service is often 0000fee7... or e781...
  // Since we use dynamic discovery, we don't strictly enforce these, but good to have reference.
  static const String SERVICE_UUID_SHORT = "fee7";
  
  // Protocol Bytes
  static const int HEAD_1 = 0x55;
  static const int HEAD_2 = 0x55;
  static const int TAIL_1 = 0xAA;
  static const int TAIL_2 = 0xAA;
  static const int CONNECT_PREFIX = 0x03;

  // Packet Offsets
  static const int OFFSET_CMD = 2;
  static const int OFFSET_LEN = 3;
  static const int OFFSET_DATA = 4;
}
