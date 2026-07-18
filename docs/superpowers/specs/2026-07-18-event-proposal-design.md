# 일정 제안 → 수락/거절 설계

2026-07-18. 일정을 제안으로 보내면 상대가 수락/거절. 수락 시 확정.

## 데이터

- `EventModel.status` (String: `'proposed'` | `'confirmed'`, 기본 `'confirmed'`)
- 구 문서(필드 없음) → confirmed
- `copyWith`에 `status` 파라미터 추가

## 흐름

1. **제안 생성**: 폼에서 "상대에게 제안" 스위치 ON → status proposed로 저장
   - 신규 생성 시에만 노출 (수정 화면에서는 스위치 숨김, 기존 status 유지)
   - proposed는 삼성캘린더 동기화 스킵 (`syncEventCreate` 미호출)
2. **표시**: proposed 이벤트는 리스트 타일 제목 뒤 '(제안)' 대신 subtitle 앞에 파란 '제안' 뱃지 — 간단히 title suffix ' 📩' + subtitle 앞 '제안 · ' prefix
3. **수락/거절** (상세 화면, status proposed && 현재 uid ≠ createdByUid일 때만):
   - 하단에 FilledButton '수락' + OutlinedButton '거절' 행
   - 수락: `updateEvent(copyWith(status: 'confirmed'), editorUid: 내uid)` → pop
   - 거절: 확인 다이얼로그 후 `deleteEvent` → pop
4. **푸시** (functions/index.js):
   - onCreate: status == 'proposed' → "OO님이 일정을 제안했어요"
   - onUpdate: before proposed → after confirmed → "OO님이 제안을 수락했어요" (다른 필드 변경 없어도 발송)
   - 거절 삭제는 푸시 없음 (onDelete 미배포, v1 제외)

## 제안 이벤트의 부가 동작

- 제안 생성자는 자기 알람 설정 가능 (기존 로직 유지 — 단순화)
- 홈위젯/브리핑에는 proposed도 포함 (v1 단순화, 구분 안 함)
- 상세 화면 수정/삭제 버튼: 기존 isOwner 조건 유지 (제안 받은 쪽은 수락/거절만)

## 테스트

- event_model_test: fromMap 기본 confirmed, proposed 왕복, copyWith(status) 반영·보존
