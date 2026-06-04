import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  bool _isInitializing = true;
  bool _isAnalyzing = false;
  bool _hasPermissionError = false;
  String? _initError;
  FlashMode _flashMode = FlashMode.off;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _hasPermissionError = false;
      _initError = null;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _isInitializing = false;
        _hasPermissionError = true;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _initError = 'No camera available on this device';
        });
        return;
      }

      _selectedCameraIdx = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIdx < 0) _selectedCameraIdx = 0;

      await _startController(_cameras[_selectedCameraIdx]);
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _initError = 'Camera error: $e';
      });
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    final old = _controller;
    if (old != null) {
      await old.dispose();
      if (mounted) {
        setState(() => _controller = null);
      }
    }

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _flashMode = FlashMode.off;
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _initError = 'Failed to start camera: $e';
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isAnalyzing) return;
    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;
    setState(() => _isInitializing = true);
    await _startController(_cameras[_selectedCameraIdx]);
  }

  bool get _isUsingBackCamera {
    if (_cameras.isEmpty || _selectedCameraIdx >= _cameras.length) {
      return true;
    }
    return _cameras[_selectedCameraIdx].lensDirection ==
        CameraLensDirection.back;
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null || _isAnalyzing) return;

    if (!_isUsingBackCamera) {
      _toast('Flash not available on front camera', isError: true);
      return;
    }

    final goingOn = _flashMode == FlashMode.off;
    final modesToTry = goingOn
        ? [FlashMode.torch, FlashMode.always]
        : [FlashMode.off];

    bool ok = false;
    for (final m in modesToTry) {
      try {
        await c.setFlashMode(m);
        setState(() => _flashMode = m);
        ok = true;
        break;
      } catch (_) {}
    }
    if (!ok) {
      _toast('Could not toggle flash on this camera', isError: true);
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _isAnalyzing) return;
    setState(() => _isAnalyzing = true);
    try {
      final file = await c.takePicture();
      await _classifyImage(file.path, source: 'camera');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _toast('Could not capture: $e', isError: true);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_isAnalyzing) return;
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;
      setState(() => _isAnalyzing = true);
      await _classifyImage(image.path, source: 'gallery');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _toast('Gallery error: $e', isError: true);
    }
  }

  Future<void> _classifyImage(String imagePath,
      {required String source}) async {
    try {
      final response = await ApiService.postMultipart(
        '/scan/classify',
        imagePath,
        'image',
        fields: {'source': source},
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      if (response.statusCode == 201) {
        Navigator.pushReplacementNamed(
          context,
          '/scan-result',
          arguments: data,
        );
      } else {
        _toast(
          data['error']?.toString() ?? 'Classification failed',
          isError: true,
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _toast(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      _toast('Unexpected error: $e', isError: true);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildPreview()),
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFF5CB85C), width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_controller != null &&
              _controller!.value.isInitialized &&
              !_isAnalyzing)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.off
                          ? Icons.flash_off
                          : Icons.flash_on,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleFlash,
                  ),
                  if (_cameras.length > 1)
                    IconButton(
                      icon: const Icon(Icons.cameraswitch,
                          color: Colors.white, size: 28),
                      onPressed: _switchCamera,
                    ),
                ],
              ),
            ),
          if (_isAnalyzing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF5CB85C)),
                    SizedBox(height: 16),
                    Text('Analyzing waste...',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Text(
                    'Position waste in frame',
                    style: TextStyle(
                        fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _smallButton(
                        icon: Icons.photo_library,
                        color: const Color(0xFF5CB85C),
                        onTap: _pickFromGallery,
                      ),
                      GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: const Color(0xFF5CB85C),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 4),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 32),
                        ),
                      ),
                      _smallButton(
                        icon: Icons.close,
                        color: Colors.black87,
                        onTap: () => Navigator.pushReplacementNamed(
                            context, '/home'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF5CB85C)),
            SizedBox(height: 12),
            Text('Starting camera...',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_hasPermissionError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography,
                  size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Camera permission denied',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Open Settings > Apps > SortifyX > Permissions and allow Camera.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _initCamera,
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }
    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              Text(_initError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }
    // Full-bleed preview: fill the entire screen, crop excess
    final size = MediaQuery.of(context).size;
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.width,
            height: size.width * c.value.aspectRatio,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }

  Widget _smallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isAnalyzing ? null : onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}