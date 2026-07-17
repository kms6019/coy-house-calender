import '../models/couple_model.dart';

/// 커플 색상 프리셋 (Material 계열 12색)
const List<int> kCouplePalette = [
  0xFFEF5350, // red400
  0xFFF06292, // pink300
  0xFFAB47BC, // purple400
  0xFF7E57C2, // deepPurple400
  0xFF5C6BC0, // indigo400
  0xFF42A5F5, // blue400
  0xFF26A69A, // teal400
  0xFF66BB6A, // green400
  0xFFFFB300, // amber600
  0xFFFFA726, // orange400
  0xFF8D6E63, // brown400
  0xFF78909C, // blueGrey400
];

/// 내 역할에 해당하는 couples 문서 색상 필드명
String myColorField(CoupleModel couple, String myUid) {
  return couple.ownerUid == myUid ? 'ownerColor' : 'partnerColor';
}
