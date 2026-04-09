import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'printer_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<PrinterController>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Niimbot Printer'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Section
              _buildConnectionSection(context, controller),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Input Section
              Text(
                "Label Data",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _keteranganController,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.text_fields),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Print Button
              FilledButton.icon(
                onPressed: controller.isConnected
                    ? () {
                        if (_idController.text.isEmpty ||
                            _keteranganController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Please fill all fields")),
                          );
                          return;
                        }
                        controller.printLabel(
                            _idController.text, _keteranganController.text);
                      }
                    : null,
                icon: const Icon(Icons.print),
                label: const Text("PRINT LABEL"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              const SizedBox(height: 24),
              // Logs
              Container(
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    controller.log,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionSection(
      BuildContext context, PrinterController controller) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        controller.isConnected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        color:
                            controller.isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.isConnected
                              ? "Connected: ${controller.connectedDeviceName}"
                              : "Disconnected",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (controller.isConnected)
                  OutlinedButton(
                    onPressed: controller.disconnect,
                    child: const Text("Disconnect"),
                  )
                else ...[
                  if (kIsWeb)
                    TextButton.icon(
                      icon: const Icon(Icons.usb),
                      onPressed: controller.connectSerial,
                      label: const Text("Serial Web"),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed:
                        controller.isScanning ? null : controller.startScan,
                    child: Text(controller.isScanning ? "Scanning BLE..." : "Scan BLE"),
                  ),
                ],
              ],
            ),
            if (!controller.isConnected &&
                (controller.isScanning || controller.devices.isNotEmpty)) ...[
              const SizedBox(height: 16),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: controller.devices.length,
                  itemBuilder: (context, index) {
                    final d = controller.devices[index];
                    final name = d.platformName.isNotEmpty
                        ? d.platformName
                        : "Unknown Device";
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: Text(d.remoteId.toString()),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => controller.connectBluetooth(d),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
