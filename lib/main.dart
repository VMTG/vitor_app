// ******************************************************************************
// * IMPORTS SECTION
// ******************************************************************************
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemNavigator.pop()
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart'; // For resetting the app

// ******************************************************************************
// * MAIN APPLICATION ENTRY POINT
// ******************************************************************************
void main() {
  runApp(
    Phoenix(
      child: const SensorApp(),
    ),
  );
}

// ******************************************************************************
// * ROOT APPLICATION WIDGET
// * Sets up the MaterialApp and theme
// ******************************************************************************
class SensorApp extends StatelessWidget {
  const SensorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sensor Data',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StartPage(), // Use the home page as home
    );
  }
}

// ******************************************************************************
// * OPERATION MODE ENUM
// * Defines the operating modes available in the application
// ******************************************************************************
enum OperationMode {
  continuous,
  impact,
}

// ******************************************************************************
// * NEW HOME PAGE WITH MODE BUTTONS
// ******************************************************************************
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor App'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo ou ícone
            const Icon(
              Icons.sensors,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),

            // Application title
            const Text(
              'Sensor Data Visualizer',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),

            // Application description
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'View real-time sensor data through interactive graphs',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 50),

            // Operation modes section
            const Text(
              'Select operating mode:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Continuous mode button
            ElevatedButton(
              onPressed: () {
                // Navigate to the sensors screen in continuous mode
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(
                      mode: OperationMode.continuous,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(240, 50),
              ),
              child: const Text(
                'Continuous Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Impact mode button
            ElevatedButton(
              onPressed: () {
                // Navigate to the sensors screen in impact mode
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => DeviceScreen(
                      mode: OperationMode.impact,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                minimumSize: const Size(240, 50),
                backgroundColor: Colors.orange,
              ),
              child: const Text(
                'Impact Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),

            // Application version
            const SizedBox(height: 40),
            const Text(
              'Versão 1.0.0',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ******************************************************************************
// * MAIN DEVICE SCREEN
// * Handles Bluetooth connectivity and primary sensor data display
// ******************************************************************************
class DeviceScreen extends StatefulWidget {
  final OperationMode mode;

  const DeviceScreen({
    super.key,
    required this.mode,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  // ----------------------
  // Bluetooth device list
  // ----------------------
  final List<BluetoothDevice> _devices = [];

  // ----------------------
  // Basic sensor data storage
  // ----------------------
  final List<SensorData> _temperatureData = [];
  final List<SensorData> _pressureData = [];
  final List<SensorData> _accelTotalData = [];
  final List<SensorData> _gyroTotalData = [];

  // ----------------------
  // Individual axis sensor data storage
  // ----------------------
  final List<SensorData> _accelXData = [];
  final List<SensorData> _accelYData = [];
  final List<SensorData> _accelZData = [];
  final List<SensorData> _gyroXData = [];
  final List<SensorData> _gyroYData = [];
  final List<SensorData> _gyroZData = [];

  // ----------------------
  // Configuration parameters
  // ----------------------
  final double _impactThreshold = 5.0; // Threshold for impact detection (in g)

  // ----------------------
  // Impact detection variables
  // ----------------------
  bool _impactDetected = false;
  DateTime? _lastImpactTime;

  // ----------------------
  // Bluetooth connection variables
  // ----------------------
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<List<int>>? _valueSubscription;
  bool _isConnected = false;

  // ******************************************************************************
  // * LIFECYCLE METHODS
  // ******************************************************************************
  @override
  void initState() {
    super.initState();
    _startScan(); // Start scanning for Bluetooth devices on initialization
  }

  @override
  void dispose() {
    _valueSubscription
        ?.cancel(); // Clean up Bluetooth subscriptions when widget is disposed
    super.dispose();
  }

  // ******************************************************************************
  // * BLUETOOTH CONNECTION METHODS
  // ******************************************************************************

  // Start scanning for Bluetooth devices
  void _startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.name == "ESP32_GY91") {
          _connectToDevice(result.device);
          break;
        }
      }
    });
  }

  // Connect to a specific Bluetooth device and set up service/characteristic
  void _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();

      setState(() {
        _isConnected = true;
      });

      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString() ==
                "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
              _characteristic = characteristic;
              await characteristic.setNotifyValue(true);
              _valueSubscription = characteristic.value.listen((value) {
                _processData(ascii.decode(value));
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error connecting to device: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao conectar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ******************************************************************************
  // * DATA PROCESSING METHODS
  // ******************************************************************************

  // Process incoming sensor data from the Bluetooth device
  void _processData(String data) {
    try {
      // Expected data format:
      // T:<temp>, P:<pressure>, A:<ax>,<ay>,<az>, At:<total_acceleration>,
      // G:<gx>,<gy>,<gz>, Gt:<total_rotation>
      final RegExp regExp = RegExp(
        r'T:([\d.]+), P:([\d.]+), A:([\d.-]+),([\d.-]+),([\d.-]+), At:([\d.]+), G:([\d.-]+),([\d.-]+),([\d.-]+), Gt:([\d.]+)',
      );
      final Match? match = regExp.firstMatch(data);

      if (match != null) {
        final DateTime now = DateTime.now();
        final double temp = double.parse(match.group(1)!);
        final double pressure = double.parse(match.group(2)!);
        final double ax = double.parse(match.group(3)!);
        final double ay = double.parse(match.group(4)!);
        final double az = double.parse(match.group(5)!);
        // Compute total acceleration using the formula √(ax²+ay²+az²)
        final double computedAccelTotal = sqrt(ax * ax + ay * ay + az * az);

        final double gx = double.parse(match.group(7)!);
        final double gy = double.parse(match.group(8)!);
        final double gz = double.parse(match.group(9)!);
        // Compute total rotation using the formula √(gx²+gy²+gz²)
        final double computedGyroTotal = sqrt(gx * gx + gy * gy + gz * gz);

        // IMPORTANT: Always process data in continuous mode
        if (widget.mode == OperationMode.continuous) {
          // Always update data in continuous mode
          if (mounted) {
            setState(() {
              if (computedAccelTotal >= _impactThreshold) {
                _impactDetected = true;
                _lastImpactTime = now;
              }

              _updateSensorData(now, temp, pressure, ax, ay, az,
                  computedAccelTotal, gx, gy, gz, computedGyroTotal);
            });
          }
        }
        // For impact mode, use the original logic
        else if (widget.mode == OperationMode.impact) {
          bool shouldUpdateData = false;

          if (computedAccelTotal >= _impactThreshold) {
            _impactDetected = true;
            _lastImpactTime = now;
            shouldUpdateData = true;

            // Clear previous data on new impact
            if (mounted) {
              setState(() {
                _clearSensorData();
              });
            }
          } else if (_impactDetected && _lastImpactTime != null) {
            // Keep recording for 5 seconds after impact
            final Duration timeSinceImpact = now.difference(_lastImpactTime!);
            if (timeSinceImpact.inSeconds <= 5) {
              shouldUpdateData = true;
            } else {
              _impactDetected = false;
            }
          }

          if (shouldUpdateData && mounted) {
            setState(() {
              _updateSensorData(now, temp, pressure, ax, ay, az,
                  computedAccelTotal, gx, gy, gz, computedGyroTotal);
            });
          }
        }
      }
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

// Add a separate method for updating sensor data to avoid code duplication
  void _updateSensorData(
      DateTime now,
      double temp,
      double pressure,
      double ax,
      double ay,
      double az,
      double computedAccelTotal,
      double gx,
      double gy,
      double gz,
      double computedGyroTotal) {
    // Update basic sensor data lists
    _temperatureData.add(SensorData(now, temp));
    _pressureData.add(SensorData(now, pressure));
    _accelTotalData.add(SensorData(now, computedAccelTotal));
    _gyroTotalData.add(SensorData(now, computedGyroTotal));

    // Update individual axis data lists
    _accelXData.add(SensorData(now, ax));
    _accelYData.add(SensorData(now, ay));
    _accelZData.add(SensorData(now, az));
    _gyroXData.add(SensorData(now, gx));
    _gyroYData.add(SensorData(now, gy));
    _gyroZData.add(SensorData(now, gz));

    // Keep data lists at a manageable size (50 points maximum)
    if (_temperatureData.length > 50) _temperatureData.removeAt(0);
    if (_pressureData.length > 50) _pressureData.removeAt(0);
    if (_accelTotalData.length > 50) _accelTotalData.removeAt(0);
    if (_gyroTotalData.length > 50) _gyroTotalData.removeAt(0);
    if (_accelXData.length > 50) _accelXData.removeAt(0);
    if (_accelYData.length > 50) _accelYData.removeAt(0);
    if (_accelZData.length > 50) _accelZData.removeAt(0);
    if (_gyroXData.length > 50) _gyroXData.removeAt(0);
    if (_gyroYData.length > 50) _gyroYData.removeAt(0);
    if (_gyroZData.length > 50) _gyroZData.removeAt(0);
  }

  // Clear all sensor data
  void _clearSensorData() {
    _temperatureData.clear();
    _pressureData.clear();
    _accelTotalData.clear();
    _gyroTotalData.clear();
    _accelXData.clear();
    _accelYData.clear();
    _accelZData.clear();
    _gyroXData.clear();
    _gyroYData.clear();
    _gyroZData.clear();
  }

  // ******************************************************************************
  // * UI BUILDING METHODS
  // ******************************************************************************

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == OperationMode.continuous
            ? 'Continuous Mode'
            : 'Impact Mode'),
        actions: [
          // Current mode indicator
          Chip(
            backgroundColor: widget.mode == OperationMode.continuous
                ? Colors.blue
                : Colors.orange,
            label: Text(
              widget.mode == OperationMode.continuous ? 'Continuous' : 'Impact',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 8),

          // Reset app button using flutter_phoenix
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset App',
            onPressed: () {
              Phoenix.rebirth(context);
            },
          ),

          // Navigate to detailed graphs page
          IconButton(
            icon: const Icon(Icons.graphic_eq),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailedGraphsPage(
                    mode: widget.mode,
                    impactThreshold: _impactThreshold,
                    accelXData: _accelXData,
                    accelYData: _accelYData,
                    accelZData: _accelZData,
                    accelTotalData: _accelTotalData,
                    gyroXData: _gyroXData,
                    gyroYData: _gyroYData,
                    gyroZData: _gyroZData,
                    gyroTotalData: _gyroTotalData,
                  ),
                ),
              );
            },
            tooltip: 'View Detailed Graphs',
          ),

          // Close app button
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Close App',
            onPressed: () {
              SystemNavigator.pop();
            },
          ),
        ],
      ),
      body: _isConnected ? _buildConnectedView() : _buildConnectingView(),
    );
  }

  // View when connecting to device
  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Conectando ao dispositivo ESP32_GY91...',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              _startScan();
            },
            child: const Text('Tentar novamente'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const StartPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }

  // View when connected to device
  Widget _buildConnectedView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Mode info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: widget.mode == OperationMode.continuous
                ? Colors.blue.shade100
                : Colors.orange.shade100,
            child: Row(
              children: [
                Icon(
                  widget.mode == OperationMode.continuous
                      ? Icons.play_circle_outline
                      : Icons.flash_on,
                  color: widget.mode == OperationMode.continuous
                      ? Colors.blue
                      : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.mode == OperationMode.continuous
                        ? 'Data is displayed continuously'
                        : 'Data is only displayed when an impact is detected (Threshold: $_impactThreshold g)',
                    style: TextStyle(
                      color: widget.mode == OperationMode.continuous
                          ? Colors.blue.shade800
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
                if (widget.mode == OperationMode.impact && _impactDetected)
                  const Chip(
                    backgroundColor: Colors.red,
                    label: Text(
                      'IMPACT!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Charts
          _buildChart('Temperature (°C)', _temperatureData),
          _buildChart('Pressure (hPa)', _pressureData),
          _buildChart(
            'Acceleration Total (g)',
            _accelTotalData,
            additionalAnnotation: _buildThresholdAnnotation(_impactThreshold),
          ),
          _buildChart('Gyro Total (dps)', _gyroTotalData),

          // Change mode button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const StartPage(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: const Text(
                'Change Mode',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build a simple chart widget
  Widget _buildChart(String title, List<SensorData> data,
      {CartesianChartAnnotation? additionalAnnotation}) {
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        annotations: additionalAnnotation != null
            ? <CartesianChartAnnotation>[additionalAnnotation]
            : null,
        series: <LineSeries<SensorData, DateTime>>[
          LineSeries<SensorData, DateTime>(
            dataSource: data,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
        ],
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
      ),
    );
  }

  // Create a threshold annotation for impact detection visualization
  CartesianChartAnnotation _buildThresholdAnnotation(double threshold) {
    return CartesianChartAnnotation(
      widget: Container(
        child: Text(
          'Threshold: $threshold',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      coordinateUnit: CoordinateUnit.point,
      x: DateTime.now(), // Places the annotation at the current time.
      y: threshold,
    );
  }
}

// ******************************************************************************
// * DETAILED GRAPHS PAGE
// * Shows extended visualization of sensor data with multiple chart types
// ******************************************************************************
class DetailedGraphsPage extends StatelessWidget {
  // ----------------------
  // Operation mode
  // ----------------------
  final OperationMode mode;
  final double impactThreshold;

  // ----------------------
  // Data lists passed from main screen
  // ----------------------
  final List<SensorData> accelXData;
  final List<SensorData> accelYData;
  final List<SensorData> accelZData;
  final List<SensorData> accelTotalData;
  final List<SensorData> gyroXData;
  final List<SensorData> gyroYData;
  final List<SensorData> gyroZData;
  final List<SensorData> gyroTotalData;

  const DetailedGraphsPage({
    super.key,
    required this.mode,
    required this.impactThreshold,
    required this.accelXData,
    required this.accelYData,
    required this.accelZData,
    required this.accelTotalData,
    required this.gyroXData,
    required this.gyroYData,
    required this.gyroZData,
    required this.gyroTotalData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Gráficos Detalhados - ${mode == OperationMode.continuous ? 'Continuous Mode' : 'Impact Mode'}'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Mode info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: mode == OperationMode.continuous
                    ? Colors.blue.shade100
                    : Colors.orange.shade100,
                child: Row(
                  children: [
                    Icon(
                      mode == OperationMode.continuous
                          ? Icons.play_circle_outline
                          : Icons.flash_on,
                      color: mode == OperationMode.continuous
                          ? Colors.blue
                          : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mode == OperationMode.continuous
                            ? 'Continuous Mode: Data is displayed continuously'
                            : 'Impact Mode: Data is only displayed when an impact is detected (Threshold: $impactThreshold g)',
                        style: TextStyle(
                          color: mode == OperationMode.continuous
                              ? Colors.blue.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ----------------------
              // Accelerometer Data Section
              // ----------------------
              const Text('Accelerometer Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart('Ax vs. Time', accelXData),
              _buildChart('Ay vs. Time', accelYData),
              _buildChart('Az vs. Time', accelZData),
              _buildChart('Total Acceleration vs. Time', accelTotalData,
                  additionalAnnotation:
                      _buildThresholdAnnotation(impactThreshold)),
              const SizedBox(height: 20),

              // ----------------------
              // Gyroscope Data Section
              // ----------------------
              const Text('Gyroscope Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart('Gx vs. Time', gyroXData),
              _buildChart('Gy vs. Time', gyroYData),
              _buildChart('Gz vs. Time', gyroZData),
              _buildChart('Total Rotation vs. Time', gyroTotalData),
              const SizedBox(height: 20),

              // ----------------------
              // Combined Graphs Section
              // ----------------------
              const Text('Combined Graphs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildCombinedChart('Total Acceleration & Rotation',
                  accelTotalData, gyroTotalData),
              _buildMultiSeriesChart('X, Y, Z Accelerations',
                  [accelXData, accelYData, accelZData], ['Ax', 'Ay', 'Az']),
              _buildMultiSeriesChart('X, Y, Z Rotations',
                  [gyroXData, gyroYData, gyroZData], ['Gx', 'Gy', 'Gz']),

              // ----------------------
              // Impact Detection Section
              // ----------------------
              const Text('Impact Detection (Acceleration Threshold)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              _buildChart(
                  'Acceleration vs. Time (Threshold Marked)', accelTotalData,
                  additionalAnnotation:
                      _buildThresholdAnnotation(impactThreshold)),
            ],
          ),
        ),
      ),
    );
  }

  // ******************************************************************************
  // * CHART BUILDING HELPER METHODS
  // ******************************************************************************

  // Build a basic single-series chart
  Widget _buildChart(String title, List<SensorData> data,
      {CartesianChartAnnotation? additionalAnnotation}) {
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        annotations: additionalAnnotation != null
            ? <CartesianChartAnnotation>[additionalAnnotation]
            : null,
        series: <LineSeries<SensorData, DateTime>>[
          LineSeries<SensorData, DateTime>(
            dataSource: data,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
        ],
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
      ),
    );
  }

  // Build a chart with two data series (for comparing two metrics)
  Widget _buildCombinedChart(
      String title, List<SensorData> series1, List<SensorData> series2) {
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        legend: Legend(isVisible: true),
        series: <LineSeries<SensorData, DateTime>>[
          LineSeries<SensorData, DateTime>(
            name: 'Total Acceleration',
            dataSource: series1,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
          LineSeries<SensorData, DateTime>(
            name: 'Total Rotation',
            dataSource: series2,
            xValueMapper: (SensorData data, _) => data.time,
            yValueMapper: (SensorData data, _) => data.value,
          ),
        ],
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
      ),
    );
  }

  // Build a chart with multiple data series
  Widget _buildMultiSeriesChart(String title, List<List<SensorData>> seriesData,
      List<String> seriesNames) {
    List<LineSeries<SensorData, DateTime>> seriesList = [];
    for (int i = 0; i < seriesData.length; i++) {
      seriesList.add(
        LineSeries<SensorData, DateTime>(
          name: seriesNames[i],
          dataSource: seriesData[i],
          xValueMapper: (SensorData data, _) => data.time,
          yValueMapper: (SensorData data, _) => data.value,
        ),
      );
    }
    return SizedBox(
      height: 200,
      child: SfCartesianChart(
        title: ChartTitle(text: title),
        legend: Legend(isVisible: true),
        series: seriesList,
        primaryXAxis: DateTimeAxis(),
        primaryYAxis: NumericAxis(),
      ),
    );
  }

  // Create a threshold annotation for impact detection visualization
  CartesianChartAnnotation _buildThresholdAnnotation(double threshold) {
    return CartesianChartAnnotation(
      widget: Container(
        child: Text(
          'Threshold: $threshold',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      coordinateUnit: CoordinateUnit.point,
      x: DateTime.now(), // Places the annotation at the current time.
      y: threshold,
    );
  }
}

// ******************************************************************************
// * DATA MODEL
// * Simple class to store time-series sensor data
// ******************************************************************************
class SensorData {
  final DateTime time;
  final double value;

  SensorData(this.time, this.value);
}
