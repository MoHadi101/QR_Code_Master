import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class GenerateQRCode extends StatefulWidget {
  const GenerateQRCode({super.key});

  @override
  State<GenerateQRCode> createState() => _GenerateQRCodeState();
}

class _GenerateQRCodeState extends State<GenerateQRCode> {
  final TextEditingController urlController = TextEditingController();
  // Der Key ist nötig, um das Widget in ein Bild zu verwandeln
  final GlobalKey _qrKey = GlobalKey();
  String qrData = '';

  // Wandelt das QR-Widget in ein PNG-Bild um
  Future<Uint8List?> _captureQrImage() async {
    try {
      final RenderRepaintBoundary boundary =
      _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Fehler beim Erstellen des Bildes: $e');
      return null;
    }
  }

  // Speichert den QR-Code in der Galerie
  Future<void> _saveToGallery() async {
    final Uint8List? imageBytes = await _captureQrImage();
    if (imageBytes == null) return;

    try {
      // Prüfe, ob wir Zugriff auf die Galerie haben
      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(imageBytes);
      await Gal.putImage(file.path, album: 'QR Codes');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR-Code in der Galerie gespeichert! 📸'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    }
  }

  // Teilt den QR-Code als Bild
  Future<void> _shareQrImage() async {
    final Uint8List? imageBytes = await _captureQrImage();
    if (imageBytes == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/qr_share.png');
      await file.writeAsBytes(imageBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: qrData,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Teilen: $e')),
      );
    }
  }

  // Kopiert den Text in die Zwischenablage
  void _copyText() {
    Clipboard.setData(ClipboardData(text: qrData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Text kopiert! 📋')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Generieren'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // QR-Code in einem RepaintBoundary (wichtig für Bild-Export)
              if (qrData.isNotEmpty)
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 220.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 25),

              // Eingabefeld
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  hintText: 'Text oder URL eingeben',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  labelText: 'Deine Daten',
                ),
              ),

              const SizedBox(height: 15),

              // Button zum Generieren
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.qr_code_2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    setState(() {
                      qrData = urlController.text.trim();
                    });
                  },
                  label: const Text(
                    'QR Code Generieren',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Aktions-Buttons (nur sichtbar wenn QR-Code existiert)
              if (qrData.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Speichern'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveToGallery,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Teilen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _shareQrImage,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Text kopieren'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _copyText,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }
}