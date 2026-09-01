// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../epub_view.dart';
import '../reader_theme.dart';

class SearchPanel extends StatefulWidget {
  const SearchPanel({
    super.key,
    required this.chrome,
    required this.hits,
    required this.busy,
    required this.query,
    required this.onSubmit,
    required this.onSelect,
    required this.onClose,
  });

  final ReaderChrome chrome;
  final List<SearchHit> hits;
  final bool busy;
  final String query;
  final ValueChanged<String> onSubmit;
  final ValueChanged<SearchHit> onSelect;
  final VoidCallback onClose;

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chrome = widget.chrome;
    return Container(
      width: 320,
      height: double.infinity,
      decoration: BoxDecoration(
        color: chrome.panelBackground,
        border: Border(right: BorderSide(color: chrome.panelBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 52,
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: chrome.barBorder)),
            ),
            child: Row(
              children: [
                Text(
                  'Buscar en el libro',
                  style: AppTheme.reading(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: chrome.onBar,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 17),
                  color: chrome.onBarMuted,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: BoxDecoration(
                color: chrome.fieldBackground,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: chrome.panelBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 15, color: chrome.onBarMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: widget.onSubmit,
                      cursorColor: ReaderChrome.accent,
                      cursorWidth: 1.5,
                      style: TextStyle(fontSize: 13, color: chrome.onBar),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Palabra o frase',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: chrome.onBarMuted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              _statusLine(),
              style: TextStyle(fontSize: 11, color: chrome.onBarMuted),
            ),
          ),
          Expanded(child: _results(chrome)),
        ],
      ),
    );
  }

  String _statusLine() {
    if (widget.busy) return 'Buscando…';
    if (widget.query.isEmpty) return 'Escribe y pulsa Enter';
    final n = widget.hits.length;
    if (n == 0) return 'Sin coincidencias';
    return n == 1 ? '1 coincidencia' : '$n coincidencias';
  }

  Widget _results(ReaderChrome chrome) {
    if (widget.hits.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: widget.hits.length,
      itemBuilder: (context, i) {
        final hit = widget.hits[i];
        return InkWell(
          onTap: () => widget.onSelect(hit),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 9, 16, 9),
            child: Text(
              hit.excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: chrome.onBarMuted,
              ),
            ),
          ),
        );
      },
    );
  }
}
