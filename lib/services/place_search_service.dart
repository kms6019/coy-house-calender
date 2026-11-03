import 'package:cloud_functions/cloud_functions.dart';
import '../models/event_place.dart';

/// 구글 장소 자동완성.
///
/// API 키를 앱에 넣지 않으려고 Cloud Functions(`searchPlaces`)를 거쳐 호출한다.
/// 같은 검색 화면에서 친 글자들은 [sessionToken] 하나로 묶어 보낸다.
class PlaceSearchService {
  final _callable = FirebaseFunctions.instanceFor(
    region: 'asia-northeast3',
  ).httpsCallable('searchPlaces');

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
}
