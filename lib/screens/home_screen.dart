import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../services/fungal_detector.dart';
import '../widgets/app_logo.dart';
import 'analysis_screen.dart';
import 'history_screen.dart';
import 'about_screen.dart';
import 'onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final detector = context.watch<FungalDetector>();
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _CaptureTab(detector: detector),
          const HistoryScreen(),
          AboutScreen(onShowOnboarding: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OnboardingScreen(onDone: () => Navigator.pop(context))),
            );
          }),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        indicatorColor: Colors.orange.withValues(alpha: 0.15),
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.camera_alt_outlined), label: 'Captura'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Histórico'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Sobre'),
        ],
      ),
    );
  }
}

class _CaptureTab extends StatefulWidget {
  final FungalDetector detector;
  const _CaptureTab({required this.detector});

  @override
  State<_CaptureTab> createState() => _CaptureTabState();
}

class _CaptureTabState extends State<_CaptureTab> {
  bool _picking = false;
  FungalDetector get detector => widget.detector;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Column(
            children: [
              const AppLogo(size: 96),
              const SizedBox(height: 16),
              Text(
                'FungalAnalyzer',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                'Calcule a área de colônias fúngicas',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickImage(context, ImageSource.camera),
                    child: const Column(
                      children: [
                        Icon(Icons.camera_alt, size: 26),
                        SizedBox(height: 6),
                        Text('Câmera', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _pickImage(context, ImageSource.gallery),
                    child: const Column(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 26),
                        SizedBox(height: 6),
                        Text('Galeria', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ModelStatusIndicator(detector: detector),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    ImageSource? nextSource;
    try {
      if (source == ImageSource.gallery && !await _ensureGalleryAccess(context)) {
        return;
      }

      final picker = ImagePicker();
      XFile? picked;
      try {
        picked = await picker.pickImage(source: source, imageQuality: 95);
      } on PlatformException {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não foi possível abrir a galeria. Verifique as permissões nas Configurações.'),
            ),
          );
        }
        return;
      }
      if (picked == null || !context.mounted) return;

      final bytes = await picked.readAsBytes();
      if (!context.mounted) return;
      nextSource = await Navigator.push<ImageSource>(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisScreen(
            imageBytes: bytes,
            detector: detector,
            imageSource: source,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (nextSource != null && context.mounted) {
      _pickImage(context, nextSource);
    }
  }

  Future<bool> _ensureGalleryAccess(BuildContext context) async {
    if (Platform.isIOS) {
      return _ensureIOSPhotoAccess(context);
    }
    return _ensureAndroidGalleryAccess(context);
  }

  // iOS: distingue acesso total, parcial (Limited) e negado.
  Future<bool> _ensureIOSPhotoAccess(BuildContext context) async {
    final status = await Permission.photos.status;

    if (status.isGranted) return true;

    if (status.isLimited) {
      if (!context.mounted) return true;
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Acesso parcial à galeria'),
          content: const Text(
            'O app tem acesso apenas às fotos selecionadas. '
            'Para ver todas as fotos, conceda acesso total nas Configurações.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Continuar assim'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abrir Configurações'),
            ),
          ],
        ),
      );
      if (goToSettings == true) {
        await openAppSettings();
        return false;
      }
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.photos.request();
      return result.isGranted || result.isLimited;
    }

    // permanentlyDenied
    if (!context.mounted) return false;
    await _showPermanentlyDeniedDialog(context);
    return false;
  }

  // Android: API < 33 usa READ_EXTERNAL_STORAGE; 33+ usa READ_MEDIA_IMAGES;
  // 34+ também aceita READ_MEDIA_VISUAL_USER_SELECTED (acesso parcial = isLimited).
  Future<bool> _ensureAndroidGalleryAccess(BuildContext context) async {
    final status = await Permission.photos.status;

    // granted ou limited (acesso parcial no Android 14+) — tudo certo
    if (status.isGranted || status.isLimited) return true;

    if (status.isDenied) {
      final result = await Permission.photos.request();
      if (result.isGranted || result.isLimited) return true;
      // Se ainda negado, tenta abrir a galeria mesmo assim — alguns OEMs
      // gerenciam permissões de forma independente do sistema padrão.
      return true;
    }

    // permanentlyDenied
    if (!context.mounted) return false;
    await _showPermanentlyDeniedDialog(context);
    return false;
  }

  Future<void> _showPermanentlyDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permissão negada'),
        content: const Text(
          'O acesso à galeria foi bloqueado. '
          'Habilite nas Configurações do sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Abrir Configurações'),
          ),
        ],
      ),
    );
  }
}

class _ModelStatusIndicator extends StatelessWidget {
  final FungalDetector detector;
  const _ModelStatusIndicator({required this.detector});

  @override
  Widget build(BuildContext context) {
    if (!detector.isModelLoaded) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_outlined, color: Colors.red, size: 16),
          SizedBox(width: 6),
          Text('Modelo não encontrado', style: TextStyle(color: Colors.red, fontSize: 12)),
        ],
      );
    }
    if (!detector.isWarmedUp) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Text('Preparando modelo…', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      );
    }
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: Colors.green, size: 16),
        SizedBox(width: 6),
        Text('Modelo pronto', style: TextStyle(color: Colors.green, fontSize: 12)),
      ],
    );
  }
}
