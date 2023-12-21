import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FlutterBlue flutterBlue = FlutterBlue.instance;
  BluetoothDevice? selectedDevice;
  BluetoothCharacteristic? writeCharacteristic;

  void _startScanning() {
    flutterBlue.startScan(timeout: Duration(seconds: 4));
  }

  void _stopScanning() {
    flutterBlue.stopScan();
  }

  void _connectToDevice(BluetoothDevice device) async {
    device.connect();
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) {
      service.characteristics.forEach((characteristic) {
        if (characteristic.properties.write) {
          writeCharacteristic = characteristic;
        }
      });
    });
    setState(() {
      selectedDevice = device;
    });
  }

  void _sendCommand(int throttle, int pitch, int roll, int yaw) {
    if (selectedDevice != null && writeCharacteristic != null) {
      List<int> command = [throttle, pitch, roll, yaw];
      writeCharacteristic?.write(command);
    }
  }

  @override
  void initState() {
    super.initState();
    _startScanning();
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Drone Controller'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Select a Bluetooth device:',
            ),
            FutureBuilder<List<ScanResult>>(
              future: flutterBlue.scanResults.first,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('No Bluetooth devices found.');
                } else {
                  return Column(
                    children: snapshot.data!.map((result) {
                      return ListTile(
                        title: Text(result.device.name),
                        subtitle: Text(result.device.id.toString()),
                        onTap: () => _connectToDevice(result.device),
                      );
                    }).toList(),
                  );
                }
              },
            ),
            if (selectedDevice != null)
              Joystick(
                onChange: (double dx, double dy) {
                  // Map joystick input to drone control values
                  int throttle = ((dy + 1) * 1000).toInt();
                  int pitch = (dy * 500).toInt();
                  int roll = (dx * 500).toInt();
                  int yaw = 0; // Implement your own yaw control
                  _sendCommand(throttle, pitch, roll, yaw);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class Joystick extends StatelessWidget {
  final Function(double, double) onChange;

  Joystick({required this.onChange});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        double dx = details.globalPosition.dx / context.size!.width * 2 - 1;
        double dy = details.globalPosition.dy / context.size!.height * 2 - 1;
        onChange(dx, dy);
      },
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.withOpacity(0.5),
        ),
      ),
    );
  }
}
