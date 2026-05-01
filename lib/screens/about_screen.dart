import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/app_logo.dart';

class AboutScreen extends StatelessWidget {
  final VoidCallback onShowOnboarding;

  const AboutScreen({super.key, required this.onShowOnboarding});

  static const _contactEmail = 'contato@rodrigogossi.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // App identity
          _Section(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const AppLogo(size: 64),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FungalAnalyzer',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (_, snap) => Text(
                          'Versão ${snap.data?.version ?? '1.0'}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]),

          // IC description
          _Section(
            title: 'Iniciação Científica',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Este app foi desenvolvido como ferramenta auxiliar de uma Iniciação Científica focada em deep learning e visão computacional aplicados à micologia.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O objetivo é medir a área de crescimento de colônias fúngicas em placas de Petri de forma automatizada, utilizando um modelo de segmentação YOLOv8 treinado para detectar e delimitar as colônias com precisão.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Technology
          const _Section(
            title: 'Tecnologia',
            children: [
              _InfoRow(label: 'Modelo de IA', value: 'YOLOv8-seg'),
              _InfoRow(label: 'Framework', value: 'TFLite / Flutter'),
              _InfoRow(label: 'Plataforma', value: 'iOS / Android'),
              _InfoRow(label: 'Linguagem', value: 'Dart / Flutter'),
            ],
          ),

          // Contact
          _Section(
            title: 'Contato',
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text(_contactEmail),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: const Text('rodrigogossi.com/fungalanalyzer'),
                onTap: () {},
              ),
            ],
          ),

          // Help
          _Section(children: [
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Rever Tutorial'),
              onTap: onShowOnboarding,
            ),
          ]),

          // Credits
          _Section(
            title: 'Créditos',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Modelo treinado com imagens coletadas em laboratório.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('YOLOv8 por Ultralytics (AGPL-3.0).',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const _Section({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
