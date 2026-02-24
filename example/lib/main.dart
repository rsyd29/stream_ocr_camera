import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stream_ocr_camera/stream_ocr_camera.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANPR Scanner Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isCameraPermissionGranted = false;
  bool _isLoading = true;

  // Current scan mode
  ScanMode _scanMode = ScanMode.plateOnly;

  // Scanner widget keys
  final _anprScannerKey = GlobalKey<AnprScannerWidgetState>();
  final _docScannerKey = GlobalKey<DocumentScannerWidgetState>();

  // Single plate mode state
  AnprResult? _lastPlateResult;

  // Multi plate mode state
  bool _multiPlateMode = false;
  final List<AnprResult> _allDetectedPlates = [];
  final ScrollController _plateListController = ScrollController();

  // Document mode state
  DocumentOcrResult? _lastDocResult;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _plateListController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _isCameraPermissionGranted = status.isGranted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    if (!_isCameraPermissionGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white54,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera permission is required',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestCameraPermission,
                icon: const Icon(Icons.refresh),
                label: const Text('Grant Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner widget — switches between ANPR and Document scanner
          if (_scanMode == ScanMode.plateOnly)
            AnprScannerWidget(
              key: _anprScannerKey,
              multiPlateMode: _multiPlateMode,
              onPlateDetected: (result) {
                setState(() => _lastPlateResult = result);
              },
              onMultiplePlatesDetected: (results) {
                setState(() => _allDetectedPlates.addAll(results));
                _scrollToBottom();
              },
              onError: (error) => debugPrint('Scanner Error: $error'),
            )
          else
            DocumentScannerWidget(
              key: _docScannerKey,
              scanMode: _scanMode,
              onDocumentDetected: (result) {
                setState(() => _lastDocResult = result);
              },
              onError: (error) => debugPrint('Scanner Error: $error'),
            ),

          // Top bar with mode toggle
          _buildTopBar(),

          // Bottom result card(s)
          if (_scanMode == ScanMode.plateOnly && _multiPlateMode)
            _buildMultiPlateResults()
          else if (_scanMode == ScanMode.plateOnly && _lastPlateResult != null)
            _buildSinglePlateResult()
          else if (_scanMode != ScanMode.plateOnly && _lastDocResult != null)
            _buildDocumentResult(),
        ],
      ),
    );
  }

  // ── Top Bar ─────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'OCR Scanner',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Mode toggle row
              _buildModeSwitcher(),
              // Single / Multi toggle (plate mode only)
              if (_scanMode == ScanMode.plateOnly) ...[
                const SizedBox(height: 8),
                _buildPlateSubModeSwitcher(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(
            label: 'Plat Nomor',
            icon: Icons.directions_car,
            isActive: _scanMode == ScanMode.plateOnly,
            onTap: () => _switchMode(ScanMode.plateOnly),
          ),
          _buildModeChip(
            label: 'STNK',
            icon: Icons.description,
            isActive: _scanMode == ScanMode.stnk,
            onTap: () => _switchMode(ScanMode.stnk),
          ),
          _buildModeChip(
            label: 'BPKB',
            icon: Icons.menu_book,
            isActive: _scanMode == ScanMode.bpkb,
            onTap: () => _switchMode(ScanMode.bpkb),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlateSubModeSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(
            label: 'Single',
            icon: Icons.filter_1,
            isActive: !_multiPlateMode,
            onTap: () => _switchPlateSubMode(false),
          ),
          _buildModeChip(
            label: 'Multi',
            icon: Icons.filter_9_plus,
            isActive: _multiPlateMode,
            onTap: () => _switchPlateSubMode(true),
          ),
        ],
      ),
    );
  }

  void _switchPlateSubMode(bool multi) {
    setState(() {
      _multiPlateMode = multi;
      _lastPlateResult = null;
      _allDetectedPlates.clear();
    });
    _anprScannerKey.currentState?.resetDetectionHistory();
  }

  void _switchMode(ScanMode mode) {
    setState(() {
      _scanMode = mode;
      _lastPlateResult = null;
      _lastDocResult = null;
      _allDetectedPlates.clear();
      _multiPlateMode = false;
    });
    _anprScannerKey.currentState?.resetDetectionHistory();
    _docScannerKey.currentState?.resetDetection();
  }

  void _clearAllPlates() {
    setState(() => _allDetectedPlates.clear());
    _anprScannerKey.currentState?.resetDetectionHistory();
  }

  // ── Single Plate Result ─────────────────────────────────────────────

  Widget _buildSinglePlateResult() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: _resultCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultHeader(
                onClose: () => setState(() => _lastPlateResult = null),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _lastPlateResult!.plateNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  _buildConfidenceBadge(_lastPlateResult!.confidence),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Raw: ${_lastPlateResult!.rawText}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Multi Plate Results ─────────────────────────────────────────────

  Widget _buildMultiPlateResults() {
    if (_allDetectedPlates.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 280),
          decoration: _resultCardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildResultHeader(
                title: '${_allDetectedPlates.length} PLAT TERDETEKSI',
                onClose: () => _clearAllPlates(),
                onClear: () => _clearAllPlates(),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  controller: _plateListController,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _allDetectedPlates.length,
                  separatorBuilder: (_, _) => Divider(
                    color: Colors.white.withValues(alpha: 0.1),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final result = _allDetectedPlates[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.tealAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result.plateNumber,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          _buildConfidenceBadge(result.confidence, small: true),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(result.timestamp),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Document Result ────────────────────────────────────────────────

  Widget _buildDocumentResult() {
    final result = _lastDocResult!;
    final typeName = result.documentType == DocumentType.stnk ? 'STNK' : 'BPKB';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: _resultCardDecoration(
            accentColor: result.documentType == DocumentType.stnk
                ? Colors.amber
                : Colors.blueAccent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultHeader(
                title: '$typeName TERDETEKSI',
                onClose: () {
                  setState(() => _lastDocResult = null);
                  _docScannerKey.currentState?.resetDetection();
                },
              ),
              const SizedBox(height: 12),

              // Plate number (primary)
              if (result.plateNumber != null) ...[
                _buildFieldRow(
                  'Nomor Polisi',
                  result.plateNumber!,
                  isPrimary: true,
                ),
                const SizedBox(height: 8),
              ],

              // Metadata fields
              if (result.ownerName != null)
                _buildFieldRow('Nama Pemilik', result.ownerName!),
              if (result.vehicleBrand != null)
                _buildFieldRow('Merek', result.vehicleBrand!),
              if (result.vehicleType != null)
                _buildFieldRow('Tipe', result.vehicleType!),
              if (result.vehicleColor != null)
                _buildFieldRow('Warna', result.vehicleColor!),
              if (result.engineNumber != null)
                _buildFieldRow('No. Mesin', result.engineNumber!),
              if (result.chassisNumber != null)
                _buildFieldRow('No. Rangka', result.chassisNumber!),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildConfidenceBadge(result.confidence, small: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String value, {bool isPrimary = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: isPrimary ? 13 : 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isPrimary ? 22 : 14,
                fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                letterSpacing: isPrimary ? 1.5 : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared Helpers ──────────────────────────────────────────────────

  BoxDecoration _resultCardDecoration({Color? accentColor}) {
    final color = accentColor ?? Colors.teal;
    return BoxDecoration(
      color: Colors.grey[900]!.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.5)),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.2),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ],
    );
  }

  Widget _buildResultHeader({
    String? title,
    required VoidCallback onClose,
    VoidCallback? onClear,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            title ?? 'TERDETEKSI',
            style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const Spacer(),
        if (onClear != null)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_sweep, size: 16),
            label: const Text('Clear', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
          ),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
        ),
      ],
    );
  }

  Widget _buildConfidenceBadge(double confidence, {bool small = false}) {
    final Color badgeColor;
    if (confidence >= 80) {
      badgeColor = Colors.greenAccent;
    } else if (confidence >= 50) {
      badgeColor = Colors.orangeAccent;
    } else {
      badgeColor = Colors.redAccent;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${confidence.toStringAsFixed(0)}%',
        style: TextStyle(
          color: badgeColor,
          fontSize: small ? 11 : 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_plateListController.hasClients) {
        _plateListController.animateTo(
          _plateListController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
