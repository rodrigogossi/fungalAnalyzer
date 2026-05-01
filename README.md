# FungalAnalyzer

Aplicativo móvel para medição automatizada da área de crescimento de colônias fúngicas em placas de Petri, desenvolvido como ferramenta auxiliar de uma **Iniciação Científica** focada em **deep learning** e **visão computacional** aplicados à micologia.

---

## Sobre o Projeto

O FungalAnalyzer substitui o processo manual de contagem de pixels utilizado em experimentos de micologia. A partir de uma fotografia da placa de Petri contendo uma referência de escala, o app detecta e segmenta automaticamente a colônia fúngica e calcula sua área em cm².

O modelo de segmentação foi treinado com imagens coletadas em laboratório e exportado para o formato TFLite, permitindo inferência local no dispositivo — sem necessidade de conexão com a internet.

---

## Funcionalidades

- **Detecção e segmentação** da colônia fúngica e da referência de escala via YOLOv8-seg
- **Cálculo de área** em cm² e mm² a partir da escala informada pelo usuário
- **Overlay visual** com máscara de segmentação sobre a imagem original
- **Histórico** de análises com imagem, data e resultados
- **Exportação CSV** de todas as análises realizadas
- **Memória de escala** — o último valor digitado é lembrado entre sessões
- Funciona **offline**, com inferência totalmente local via TFLite
- Suporte a **iOS e Android**
- Suporte a **modo escuro**

---

## Metodologia

### Captura

O usuário fotografa a placa de Petri incluindo no campo de visão um objeto de referência de tamanho conhecido (ex: papel milimetrado, régua). O app aceita imagens da câmera ou da galeria do dispositivo.

### Inferência

A imagem é redimensionada para 1024×1024 px e processada por um modelo **YOLOv8-seg** convertido para TFLite (float32). O modelo detecta duas classes:

| Classe | Índice | Descrição |
|--------|--------|-----------|
| `scale` | 0 | Referência de escala |
| `fungus` | 1 | Colônia fúngica |

A saída do modelo consiste em:
- Tensor de detecções `[1, 38, N]` — coordenadas normalizadas, scores e 32 coeficientes de máscara por âncora
- Tensor de protótipos `[1, 256, 256, 32]` — base para reconstrução das máscaras de segmentação

### Cálculo de Área

```
pixelsPerCm  = largura_bbox_escala_px / comprimento_escala_cm
área (cm²)   = pixels_fungo / pixelsPerCm²
```

Os pixels da máscara são contados no espaço 256×256 do modelo. A escala converte essa contagem para unidades reais informadas pelo usuário.

---

## Modelo

| Parâmetro | Valor |
|-----------|-------|
| Arquitetura | YOLOv8-seg |
| Formato | TFLite float32 |
| Tamanho do modelo | ~13 MB |
| Resolução de entrada | 1024×1024 px |
| Classes | 2 (scale, fungus) |
| Confiança mínima | 50% |
| Dados de treino | Imagens coletadas em laboratório |

> O arquivo do modelo (`best_float32.tflite`) está incluído no repositório em `assets/models/`.

---

## Stack Tecnológico

| Camada | Tecnologia |
|--------|------------|
| Framework | Flutter 3.x / Dart |
| Inferência ML | tflite_flutter 0.12 |
| Processamento de imagem | package:image |
| Gerenciamento de estado | Provider + ChangeNotifier |
| Persistência | SharedPreferences + sistema de arquivos |
| Plataformas | iOS 14+ / Android 5+ (API 21+) |

---

## Estrutura do Projeto

```
lib/
├── main.dart                    # Ponto de entrada, providers, onboarding
├── models/
│   ├── detection_models.dart    # FungalClass, Detection, AnalysisResult
│   └── history_entry.dart       # Modelo de entrada do histórico
├── services/
│   ├── fungal_detector.dart     # Inferência TFLite em Dart Isolate
│   └── history_store.dart       # Persistência do histórico
├── screens/
│   ├── home_screen.dart         # Tela inicial (câmera / galeria)
│   ├── analysis_screen.dart     # Resultado da análise
│   ├── history_screen.dart      # Histórico de análises
│   ├── about_screen.dart        # Informações do app
│   └── onboarding_screen.dart   # Tutorial inicial
└── widgets/
    └── app_logo.dart            # Logo do aplicativo
```

---

## Como Executar

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.5 ou superior
- Android Studio / Xcode para emuladores ou dispositivo físico

### Instalação

```bash
# 1. Clone o repositório
git clone https://github.com/SEU_USUARIO/fungal-analyzer.git
cd fungal-analyzer

# 2. Instale as dependências
flutter pub get

# 3. Execute
flutter run
```

### Gerar APK (Android)

```bash
flutter build apk --release --split-per-abi
```

O APK para dispositivos modernos (64-bit) estará em:
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

### Gerar IPA (iOS)

```bash
flutter build ios --release
```

---

## Permissões Necessárias

| Permissão | Plataforma | Uso |
|-----------|------------|-----|
| `CAMERA` | Android / iOS | Captura de foto pela câmera |
| `READ_MEDIA_IMAGES` | Android 13+ | Acesso à galeria |
| `READ_MEDIA_VISUAL_USER_SELECTED` | Android 14+ | Acesso parcial à galeria |
| `NSCameraUsageDescription` | iOS | Câmera |
| `NSPhotoLibraryUsageDescription` | iOS | Galeria |

---

## Créditos

- Modelo YOLOv8 por [Ultralytics](https://github.com/ultralytics/ultralytics) (AGPL-3.0)
- Desenvolvido como ferramenta auxiliar de Iniciação Científica
