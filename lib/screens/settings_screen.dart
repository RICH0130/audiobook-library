import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _keyCtrl;
  bool _obscure = true;

  static const _languages = {
    'zh-TW': '中文（台灣）',
    'zh-CN': '中文（中國）',
    'zh-HK': '粵語（香港）',
    'en-US': 'English (US)',
    'ja-JP': '日本語',
  };

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(text: context.read<AppSettings>().apiKey);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('朗讀', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _languages.containsKey(s.language) ? s.language : 'zh-TW',
            decoration: const InputDecoration(labelText: '朗讀語言', border: OutlineInputBorder()),
            items: _languages.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => v == null ? null : s.setLanguage(v),
          ),
          const SizedBox(height: 16),
          Text('語速：${(s.speechRate * 2).toStringAsFixed(1)}x'),
          Slider(
            value: s.speechRate,
            min: 0.2,
            max: 1.0,
            divisions: 16,
            onChanged: s.setSpeechRate,
          ),
          Text('音調：${s.pitch.toStringAsFixed(1)}'),
          Slider(value: s.pitch, min: 0.5, max: 2.0, divisions: 15, onChanged: s.setPitch),
          const Divider(height: 32),
          Text('閱讀', style: Theme.of(context).textTheme.titleMedium),
          Text('字體大小：${s.fontSize.round()}'),
          Slider(value: s.fontSize, min: 14, max: 30, divisions: 16, onChanged: s.setFontSize),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('在內文標示關鍵字'),
            value: s.showKeywords,
            onChanged: s.setShowKeywords,
          ),
          const Divider(height: 32),
          Text('AI 重點（Claude）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            '關鍵字和 ADHD 重點由 Claude 產生，需要你自己的 API 金鑰（到 console.anthropic.com 申請）。金鑰只存在這支手機上。',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'Claude API 金鑰',
              hintText: 'sk-ant-…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () async {
                await s.setApiKey(_keyCtrl.text);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已儲存金鑰')));
              },
              child: const Text('儲存'),
            ),
          ),
        ],
      ),
    );
  }
}
