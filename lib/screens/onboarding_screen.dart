import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: null,
      iconColor: Colors.orange,
      title: 'FungalAnalyzer',
      subtitle: 'Análise automatizada de colônias fúngicas por visão computacional.',
      body:
          'Este aplicativo foi desenvolvido como parte de uma Iniciação Científica e usa um modelo de segmentação YOLOv8 treinado especificamente para detectar fungos e escalas de referência em imagens de placas de Petri.',
    ),
    _OnboardingPage(
      icon: Icons.camera_alt_outlined,
      iconColor: Colors.blue,
      title: 'Como funciona',
      subtitle: 'Três passos simples para obter a área da colônia.',
      body:
          '1. Fotografe a placa com uma escala de referência (papel milimetrado ou régua) visível ao lado.\n\n2. O app detecta automaticamente o fungo e a escala usando IA.\n\n3. Informe o comprimento real da escala em cm e o app calcula a área em cm².',
    ),
    _OnboardingPage(
      icon: Icons.bar_chart_outlined,
      iconColor: Colors.green,
      title: 'Dicas de uso',
      subtitle: 'Para melhores resultados:',
      body:
          '• Use iluminação uniforme e fundo escuro.\n\n• A escala deve estar no mesmo plano da colônia.\n\n• Evite reflexos na tampa da placa.\n\n• Você pode usar a câmera ou importar da galeria.\n\n• Exporte os resultados como imagem para seu relatório.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _PageContent(page: _pages[i]),
              ),
            ),
            _BottomBar(
              pageCount: _pages.length,
              currentPage: _currentPage,
              onNext: () {
                _controller.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              onSkip: widget.onDone,
              onDone: widget.onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          if (page.icon == null)
            const AppLogo(size: 100, cornerRadius: 22)
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: page.iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(page.icon, size: 52, color: page.iconColor),
            ),
          const SizedBox(height: 32),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            page.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page.body,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onDone;

  const _BottomBar({
    required this.pageCount,
    required this.currentPage,
    required this.onNext,
    required this.onSkip,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentPage == pageCount - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pageCount, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? Colors.orange : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          if (isLast)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: onDone,
                child: const Text('Começar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: onSkip,
                  child: const Text('Pular', style: TextStyle(color: Colors.grey)),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Próximo', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData? icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}
