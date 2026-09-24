import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'scan_history_item.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<ScanHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? historyJson = prefs.getStringList('scanHistory');
    if (historyJson != null) {
      setState(() {
        _history = historyJson
            .map((json) => ScanHistoryItem.fromJson(jsonDecode(json)))
            .toList()
            .reversed
            .toList(); // Neueste zuerst anzeigen
      });
    }
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('scanHistory');
    setState(() {
      _history = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan-Verlauf'),
        backgroundColor: Colors.blue,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Verlauf löschen',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Verlauf löschen?'),
                    content: const Text('Möchtest du wirklich den gesamten Verlauf löschen?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Abbrechen'),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearHistory();
                          Navigator.pop(context);
                        },
                        child: const Text('Löschen', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(child: Text('Noch keine Scans vorhanden.'))
          : ListView.builder(
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: Icon(
                item.type == 'url'
                    ? Icons.link
                    : item.type == 'phone'
                    ? Icons.phone
                    : Icons.text_fields,
                color: Colors.blue,
              ),
              title: Text(
                item.data,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${item.type.toUpperCase()} • ${item.timestamp.toLocal().toString().substring(0, 16)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: item.data));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('In Zwischenablage kopiert!')),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}