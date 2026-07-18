# 일정 사진/한줄 후기 설계

2026-07-18. 지난 일정에 사진 1장 + 한줄 후기를 남기는 추억 아카이브. Firebase Storage (Blaze).

## 데이터

- `EventModel.reviewText` (String?, null=후기 없음), `EventModel.reviewPhotoUrl` (String?)
- Storage 경로: `reviews/{eventId}.jpg` (이벤트당 1장, 덮어쓰기)
- 커플 멤버 누구나 작성/수정 (v1 권한 구분 없음)

## UI (event_detail_screen)

- 설명 아래 '후기' 섹션:
  - 후기 없으면: OutlinedButton '후기 남기기'
  - 있으면: 사진(있을 때, ClipRRect 둥근 모서리, 최대 높이 220) + 텍스트 + '후기 수정' TextButton
- 작성/수정 다이얼로그: TextField(한줄 후기) + '사진 선택' 버튼(image_picker 갤러리, maxWidth 1280, imageQuality 80) + 선택 미리보기 + 저장/취소
- 저장: 사진 선택했으면 Storage 업로드 → downloadURL → `updateEvent(copyWith(reviewText, reviewPhotoUrl), editorUid: 내uid)`
- 실패 시 스낵바 '후기 저장에 실패했습니다'

## 규칙/인프라

- pubspec: `firebase_storage`, `image_picker`
- storage.rules (firebase.json 등록 + 배포):
  ```
  rules_version = '2';
  service firebase.storage {
    match /b/{bucket}/o {
      match /reviews/{fileName} {
        allow read: if request.auth != null;
        allow write: if request.auth != null
          && request.resource.size < 5 * 1024 * 1024
          && request.resource.contentType.matches('image/.*');
      }
    }
  }
  ```
- 과금: Storage 무료 5GB — 사진 수백 장 수준 0원. 5MB 제한으로 상한 가드
- 푸시: 후기 저장은 reviewText가 MEANINGFUL_FIELDS에 없으므로 발송 안 됨 (v1 의도)

## 제외 (v1)

- 사진 여러 장, 삭제 UI(수정으로 덮어쓰기만), 후기 모아보기 화면, 위젯/리포트 반영

## 테스트

- event_model_test: reviewText/reviewPhotoUrl 왕복, 구 문서 null, copyWith 보존
- 실기기: 갤러리 선택 → 업로드 → 표시 (web은 image_picker 제한적 — 실기기 검증)
