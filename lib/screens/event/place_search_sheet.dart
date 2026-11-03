import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/event_place.dart';
import '../../services/place_search_service.dart';

/// 장소 검색 시트. 고른 장소를 돌려주고, 닫으면 null.
///
/// 검색이 안 되는 상황(오프라인, 서버 미설정)에도 입력한 글자를 그대로
/// 장소로 쓸 수 있다 — "집", "시댁"처럼 지도에 없는 장소도 많다.
Future<EventPlace?> showPlaceSearchSheet(
  BuildContext context, {
  String? initialText,
}) {
  return showModalBottomSheet<EventPlace>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlaceSearchSheet(initialText: initialText),
  );
}

class _PlaceSearchSheet extends StatefulWidget {
  const _PlaceSearchSheet({this.initialText});

  final String? initialText;

  @override
  State<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends State<_PlaceSearchSheet> {
  final _service = PlaceSearchService();
  final _sessionToken = const Uuid().v4();
  late final _ctrl = TextEditingController(text: widget.initialText);
  Timer? _debounce;

  List<EventPlace> _results = const [];
  bool _loading = false;
  bool _failed = false;

  /// 늦게 도착한 이전 검색 결과가 최신 결과를 덮지 않게 하는 번호
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    if (_ctrl.text.trim().isNotEmpty) _search(_ctrl.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
    setState(() {});
  }

  Future<void> _search(String text) async {
    final query = text.trim();
    final seq = ++_requestSeq;
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _service.search(
        query,
        sessionToken: _sessionToken,
      );
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = results;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final typed = _ctrl.text.trim();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: '장소 이름이나 주소',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (typed.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.edit_location_alt_outlined),
                      title: Text("'$typed' 그대로 쓰기"),
                      subtitle: const Text('지도에 없는 장소도 괜찮아요'),
                      onTap: () =>
                          Navigator.of(context).pop(EventPlace(name: typed)),
                    ),
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '지금은 장소 검색을 할 수 없어요. 입력한 그대로 저장할 수 있어요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final place in _results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(place.name),
                      subtitle: place.address != null
                          ? Text(place.address!)
                          : null,
                      onTap: () => Navigator.of(context).pop(place),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
