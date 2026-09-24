import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'scan_history_item.dart';

class ScanQrCode extends StatefulWidget {
  const ScanQrCode({super.key});

  @override
  State<ScanQrCode> createState() => _ScanQrCodeState();
}

class _ScanQrCodeState extends State<ScanQrCode> {
  final MobileScannerController controller = MobileScannerController();
  String qrResult = 'Scanne einen QR-Code...';
  String qrType = 'text';
  String _lastSavedData = ''; // Verhindert mehrfaches Speichern desselben Codes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Code Scanner'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Kamera-Bereich (70% des Bildschirms)
          Expanded(
            flex: 7,
            child: MobileScanner(
              controller: controller,
              // Dieser errorBuilder zeigt uns, WARUM die Kamera nicht funktioniert
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 60),
                        const SizedBox(height: 15),
                        const Text(
                          'Kamera-Fehler',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Code: ${error.errorCode}\n${error.errorDetails?.message ?? "Unbekannter Fehler"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                    _handleScan(barcode.rawValue!);
                    break;
                  }
                }
              },
            ),
          ),
          // Ergebnis- und Aktionsbereich (30% des Bildschirms)
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              color: Colors.blue.shade50,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      qrResult,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    if (qrResult != 'Scanne einen QR-Code...') ...[
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: [
                          // 1. Immer: Kopieren
                          ElevatedButton.icon(
                            icon: const Icon(Icons.copy, size: 18),
                            label: const Text('Kopieren'),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: qrResult));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('In Zwischenablage kopiert!')),
                              );
                            },
                          ),
                          // 2. URL: Browser öffnen
                          if (qrType == 'url')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_browser, size: 18),
                              label: const Text('Webseite öffnen'),
                              onPressed: () => launchUrl(Uri.parse(qrResult)),
                            ),
                          // 3. Telefon: Anrufen & WhatsApp
                          if (qrType == 'phone') ...[
                            ElevatedButton.icon(
                              icon: const Icon(Icons.phone, size: 18),
                              label: const Text('Anrufen'),
                              onPressed: () => launchUrl(Uri.parse('tel:$qrResult')),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.chat, size: 18),
                              label: const Text('WhatsApp'),
                              onPressed: () {
                                final number = qrResult.replaceAll(RegExp(r'[^\d+]'), '');
                                launchUrl(Uri.parse('https://wa.me/$number'));
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Verarbeitet den gescannten Code
  void _handleScan(String data) {
    // Bestimme den Typ des Codes
    String type = 'text';
    if (data.startsWith('http://') || data.startsWith('https://')) {
      type = 'url';
    } else if (data.startsWith('tel:') || RegExp(r'^\+?[0-9\s\-]+$').hasMatch(data)) {
      type = 'phone';
    } else if (data.startsWith('mailto:')) {
      type = 'email';
    }

    setState(() {
      qrResult = data;
      qrType = type;
    });

    // Speichere im Verlauf, aber nur wenn es nicht der gleiche Code wie zuvor ist
    if (data != _lastSavedData) {
      _lastSavedData = data;
      _saveToHistory(data, type);
    }
  }

  // Speichert den Scan im lokalen Speicher
  Future<void> _saveToHistory(String data, String type) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historyJson = prefs.getStringList('scanHistory') ?? [];

    final newItem = ScanHistoryItem(
      data: data,
      type: type,
      timestamp: DateTime.now(),
    );
    historyJson.add(jsonEncode(newItem.toJson()));

    await prefs.setStringList('scanHistory', historyJson);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}