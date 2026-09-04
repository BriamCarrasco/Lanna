// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
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
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.fromLTRB(
                LannaSpacing.s5,
                0,
                LannaSpacing.s3,
                0,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: chrome.barBorder)),
              ),
              child: Row(
                children: [
                  Text(
                    'Buscar en el libro',
                    style: LannaType.lg.copyWith(
                      fontFamily: AppFonts.serif,
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
              padding: const EdgeInsets.fromLTRB(
                LannaSpacing.s4,
                LannaSpacing.s4,
                LannaSpacing.s4,
                LannaSpacing.s3,
              ),
              child: Container(
                height: LannaSpacing.fieldHeight,
                padding: const EdgeInsets.only(
                  left: LannaSpacing.s3 - 2,
                  right: 4,
                ),
                decoration: BoxDecoration(
                  color: chrome.fieldBackground,
                  borderRadius: LannaRadii.brMd,
                  border: Border.all(color: chrome.panelBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 15, color: chrome.onBarMuted),
                    const SizedBox(width: LannaSpacing.s2),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: widget.onSubmit,
                        cursorColor: ReaderChrome.accent,
                        cursorWidth: 1.5,
                        style: LannaType.md.copyWith(color: chrome.onBar),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Palabra o frase',
                          hintStyle: LannaType.md.copyWith(
                            color: chrome.onBarMuted,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: LannaSpacing.s2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LannaSpacing.s5,
                0,
                LannaSpacing.s5,
                LannaSpacing.s2,
              ),
              child: Text(
                _statusLine(),
                style: LannaType.micro.copyWith(color: chrome.onBarMuted),
              ),
            ),
            Expanded(child: _results(chrome)),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: LannaSpacing.s2),
      itemCount: widget.hits.length,
      itemBuilder: (context, i) {
        final hit = widget.hits[i];
        return InkWell(
          onTap: () => widget.onSelect(hit),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              LannaSpacing.s5,
              LannaSpacing.s2 + 1,
              LannaSpacing.s4,
              LannaSpacing.s2 + 1,
            ),
            child: Text(
              hit.excerpt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: LannaType.sm.copyWith(color: chrome.onBarMuted),
            ),
          ),
        );
      },
    );
  }
}
