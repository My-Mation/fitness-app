import 'package:flutter/material.dart';
import 'package:pushup_counter/services/storage_service.dart';

class AppEditor extends StatefulWidget {
  final String packageName;

  const AppEditor({super.key, required this.packageName});

  @override
  State<AppEditor> createState() => _AppEditorState();
}

class _AppEditorState extends State<AppEditor> {
  final _storage = StorageService();
  late Duration _currentLimit;
  double _sliderValue = 0;

  @override
  void initState() {
    super.initState();
    _currentLimit = _storage.getDailyLimit(widget.packageName);
    _sliderValue = _currentLimit.inMinutes.toDouble();
  }

  void _saveLimit() async {
    final newLimit = Duration(minutes: _sliderValue.toInt());
    await _storage.setDailyLimit(widget.packageName, newLimit);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time limit updated!')),
      );
      Navigator.of(context).pop();
    }
  }

  void _removeLimit() async {
    await _storage.removeDailyLimit(widget.packageName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App restriction removed!')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Limit: ${widget.packageName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _removeLimit,
            tooltip: 'Remove Restriction',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Set daily time limit for ${widget.packageName}',
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              '${_sliderValue.toInt()} minutes',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _sliderValue,
              min: 0,
              max: 180, // 3 hours
              divisions: 12,
              label: '${_sliderValue.toInt()} min',
              onChanged: (value) {
                setState(() {
                  _sliderValue = value;
                });
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _saveLimit,
              icon: const Icon(Icons.save),
              label: const Text('Save Limit'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
