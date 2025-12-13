class RequestCommandId {
  static const int connect = 0xc1;
  static const int cancelPrint = 0xda;
  static const int calibrateHeight = 0x59;
  static const int heartbeat = 0xdc;
  static const int labelPositioningCalibration = 0x8e;
  static const int pageEnd = 0xe3;
  static const int printerLog = 0x05;
  static const int pageStart = 0x03;
  static const int printBitmapRow = 0x85;
  static const int printBitmapRowIndexed = 0x83;
  static const int printClear = 0x20;
  static const int printEmptyRow = 0x84;
  static const int printEnd = 0xf3;
  static const int printerInfo = 0x40;
  static const int printerConfig = 0xaf;
  static const int printerStatusData = 0xa5;
  static const int printerReset = 0x28;
  static const int printQuantity = 0x15;
  static const int printStart = 0x01;
  static const int printStatus = 0xa3;
  static const int rfidInfo = 0x1a;
  static const int rfidInfo2 = 0x1c;
  static const int rfidSuccessTimes = 0x54;
  static const int setAutoShutdownTime = 0x27;
  static const int setDensity = 0x21;
  static const int setLabelType = 0x23;
  static const int setPageSize = 0x13;
  static const int soundSettings = 0x58;
  static const int antiFake = 0x0b;
  static const int writeRFID = 0x70;
  static const int printTestPage = 0x5a;
  static const int startFirmwareUpgrade = 0xf5;
  static const int firmwareCrc = 0x91;
  static const int firmwareCommit = 0x92;
  static const int firmwareChunk = 0x9b;
  static const int firmwareNoMoreChunks = 0x9c;
  static const int printerCheckLine = 0x86;
  static const int getCurrentTimeFormat = 0x12;
  static const int printerConfig2 = 0x07;
  static const int getKeyFunction = 0x09;
  static const int getPrintQuality = 0x0d;
  static const int getPrinterConfigurationWifi = 0xa2;
}

class ResponseCommandId {
  static const int inConnect = 0xc2;
  // ... other response IDs can be added as needed for parsing
}
