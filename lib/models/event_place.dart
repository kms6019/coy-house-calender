/// 일정 장소.
///
/// 직접 입력하면 [name] 만 있고, 구글 장소 검색으로 고르면 [address] 와
/// [placeId] 가 함께 채워진다.
class EventPlace {
  final String name;
  final String? address;

  /// 구글 Places 의 place id — 지도에서 정확히 그 장소를 열 때 쓴다.
  final String? placeId;

  const EventPlace({required this.name, this.address, this.placeId});

  /// 기기 캘린더(EVENT_LOCATION)와 지도 검색어로 쓰는 한 줄 표기.
  String get label {
    final a = address ?? '';
    return a.isEmpty || a == name ? name : '$name, $a';
  }

  /// 구글 지도 링크. 지도 앱이 설치돼 있으면 앱으로 열린다.
  Uri get mapsUri => Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': label,
    'query_place_id': ?placeId,
  });

  /// Firestore 값 → EventPlace. 형식이 다르거나 이름이 비었으면 null.
  static EventPlace? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final name = _text(raw['name']);
    if (name == null) return null;
    return EventPlace(
      name: name,
      address: _text(raw['address']),
      placeId: _text(raw['placeId']),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    if (address != null) 'address': address,
    if (placeId != null) 'placeId': placeId,
  };

  static String? _text(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
