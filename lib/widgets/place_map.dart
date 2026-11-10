import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/event_place.dart';
import '../services/place_search_service.dart';

/// 장소의 작은 지도 그림. 누르면 구글 지도로 연다.
///
/// 좌표가 없어도 구글 장소(placeId)면 좌표를 받아 와서 그린다 — 좌표 저장 전에
/// 고른 장소도 지도가 나오게. 직접 입력한 장소는 그리지 않는다.
/// 라이트 모드(움직이지 않는 지도)라 스크롤을 방해하지 않는다.
/// Maps SDK for Android 를 쓰므로 안드로이드에서만 그린다.
class PlaceMap extends StatefulWidget {
  final EventPlace place;
  const PlaceMap({super.key, required this.place});

  @override
  State<PlaceMap> createState() => _PlaceMapState();
}

class _PlaceMapState extends State<PlaceMap> {
  EventPlace? _located;

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void didUpdateWidget(PlaceMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.place != widget.place) _locate();
  }

  void _locate() {
    final place = widget.place;
    _located = place.hasLocation ? place : null;
    if (!_supported || place.hasLocation || place.placeId == null) return;
    PlaceSearchService().withLocation(place).then((located) {
      if (mounted && widget.place == place && located.hasLocation) {
        setState(() => _located = located);
      }
    }, onError: (_) {}); // 위치를 못 받으면 지도만 빠진다
  }

  @override
  Widget build(BuildContext context) {
    final place = _located;
    if (!_supported || place == null) return const SizedBox.shrink();
    final target = LatLng(place.lat!, place.lng!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 160,
        child: GoogleMap(
          // 장소가 바뀌면 새로 만든다 — initialCameraPosition 은 처음에만 쓰인다
          key: ValueKey(target),
          liteModeEnabled: true,
          initialCameraPosition: CameraPosition(target: target, zoom: 16),
          markers: {
            Marker(markerId: const MarkerId('place'), position: target),
          },
          mapToolbarEnabled: false,
          onTap: (_) =>
              launchUrl(place.mapsUri, mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }
}
