import 'package:cloud_functions/cloud_functions.dart';
import '../models/event_place.dart';

/// 구글 장소 자동완성.
///
/// API 키를 앱에 넣지 않으려고 Cloud Functions(`searchPlaces`)를 거쳐 호출한다.
/// 같은 검색 화면에서 친 글자들은 [sessionToken] 하나로 묶어 보낸다.
class PlaceSearchService {
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  late final _callable = _functions.httpsCallable('searchPlaces');
  late final _locationCallable = _functions.httpsCallable('placeLocation');

  Future<List<EventPlace>> search(
    String input, {
    required String sessionToken,
  }) async {
    final result = await _callable.call<Map<Object?, Object?>>({
      'input': input,
      'sessionToken': sessionToken,
    });
    final suggestions = result.data['suggestions'];
    if (suggestions is! List) return const [];
    return suggestions.map(EventPlace.fromMap).whereType<EventPlace>().toList();
  }

  /// 고른 장소에 좌표를 붙여 돌려준다. 검색과 같은 [sessionToken] 을 넘겨
  /// 세션을 마무리한다 — 그래야 그 세션의 자동완성 요금이 붙지 않는다.
  Future<EventPlace> withLocation(
    EventPlace place, {
    required String sessionToken,
  }) async {
    final placeId = place.placeId;
    if (placeId == null) return place;
    final result = await _locationCallable.call<Map<Object?, Object?>>({
      'placeId': placeId,
      'sessionToken': sessionToken,
    });
    final lat = result.data['lat'], lng = result.data['lng'];
    if (lat is! num || lng is! num) return place;
    return place.withLocation(lat.toDouble(), lng.toDouble());
  }
}
