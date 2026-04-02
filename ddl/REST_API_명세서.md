# REST API 명세서

> **프로젝트**: 2팀 ERP 무역관리 시스템
> **최종 수정일**: 2026-03-26
> **버전**: v1.0

---

## 목차

- [공통 사항](#공통-사항)
- [1. Auth Service (port 8011)](#1-auth-service-port-8011)
  - [1.1 인증](#11-인증)
  - [1.2 사용자 관리](#12-사용자-관리)
  - [1.3 직급 관리](#13-직급-관리)
  - [1.4 부서 관리](#14-부서-관리)
  - [1.5 회사 정보](#15-회사-정보)
- [2. Master Service (port 8012)](#2-master-service-port-8012)
  - [2.1 거래처 (Clients)](#21-거래처-clients)
  - [2.2 품목 (Items)](#22-품목-items)
  - [2.3 바이어 (Buyers)](#23-바이어-buyers)
  - [2.4 기초 마스터 데이터 (국가/통화/인코텀즈/항구/결제조건)](#24-기초-마스터-데이터-국가통화인코텀즈항구결제조건)
- [3. Activity Service (port 8013)](#3-activity-service-port-8013)
  - [3.1 활동기록 (Activities)](#31-활동기록-activities)
  - [3.2 컨택 (Contacts)](#32-컨택-contacts)
  - [3.3 메일 이력 (Email Logs)](#33-메일-이력-email-logs)
  - [3.4 활동기록 패키지 (Activity Packages)](#34-활동기록-패키지-activity-packages)
- [4. Document Service (port 8014)](#4-document-service-port-8014)
  - [4.1 PI (Proforma Invoice)](#41-pi-proforma-invoice)
  - [4.2 PO (Purchase Order)](#42-po-purchase-order)
  - [4.3 CI / PL](#43-ci--pl)
  - [4.4 생산지시서 (Production Orders)](#44-생산지시서-production-orders)
  - [4.5 출하지시서 (Shipment Orders)](#45-출하지시서-shipment-orders)
  - [4.6 출하현황 (Shipments)](#46-출하현황-shipments)
  - [4.7 매출·수금 (Collections)](#47-매출수금-collections)
  - [4.8 결재 (Approval Requests)](#48-결재-approval-requests)

---

## 공통 사항

### Base URL

| 서비스 | Base URL |
|--------|----------|
| Auth Service | `http://localhost:8011` |
| Master Service | `http://localhost:8012` |
| Activity Service | `http://localhost:8013` |
| Document Service | `http://localhost:8014` |

### 인증 방식

- **JWT Bearer Token** 방식을 사용한다.
- 로그인(`POST /api/auth/login`) 성공 시 `accessToken`과 `refreshToken`을 발급받는다.
- 인증이 필요한 모든 요청에는 아래 헤더를 포함해야 한다.

```
Authorization: Bearer {accessToken}
```

- `accessToken` 만료 시 `POST /api/auth/refresh`로 갱신한다.
- 로그인/토큰갱신 API는 인증 헤더가 필요 없다.

### 공통 요청 헤더

| 헤더 | 값 | 비고 |
|------|-----|------|
| `Content-Type` | `application/json` | 요청 본문이 있는 경우 |
| `Authorization` | `Bearer {accessToken}` | 인증 필요 API |

### 공통 에러 응답

| HTTP 상태 코드 | 설명 |
|---------------|------|
| `400 Bad Request` | 요청 파라미터 누락 또는 유효성 검증 실패 |
| `401 Unauthorized` | 인증 실패 (토큰 없음, 만료, 무효) |
| `403 Forbidden` | 권한 부족 |
| `404 Not Found` | 리소스를 찾을 수 없음 |
| `409 Conflict` | 중복 데이터 또는 비즈니스 규칙 충돌 |
| `500 Internal Server Error` | 서버 내부 오류 |

에러 응답 본문 (공통 포맷):
```json
{
  "timestamp": "2026-03-26T10:00:00",
  "status": 400,
  "error": "Bad Request",
  "message": "에러 상세 메시지"
}
```

### 열거형(Enum) 값 정의

| Enum | 값 | 설명 |
|------|----|------|
| `Role` | `admin`, `sales`, `production`, `shipping` | 사용자 역할 |
| `UserStatus` | `재직`, `휴직`, `퇴직` | 사용자 재직 상태 |
| `ClientStatus` | `활성`, `비활성` | 거래처 상태 |
| `ItemStatus` | `활성`, `비활성` | 품목 상태 |
| `ActivityType` | `미팅/협의`, `이슈`, `메모/노트`, `일정` | 활동 유형 |
| `ActivityPriority` | `높음`, `보통` | 활동 우선순위 |
| `PI/PO Status` | `초안`, `확정`, `결재대기`, `반려`, `취소`, `등록요청`, `수정요청`, `삭제요청` | PI/PO 문서 상태 |
| `ProductionOrderStatus` | `진행중`, `생산완료` | 생산지시서 상태 |
| `ShipmentOrderStatus` | `출하준비`, `출하완료` | 출하지시서 상태 |
| `ShipmentStatus` | `출하준비`, `출하완료` | 출하현황 상태 |
| `CollectionStatus` | `미수금`, `수금완료` | 수금 상태 |
| `CI/PL Status` | `발행대기`, `발행완료` | CI/PL 상태 |
| `ApprovalStatus` | `대기`, `승인`, `반려` | 결재 상태 |
| `ApprovalRequestType` | `등록요청`, `수정요청`, `삭제요청` | 결재 요청 유형 |
| `ApprovalDocumentType` | `PI`, `PO` | 결재 문서 유형 |
| `EmailStatus` | `발송`, `실패` | 이메일 상태 |

---

## 1. Auth Service (port 8011)

### 1.1 인증

#### `POST /api/auth/login` — 로그인 ✅ 구현완료

사용자 이메일과 비밀번호로 로그인하여 JWT 토큰을 발급받는다.

**요청 헤더**: 인증 불필요

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `email` | `String` | O | 사용자 이메일 |
| `password` | `String` | O | 비밀번호 |

```json
{
  "email": "user@example.com",
  "password": "password123"
}
```

**응답 `200 OK`**:

| 필드 | 타입 | 설명 |
|------|------|------|
| `accessToken` | `String` | JWT 액세스 토큰 |
| `refreshToken` | `String` | JWT 리프레시 토큰 |

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `401 Unauthorized` | 이메일/비밀번호 불일치 |
| `401 Unauthorized` | 재직(`재직`) 상태가 아닌 사용자 (휴직/퇴직) |

**비고**: `canLogin()` 메서드에 의해 `UserStatus.재직` 상태인 사용자만 로그인 가능하다.

---

#### `POST /api/auth/refresh` — 토큰 갱신 ✅ 구현완료

리프레시 토큰으로 새로운 액세스/리프레시 토큰 쌍을 발급받는다.

**요청 헤더**: 인증 불필요

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `refreshToken` | `String` | O | 기존 리프레시 토큰 |

```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**응답 `200 OK`**:

```json
{
  "accessToken": "eyJhbGciOiJIUzI1NiJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiJ9..."
}
```

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `401 Unauthorized` | 만료되었거나 무효한 리프레시 토큰 |

---

#### `POST /api/auth/logout` — 로그아웃 ✅ 구현완료

사용자의 리프레시 토큰을 무효화하여 로그아웃 처리한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `userId` | `Integer` | O | 사용자 ID |

```json
{
  "userId": 1
}
```

**응답 `200 OK`**: 본문 없음

---

### 1.2 사용자 관리

#### `GET /api/users` — 전체 사용자 조회 ✅ 구현완료

등록된 모든 사용자 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `User[]`

```json
[
  {
    "id": 1,
    "employeeNo": "EMP001",
    "name": "홍길동",
    "email": "hong@example.com",
    "role": "sales",
    "department": { "id": 1, "name": "영업1팀", "createdAt": "..." },
    "position": { "id": 2, "name": "팀원", "level": 2, "createdAt": "..." },
    "status": "재직",
    "createdAt": "2026-01-01T09:00:00",
    "updatedAt": "2026-03-20T14:30:00"
  }
]
```

---

#### `GET /api/users/{id}` — 사용자 단건 조회 ✅ 구현완료

지정한 ID의 사용자 정보를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 사용자 ID |

**응답 `200 OK`**: `User` (위 User 객체와 동일 구조)

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `404 Not Found` | 해당 ID의 사용자가 존재하지 않음 |

---

#### `POST /api/users` — 사용자 생성 ✅ 구현완료

새로운 사용자를 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `employeeNo` | `String` | O | 사번 (고유값, 최대 20자) |
| `name` | `String` | O | 이름 (최대 100자) |
| `email` | `String` | O | 이메일 (고유값, 최대 255자) |
| `password` | `String` | O | 비밀번호 |
| `role` | `String` | O | 역할 (`admin` / `sales` / `production` / `shipping`) |

```json
{
  "employeeNo": "EMP010",
  "name": "김철수",
  "email": "kim@example.com",
  "password": "securePass123",
  "role": "sales"
}
```

**응답 `201 Created`**: 생성된 `User` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 필수 필드 누락 |
| `409 Conflict` | 사번 또는 이메일 중복 |

---

#### `PUT /api/users/{id}` — 사용자 수정 ✅ 구현완료

기존 사용자의 정보를 수정한다. `null`인 필드는 변경하지 않는다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 사용자 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | `String` | - | 이름 |
| `email` | `String` | - | 이메일 |
| `departmentId` | `Integer` | - | 부서 ID |
| `positionId` | `Integer` | - | 직급 ID |

```json
{
  "name": "김철수(수정)",
  "departmentId": 2,
  "positionId": 1
}
```

**응답 `200 OK`**: 수정된 `User` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `404 Not Found` | 해당 사용자/부서/직급이 존재하지 않음 |

---

#### `PATCH /api/users/{id}` — 내 정보 수정 ✅ 구현완료

사용자가 자신의 이름, 이메일, 비밀번호를 부분 수정합니다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 사용자 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | `String` | 선택 | 변경할 이름 |
| `email` | `String` | 선택 | 변경할 이메일 |
| `pw` | `String` | 선택 | 변경할 비밀번호 (bcrypt 해싱 후 저장) |

**응답 `200 OK`**:

```json
{
  "id": 1,
  "employeeNo": "25061501",
  "name": "김영업",
  "email": "kim@salesboost.com"
}
```

**비고**: 최소 1개 이상의 필드가 포함되어야 함. 사번, 역할, 부서, 직급은 관리자만 변경 가능 (PUT 사용).

---

#### `PATCH /api/users/{id}/status` — 사용자 상태 변경 ✅ 구현완료

사용자의 재직 상태를 변경한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 사용자 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `String` | O | `재직` / `휴직` / `퇴직` |

```json
{
  "status": "휴직"
}
```

**응답 `200 OK`**: 수정된 `User` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 퇴직 상태 사용자의 상태 변경 시도 |
| `404 Not Found` | 해당 사용자가 존재하지 않음 |

**비고**: 퇴직(`퇴직`) 상태인 사용자는 상태를 변경할 수 없다. (`IllegalStateException: "퇴직한 사용자의 상태는 변경할 수 없습니다."`)

---

### 1.3 직급 관리

#### `GET /api/positions` — 전체 직급 조회 ✅ 구현완료

등록된 모든 직급 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Position[]`

```json
[
  {
    "id": 1,
    "name": "팀장",
    "level": 1,
    "createdAt": "2026-01-01T09:00:00"
  },
  {
    "id": 2,
    "name": "팀원",
    "level": 2,
    "createdAt": "2026-01-01T09:00:00"
  }
]
```

**비고**: `level`이 1인 직급은 결재 권한(`hasApprovalAuthority`)을 갖는다.

---

#### `POST /api/positions` — 직급 생성 ✅ 구현완료

새로운 직급을 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | `String` | O | 직급명 (최대 50자) |
| `level` | `int` | O | 직급 레벨 (1: 결재 권한 보유) |

```json
{
  "name": "팀장",
  "level": 1
}
```

**응답 `201 Created`**: 생성된 `Position` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 직급명이 비어있거나 null |

---

### 1.4 부서 관리

#### `GET /api/departments` — 전체 부서 조회 ✅ 구현완료

등록된 모든 부서 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Department[]`

```json
[
  {
    "id": 1,
    "name": "영업1팀",
    "createdAt": "2026-01-01T09:00:00"
  }
]
```

---

#### `POST /api/departments` — 부서 생성 ✅ 구현완료

새로운 부서를 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | `String` | O | 부서명 (최대 100자) |

```json
{
  "name": "영업2팀"
}
```

**응답 `201 Created`**: 생성된 `Department` 객체

---

#### `DELETE /api/departments/{id}` — 부서 삭제 ✅ 구현완료

지정한 ID의 부서를 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 부서 ID |

**응답 `204 No Content`**: 본문 없음

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 해당 부서에 소속된 사용자가 존재하는 경우 삭제 불가 |
| `404 Not Found` | 해당 부서가 존재하지 않음 |

---

### 1.5 회사 정보

#### `GET /api/company` — 회사 정보 조회 ✅ 구현완료

등록된 회사 정보를 조회한다. (단건 — 시스템에 회사 정보는 1건만 존재)

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Company`

```json
{
  "id": 1,
  "name": "주식회사 무역",
  "addressEn": "123 Trade St, Seoul, Korea",
  "addressKr": "서울특별시 강남구 무역로 123",
  "tel": "02-1234-5678",
  "fax": "02-1234-5679",
  "email": "info@trade.co.kr",
  "website": "https://trade.co.kr",
  "sealImageUrl": "/images/seal.png",
  "updatedAt": "2026-03-20T14:30:00"
}
```

---

#### `PUT /api/company` — 회사 정보 수정 ✅ 구현완료

회사 정보를 수정한다. `null`인 필드는 변경하지 않는다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `name` | `String` | - | 회사명 (최대 200자) |
| `addressEn` | `String` | - | 영문 주소 (최대 500자) |
| `addressKr` | `String` | - | 한글 주소 (최대 500자) |
| `tel` | `String` | - | 전화번호 (최대 50자) |
| `fax` | `String` | - | 팩스번호 (최대 50자) |
| `email` | `String` | - | 이메일 (최대 255자) |
| `website` | `String` | - | 웹사이트 URL (최대 255자) |
| `sealImageUrl` | `String` | - | 법인인감 이미지 URL (최대 500자) |

```json
{
  "name": "주식회사 글로벌무역",
  "tel": "02-9999-8888"
}
```

**응답 `200 OK`**: 수정된 `Company` 객체

---

## 2. Master Service (port 8012)

### 2.1 거래처 (Clients)

#### `GET /api/clients` — 전체 거래처 조회 ✅ 구현완료

등록된 모든 거래처 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Client[]`

```json
[
  {
    "id": 1,
    "clientCode": "CL001",
    "clientName": "ABC Trading",
    "clientNameKr": "ABC 무역",
    "country": { "id": 1, "countryCode": "US", "countryName": "United States", "countryNameKr": "미국" },
    "clientCity": "New York",
    "port": { "id": 1, "portCode": "USNYC", "portName": "New York Port", "portCity": "New York" },
    "clientAddress": "123 Trade Ave, NY",
    "clientTel": "+1-212-555-0100",
    "clientEmail": "abc@trading.com",
    "paymentTerm": { "id": 1, "paymentTermCode": "TT30", "paymentTermName": "T/T 30 Days" },
    "currency": { "id": 1, "currencyCode": "USD", "currencyName": "US Dollar", "currencySymbol": "$" },
    "clientManager": "홍길동",
    "departmentId": 1,
    "clientStatus": "활성",
    "clientRegDate": "2026-01-15",
    "createdAt": "2026-01-15T09:00:00",
    "updatedAt": "2026-03-20T14:30:00"
  }
]
```

---

#### `GET /api/clients/{id}` — 거래처 단건 조회 ✅ 구현완료

지정한 ID의 거래처 정보를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 거래처 ID |

**응답 `200 OK`**: `Client` (위 객체와 동일 구조)

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `404 Not Found` | 해당 거래처가 존재하지 않음 |

---

#### `GET /api/clients/department/{departmentId}` — 부서별 거래처 조회 ✅ 구현완료

지정한 부서에 배정된 거래처 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `departmentId` | `Integer` | 부서 ID |

**응답 `200 OK`**: `Client[]`

---

#### `POST /api/clients` — 거래처 생성 ✅ 구현완료

새로운 거래처를 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `clientCode` | `String` | O | 거래처 코드 (고유값, 최대 20자) |
| `clientName` | `String` | O | 거래처 영문명 (최대 100자) |
| `clientNameKr` | `String` | - | 거래처 한글명 (최대 100자) |
| `countryId` | `Integer` | - | 국가 ID (FK) |
| `clientCity` | `String` | - | 도시 (최대 100자) |
| `portId` | `Integer` | - | 항구 ID (FK) |
| `clientAddress` | `String` | - | 주소 |
| `clientTel` | `String` | - | 전화번호 (최대 50자) |
| `clientEmail` | `String` | - | 이메일 (최대 255자) |
| `paymentTermId` | `Integer` | - | 결제조건 ID (FK) |
| `currencyId` | `Integer` | - | 통화 ID (FK) |
| `clientManager` | `String` | - | 담당자명 (최대 100자) |
| `departmentId` | `Integer` | - | 담당 부서 ID |
| `clientRegDate` | `String (date)` | - | 등록일 (YYYY-MM-DD) |

```json
{
  "clientCode": "CL002",
  "clientName": "XYZ Corp",
  "clientNameKr": "XYZ 주식회사",
  "countryId": 1,
  "clientCity": "London",
  "portId": 2,
  "clientAddress": "456 Export Rd, London",
  "clientTel": "+44-20-1234-5678",
  "clientEmail": "info@xyz.com",
  "paymentTermId": 1,
  "currencyId": 2,
  "clientManager": "김영희",
  "departmentId": 1,
  "clientRegDate": "2026-03-26"
}
```

**응답 `201 Created`**: 생성된 `Client` 객체

**비고**: 생성 시 `clientStatus`는 자동으로 `활성`으로 설정된다.

---

#### `PUT /api/clients/{id}` — 거래처 수정 ✅ 구현완료

기존 거래처 정보를 수정한다. `null`인 필드는 변경하지 않는다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 거래처 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `clientName` | `String` | - | 거래처 영문명 |
| `clientNameKr` | `String` | - | 거래처 한글명 |
| `countryId` | `Integer` | - | 국가 ID |
| `clientCity` | `String` | - | 도시 |
| `portId` | `Integer` | - | 항구 ID |
| `clientAddress` | `String` | - | 주소 |
| `clientTel` | `String` | - | 전화번호 |
| `clientEmail` | `String` | - | 이메일 |
| `paymentTermId` | `Integer` | - | 결제조건 ID |
| `currencyId` | `Integer` | - | 통화 ID |
| `clientManager` | `String` | - | 담당자명 |
| `departmentId` | `Integer` | - | 담당 부서 ID |

**응답 `200 OK`**: 수정된 `Client` 객체

---

#### `PATCH /api/clients/{id}/status` — 거래처 상태 변경 ✅ 구현완료

거래처의 활성/비활성 상태를 변경한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 거래처 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `String` | O | `활성` / `비활성` |

```json
{
  "status": "비활성"
}
```

**응답 `200 OK`**: 수정된 `Client` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 현재 상태와 동일한 상태로 변경 시도 (`"이미 {상태} 상태입니다."`) |

---

### 2.2 품목 (Items)

#### `GET /api/items` — 전체 품목 조회 ✅ 구현완료

등록된 모든 품목 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Item[]`

```json
[
  {
    "id": 1,
    "itemCode": "ITM001",
    "itemName": "Steel Pipe",
    "itemNameKr": "강관",
    "itemSpec": "OD 100mm x 6m",
    "itemUnit": "EA",
    "itemPackUnit": "BUNDLE",
    "itemUnitPrice": 150.00,
    "itemWeight": 25.500,
    "itemHsCode": "7304.19",
    "itemCategory": "철강",
    "itemStatus": "활성",
    "itemRegDate": "2026-01-10",
    "createdAt": "2026-01-10T09:00:00",
    "updatedAt": "2026-03-20T14:30:00"
  }
]
```

---

#### `GET /api/items/{id}` — 품목 단건 조회 ✅ 구현완료

지정한 ID의 품목 정보를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 품목 ID |

**응답 `200 OK`**: `Item` (위 객체와 동일 구조)

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `404 Not Found` | 해당 품목이 존재하지 않음 |

---

#### `POST /api/items` — 품목 생성 ✅ 구현완료

새로운 품목을 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `itemCode` | `String` | O | 품목 코드 (고유값, 최대 50자) |
| `itemName` | `String` | O | 품목 영문명 (최대 100자) |
| `itemNameKr` | `String` | - | 품목 한글명 (최대 100자) |
| `itemSpec` | `String` | - | 규격 (최대 200자) |
| `itemUnit` | `String` | - | 단위 (최대 50자, 예: EA, KG) |
| `itemPackUnit` | `String` | - | 포장 단위 (최대 50자, 예: BOX, PALLET) |
| `itemUnitPrice` | `BigDecimal` | - | 단가 (소수점 2자리) |
| `itemWeight` | `BigDecimal` | - | 중량 (소수점 3자리) |
| `itemHsCode` | `String` | - | HS Code (최대 20자) |
| `itemCategory` | `String` | - | 카테고리 (최대 100자) |
| `itemRegDate` | `String (date)` | - | 등록일 (YYYY-MM-DD) |

```json
{
  "itemCode": "ITM002",
  "itemName": "Copper Wire",
  "itemNameKr": "동선",
  "itemSpec": "0.5mm",
  "itemUnit": "KG",
  "itemPackUnit": "COIL",
  "itemUnitPrice": 8.50,
  "itemWeight": 1.000,
  "itemHsCode": "7408.11",
  "itemCategory": "비철금속",
  "itemRegDate": "2026-03-26"
}
```

**응답 `201 Created`**: 생성된 `Item` 객체

**비고**: 생성 시 `itemStatus`는 자동으로 `활성`으로 설정된다.

---

#### `PUT /api/items/{id}` — 품목 수정 ✅ 구현완료

기존 품목 정보를 수정한다. `null`인 필드는 변경하지 않는다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 품목 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `itemName` | `String` | - | 품목 영문명 |
| `itemNameKr` | `String` | - | 품목 한글명 |
| `itemSpec` | `String` | - | 규격 |
| `itemUnit` | `String` | - | 단위 |
| `itemPackUnit` | `String` | - | 포장 단위 |
| `itemUnitPrice` | `BigDecimal` | - | 단가 |
| `itemWeight` | `BigDecimal` | - | 중량 |
| `itemHsCode` | `String` | - | HS Code |
| `itemCategory` | `String` | - | 카테고리 |

**응답 `200 OK`**: 수정된 `Item` 객체

---

#### `PATCH /api/items/{id}/status` — 품목 상태 변경 ✅ 구현완료

품목의 활성/비활성 상태를 변경한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 품목 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `String` | O | `활성` / `비활성` |

```json
{
  "status": "비활성"
}
```

**응답 `200 OK`**: 수정된 `Item` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 현재 상태와 동일한 상태로 변경 시도 |

---

### 2.3 바이어 (Buyers)

#### `GET /api/buyers` — 전체 바이어 조회 ✅ 구현완료

등록된 모든 바이어(거래처 담당자) 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Buyer[]`

```json
[
  {
    "id": 1,
    "client": { "id": 1, "clientCode": "CL001", "clientName": "ABC Trading", "..." : "..." },
    "buyerName": "John Smith",
    "buyerPosition": "Purchasing Manager",
    "buyerEmail": "john@abctrading.com",
    "buyerTel": "+1-212-555-0101",
    "createdAt": "2026-01-20T09:00:00",
    "updatedAt": "2026-03-20T14:30:00"
  }
]
```

---

#### `GET /api/buyers/{id}` — 바이어 단건 조회 ✅ 구현완료

지정한 ID의 바이어 정보를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 바이어 ID |

**응답 `200 OK`**: `Buyer` (위 객체와 동일 구조)

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `404 Not Found` | 해당 바이어가 존재하지 않음 |

---

#### `GET /api/buyers/client/{clientId}` — 거래처별 바이어 조회 ✅ 구현완료

지정한 거래처에 소속된 바이어 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `clientId` | `Integer` | 거래처 ID |

**응답 `200 OK`**: `Buyer[]`

---

#### `POST /api/buyers` — 바이어 생성 ✅ 구현완료

새로운 바이어를 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `clientId` | `Integer` | O | 소속 거래처 ID |
| `buyerName` | `String` | O | 바이어명 (최대 100자) |
| `buyerPosition` | `String` | - | 직책 (최대 100자) |
| `buyerEmail` | `String` | - | 이메일 (최대 255자) |
| `buyerTel` | `String` | - | 전화번호 (최대 50자) |

```json
{
  "clientId": 1,
  "buyerName": "Jane Doe",
  "buyerPosition": "Sales Director",
  "buyerEmail": "jane@abctrading.com",
  "buyerTel": "+1-212-555-0102"
}
```

**응답 `201 Created`**: 생성된 `Buyer` 객체

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `400 Bad Request` | 거래처(clientId)가 null |
| `404 Not Found` | 해당 거래처가 존재하지 않음 |

---

#### `PUT /api/buyers/{id}` — 바이어 수정 ✅ 구현완료

기존 바이어 정보를 수정한다. `null`인 필드는 변경하지 않는다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 바이어 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `buyerName` | `String` | - | 바이어명 |
| `buyerPosition` | `String` | - | 직책 |
| `buyerEmail` | `String` | - | 이메일 |
| `buyerTel` | `String` | - | 전화번호 |

**응답 `200 OK`**: 수정된 `Buyer` 객체

---

#### `DELETE /api/buyers/{id}` — 바이어 삭제 ✅ 구현완료

지정한 ID의 바이어를 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 바이어 ID |

**응답 `204 No Content`**: 본문 없음

**에러 응답**:

| 상태 코드 | 조건 |
|-----------|------|
| `404 Not Found` | 해당 바이어가 존재하지 않음 |

---

### 2.4 기초 마스터 데이터 (국가/통화/인코텀즈/항구/결제조건)

아래 5개 리소스는 동일한 CRUD 패턴을 따른다. 모든 요청에 `Authorization: Bearer {accessToken}` 헤더가 필요하다.

#### 공통 엔드포인트 패턴 ✅ 구현완료

| 메서드 | 경로 | 설명 | 응답 코드 |
|--------|------|------|-----------|
| `GET` | `/api/{resource}` | 전체 조회 | `200 OK` |
| `GET` | `/api/{resource}/{id}` | 단건 조회 | `200 OK` / `404` |
| `POST` | `/api/{resource}` | 생성 | `201 Created` |
| `PUT` | `/api/{resource}/{id}` | 수정 | `200 OK` / `404` |
| `DELETE` | `/api/{resource}/{id}` | 삭제 | `200 OK` / `404` |

#### 2.4.1 국가 (Countries) — `/api/countries`

**엔티티 필드**:

| 필드 | 타입 | DB 컬럼 | 필수(생성) | 설명 |
|------|------|---------|-----------|------|
| `id` | `Integer` | `country_id` | - | PK, 자동 생성 |
| `countryCode` | `String` | `country_code` | O | 국가 코드 (고유값, 최대 10자, 예: US, KR) |
| `countryName` | `String` | `country_name` | O | 국가 영문명 (최대 100자) |
| `countryNameKr` | `String` | `country_name_kr` | - | 국가 한글명 (최대 100자) |

**생성/수정 요청 예시**:
```json
{
  "countryCode": "US",
  "countryName": "United States",
  "countryNameKr": "미국"
}
```

---

#### 2.4.2 통화 (Currencies) — `/api/currencies`

**엔티티 필드**:

| 필드 | 타입 | DB 컬럼 | 필수(생성) | 설명 |
|------|------|---------|-----------|------|
| `id` | `Integer` | `currency_id` | - | PK, 자동 생성 |
| `currencyCode` | `String` | `currency_code` | O | 통화 코드 (고유값, 최대 10자, 예: USD, KRW) |
| `currencyName` | `String` | `currency_name` | O | 통화명 (최대 100자) |
| `currencySymbol` | `String` | `currency_symbol` | - | 통화 기호 (최대 5자, 예: $, ₩) |

**생성/수정 요청 예시**:
```json
{
  "currencyCode": "USD",
  "currencyName": "US Dollar",
  "currencySymbol": "$"
}
```

---

#### 2.4.3 인코텀즈 (Incoterms) — `/api/incoterms`

**엔티티 필드**:

| 필드 | 타입 | DB 컬럼 | 필수(생성) | 설명 |
|------|------|---------|-----------|------|
| `id` | `Integer` | `incoterm_id` | - | PK, 자동 생성 |
| `incotermCode` | `String` | `incoterm_code` | O | 인코텀 코드 (고유값, 최대 10자, 예: FOB, CIF) |
| `incotermName` | `String` | `incoterm_name` | O | 인코텀 영문명 (최대 200자) |
| `incotermNameKr` | `String` | `incoterm_name_kr` | - | 인코텀 한글명 (최대 200자) |
| `incotermDescription` | `String` | `incoterm_description` | - | 설명 (TEXT) |
| `incotermTransportMode` | `String` | `incoterm_transport_mode` | - | 운송 수단 (최대 50자) |
| `incotermSellerSegments` | `String` | `incoterm_seller_segments` | - | 매도인 부담 구간 (최대 50자) |
| `incotermDefaultNamedPlace` | `String` | `incoterm_default_named_place` | - | 기본 지정 장소 (최대 100자) |

**생성/수정 요청 예시**:
```json
{
  "incotermCode": "FOB",
  "incotermName": "Free on Board",
  "incotermNameKr": "본선인도조건",
  "incotermDescription": "매도인이 지정 선적항에서 물품을 본선에 적재할 때 위험 이전",
  "incotermTransportMode": "해상/내수로",
  "incotermSellerSegments": "선적항 본선 난간",
  "incotermDefaultNamedPlace": "선적항"
}
```

---

#### 2.4.4 항구 (Ports) — `/api/ports`

**엔티티 필드**:

| 필드 | 타입 | DB 컬럼 | 필수(생성) | 설명 |
|------|------|---------|-----------|------|
| `id` | `Integer` | `port_id` | - | PK, 자동 생성 |
| `portCode` | `String` | `port_code` | O | 항구 코드 (고유값, 최대 20자, 예: KRPUS) |
| `portName` | `String` | `port_name` | O | 항구명 (최대 100자) |
| `portCity` | `String` | `port_city` | - | 도시 (최대 100자) |
| `countryId` | `Integer` | `country_id` | O | 국가 ID (FK → countries) |

**생성/수정 요청 예시**:
```json
{
  "portCode": "KRPUS",
  "portName": "Busan Port",
  "portCity": "Busan",
  "countryId": 2
}
```

**응답 시 `country` 객체가 포함됨**:
```json
{
  "id": 1,
  "portCode": "KRPUS",
  "portName": "Busan Port",
  "portCity": "Busan",
  "country": { "id": 2, "countryCode": "KR", "countryName": "South Korea", "countryNameKr": "대한민국" }
}
```

---

#### 2.4.5 결제조건 (Payment Terms) — `/api/payment-terms`

**엔티티 필드**:

| 필드 | 타입 | DB 컬럼 | 필수(생성) | 설명 |
|------|------|---------|-----------|------|
| `id` | `Integer` | `payment_term_id` | - | PK, 자동 생성 |
| `paymentTermCode` | `String` | `payment_term_code` | O | 결제조건 코드 (고유값, 최대 20자) |
| `paymentTermName` | `String` | `payment_term_name` | O | 결제조건명 (최대 100자) |
| `paymentTermDescription` | `String` | `payment_term_description` | - | 설명 (최대 200자) |

**생성/수정 요청 예시**:
```json
{
  "paymentTermCode": "TT30",
  "paymentTermName": "T/T 30 Days",
  "paymentTermDescription": "선적 후 30일 이내 전신환 송금"
}
```

---

## 3. Activity Service (port 8013)

> **상태**: 🔲 구현예정 — 아래 명세는 프론트엔드 Mock 데이터 기준 설계안이며, 구현 시 변경될 수 있다.

### 3.1 활동기록 (Activities)

#### `GET /api/activities` — 전체 활동기록 조회 🔲 구현예정

등록된 모든 활동기록 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Activity[]`

```json
[
  {
    "id": 1,
    "clientId": 1,
    "poId": null,
    "type": "이슈",
    "title": "신규 거래 문의",
    "content": "ABC Trading 신규 거래 관련 통화",
    "priority": "높음",
    "scheduleFrom": "2026-03-26T09:00:00",
    "scheduleTo": "2026-03-26T10:00:00",
    "authorId": 1,
    "createdAt": "2026-03-26T09:00:00",
    "updatedAt": "2026-03-26T09:00:00"
  }
]
```

---

#### `POST /api/activities` — 활동기록 생성 🔲 구현예정

새로운 활동기록을 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `clientId` | `Integer` | O | 거래처 ID |
| `poId` | `String` | - | PO ID (연관 주문이 있는 경우, 예: "PO2025001") |
| `type` | `String` | O | 활동 유형 (`미팅/협의` / `이슈` / `메모/노트` / `일정`) |
| `title` | `String` | O | 활동 제목 |
| `content` | `String` | - | 활동 내용 |
| `priority` | `String` | - | 우선순위 (`높음` / `보통`) |
| `scheduleFrom` | `String (datetime)` | - | 일정 시작일시 (ISO 8601) |
| `scheduleTo` | `String (datetime)` | - | 일정 종료일시 (ISO 8601) |
| `authorId` | `Integer` | O | 작성자(사용자) ID |

```json
{
  "clientId": 1,
  "poId": null,
  "type": "미팅/협의",
  "title": "분기 실적 미팅",
  "content": "2026년 1분기 실적 리뷰 및 2분기 계획 논의",
  "priority": "높음",
  "scheduleFrom": "2026-04-01T14:00:00",
  "scheduleTo": "2026-04-01T15:30:00",
  "authorId": 1
}
```

**응답 `201 Created`**: 생성된 `Activity` 객체

---

#### `PUT /api/activities/{id}` — 활동기록 수정 🔲 구현예정

기존 활동기록을 수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 활동기록 ID |

**요청 본문**: 생성과 동일 구조 (수정할 필드만 포함)

**응답 `200 OK`**: 수정된 `Activity` 객체

---

#### `DELETE /api/activities/{id}` — 활동기록 삭제 🔲 구현예정

지정한 ID의 활동기록을 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 활동기록 ID |

**응답 `204 No Content`**: 본문 없음

---

### 3.2 컨택 (Contacts)

#### `GET /api/contacts` — 전체 컨택 조회 🔲 구현예정

등록된 모든 컨택(외부 연락처) 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Contact[]`

```json
[
  {
    "id": 1,
    "clientId": 1,
    "name": "John Smith",
    "position": "Purchasing Manager",
    "email": "john@abctrading.com",
    "tel": "+1-212-555-0101",
    "writerId": 1,
    "createdAt": "2026-01-20T09:00:00",
    "updatedAt": "2026-01-20T09:00:00"
  }
]
```

---

#### `POST /api/contacts` — 컨택 생성 🔲 구현예정

새로운 컨택을 등록한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `clientId` | `Integer` | O | 거래처 ID |
| `name` | `String` | O | 이름 |
| `position` | `String` | - | 직책 |
| `email` | `String` | - | 이메일 |
| `tel` | `String` | - | 전화번호 |
| `writerId` | `Integer` | O | 등록자(사용자) ID |

```json
{
  "clientId": 1,
  "name": "Jane Doe",
  "position": "Sales Director",
  "email": "jane@abctrading.com",
  "tel": "+1-212-555-0102",
  "writerId": 1
}
```

**응답 `201 Created`**: 생성된 `Contact` 객체

---

#### `PUT /api/contacts/{id}` — 컨택 수정 🔲 구현예정

기존 컨택 정보를 수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 컨택 ID |

**요청 본문**: 생성과 동일 구조

**응답 `200 OK`**: 수정된 `Contact` 객체

---

#### `DELETE /api/contacts/{id}` — 컨택 삭제 🔲 구현예정

지정한 ID의 컨택을 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 컨택 ID |

**응답 `204 No Content`**: 본문 없음

---

### 3.3 메일 이력 (Email Logs)

#### `GET /api/email-logs` — 메일 이력 조회 🔲 구현예정

시스템에서 발송된 메일 이력을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `EmailLog[]`

```json
[
  {
    "id": 1,
    "sender": "user@company.com",
    "recipient": "buyer@client.com",
    "subject": "PI-2026-001 Proforma Invoice",
    "sentAt": "2026-03-20T14:30:00",
    "status": "발송"
  }
]
```

---

### 3.4 활동기록 패키지 (Activity Packages)

#### `GET /api/activity-packages` — 전체 패키지 조회 🔲 구현예정

등록된 모든 활동기록 패키지 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `ActivityPackage[]`

```json
[
  {
    "packageId": 1,
    "title": "2025년 1월 영업활동 보고",
    "description": "1월 주요 거래처 미팅 및 이슈 정리",
    "poId": "PO2025001",
    "creatorId": 3,
    "creatorName": "박영업",
    "activityIds": [1, 2, 3],
    "viewers": [5, 7, 8],
    "viewerNames": ["최생산", "정출하", "관리자"],
    "createdAt": "2025/03/20",
    "updatedAt": "2025/03/20"
  }
]
```

---

#### `GET /api/activity-packages/{id}` — 패키지 단건 조회 🔲 구현예정

지정한 ID의 활동기록 패키지를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 패키지 ID |

**응답 `200 OK`**: `ActivityPackage`

```json
{
  "packageId": 1,
  "title": "2025년 1월 영업활동 보고",
  "description": "1월 주요 거래처 미팅 및 이슈 정리",
  "poId": "PO2025001",
  "creatorId": 3,
  "creatorName": "박영업",
  "activityIds": [1, 2, 3],
  "viewers": [5, 7, 8],
  "viewerNames": ["최생산", "정출하", "관리자"],
  "createdAt": "2025/03/20",
  "updatedAt": "2025/03/20"
}
```

---

#### `POST /api/activity-packages` — 패키지 생성 🔲 구현예정

새로운 활동기록 패키지를 생성한다. 여러 활동기록을 묶어서 공유할 수 있다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `title` | `String` | O | 패키지 제목 |
| `description` | `String` | - | 설명 |
| `poId` | `String` | - | 관련 PO ID (예: "PO2025001") |
| `creatorId` | `Integer` | O | 생성자(사용자) ID |
| `activityIds` | `Integer[]` | O | 포함할 활동기록 ID 목록 |
| `viewers` | `Integer[]` | - | 열람 가능한 사용자 ID 목록 |

```json
{
  "title": "XYZ Corp 거래 활동 요약",
  "description": "PO-2026-005 관련 활동 정리",
  "poId": "PO2025005",
  "creatorId": 1,
  "activityIds": [10, 11, 12],
  "viewers": [1, 2, 3]
}
```

**응답 `201 Created`**: 생성된 `ActivityPackage` 객체

---

#### `PUT /api/activity-packages/{id}` — 패키지 수정 🔲 구현예정

기존 활동기록 패키지를 수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 패키지 ID |

**요청 본문**: 생성과 동일 구조

**응답 `200 OK`**: 수정된 `ActivityPackage` 객체

---

#### `DELETE /api/activity-packages/{id}` — 패키지 삭제 🔲 구현예정

지정한 ID의 활동기록 패키지를 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 패키지 ID |

**응답 `204 No Content`**: 본문 없음

---

## 4. Document Service (port 8014)

> **상태**: 🔲 구현예정 — 아래 명세는 프론트엔드 Mock 데이터 기준 설계안이며, 구현 시 변경될 수 있다.

### 4.1 PI (Proforma Invoice)

#### `GET /api/pi` — PI 목록 조회 🔲 구현예정

등록된 모든 Proforma Invoice 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `PI[]`

```json
[
  {
    "id": 1,
    "piNo": "PI-2026-001",
    "clientId": 1,
    "clientName": "ABC Trading",
    "incotermId": 1,
    "currencyId": 1,
    "piDate": "2026-03-01",
    "piValidDate": "2026-04-01",
    "totalAmount": 15000.00,
    "status": "초안",
    "items": [
      {
        "itemId": 1,
        "itemName": "Steel Pipe",
        "qty": 100,
        "unitPrice": 150.00,
        "amount": 15000.00
      }
    ],
    "createdAt": "2026-03-01T09:00:00",
    "updatedAt": "2026-03-01T09:00:00"
  }
]
```

---

#### `GET /api/pi/{id}` — PI 단건 조회 🔲 구현예정

지정한 ID의 PI를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | PI ID |

**응답 `200 OK`**: `PI` (위 객체와 동일 구조)

---

#### `POST /api/pi` — PI 생성 🔲 구현예정

새로운 PI를 생성한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `clientId` | `Integer` | O | 거래처 ID |
| `incotermId` | `Integer` | - | 인코텀즈 ID |
| `currencyId` | `Integer` | - | 통화 ID |
| `managerId` | `Integer` | O | 담당자 user_id |
| `piDate` | `String (date)` | O | PI 발행일 |
| `piValidDate` | `String (date)` | - | 유효기한 |
| `items` | `Array` | O | 품목 목록 (아래 참조) |

**items 배열 요소**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `itemId` | `Integer` | O | 품목 ID |
| `qty` | `Integer` | O | 수량 |
| `unitPrice` | `BigDecimal` | O | 단가 |

**응답 `201 Created`**: 생성된 `PI` 객체

---

#### `PUT /api/pi/{id}` — PI 수정 🔲 구현예정

기존 PI를 수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | PI ID |

**요청 본문**: 생성과 동일 구조

**응답 `200 OK`**: 수정된 `PI` 객체

---

#### `DELETE /api/pi/{id}` — PI 삭제 🔲 구현예정

지정한 ID의 PI를 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | PI ID |

**응답 `204 No Content`**: 본문 없음

**비고**: PO가 연결된 PI는 삭제할 수 없다.

---

### 4.2 PO (Purchase Order)

#### `GET /api/po` — PO 목록 조회 🔲 구현예정

등록된 모든 Purchase Order 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `PO[]`

```json
[
  {
    "id": 1,
    "poNo": "PO-2026-001",
    "piId": "PI2025001",
    "clientId": 1,
    "clientName": "ABC Trading",
    "poDate": "2026-03-05",
    "deliveryDate": "2026-05-01",
    "totalAmount": 15000.00,
    "status": "확정",
    "items": [],
    "createdAt": "2026-03-05T09:00:00",
    "updatedAt": "2026-03-05T09:00:00"
  }
]
```

---

#### `GET /api/po/{id}` — PO 단건 조회 🔲 구현예정

지정한 ID의 PO를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | PO ID |

**응답 `200 OK`**: `PO` (위 객체와 동일 구조)

---

#### `POST /api/po` — PO 생성 🔲 구현예정

새로운 PO를 생성한다. PI를 기반으로 생성할 수 있다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `piId` | `String` | - | 참조 PI ID (예: "PI2025001") |
| `clientId` | `Integer` | O | 거래처 ID |
| `managerId` | `Integer` | O | 담당자 user_id |
| `poDate` | `String (date)` | O | PO 발행일 |
| `deliveryDate` | `String (date)` | - | 납기일 |
| `items` | `Array` | O | 품목 목록 |

**응답 `201 Created`**: 생성된 `PO` 객체

---

#### `PUT /api/po/{id}` — PO 수정 🔲 구현예정

기존 PO를 수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | PO ID |

**요청 본문**: 생성과 동일 구조

**응답 `200 OK`**: 수정된 `PO` 객체

---

#### `DELETE /api/po/{id}` — PO 삭제 🔲 구현예정

지정한 ID의 PO를 삭제한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | PO ID |

**응답 `204 No Content`**: 본문 없음

**비고**: 생산지시서가 발행된 PO는 삭제할 수 없다.

---

### 4.3 CI / PL

#### CI (Commercial Invoice)

| 메서드 | 경로 | 설명 | 상태 |
|--------|------|------|------|
| `GET` | `/api/ci` | CI 목록 조회 | 🔲 구현예정 |
| `GET` | `/api/ci/{id}` | CI 단건 조회 | 🔲 구현예정 |
| `POST` | `/api/ci` | CI 생성 | 🔲 구현예정 |
| `PUT` | `/api/ci/{id}` | CI 수정 | 🔲 구현예정 |

**CI 응답 예시**:

```json
{
  "id": 1,
  "ciNo": "CI-2026-001",
  "poId": "PO2025001",
  "clientId": 1,
  "ciDate": "2026-04-15",
  "totalAmount": 15000.00,
  "items": [],
  "createdAt": "2026-04-15T09:00:00",
  "updatedAt": "2026-04-15T09:00:00"
}
```

**비고**: CI는 PO를 기반으로 생성하며, 실제 선적된 물품에 대한 상업 송장이다.

---

#### PL (Packing List)

| 메서드 | 경로 | 설명 | 상태 |
|--------|------|------|------|
| `GET` | `/api/pl` | PL 목록 조회 | 🔲 구현예정 |
| `GET` | `/api/pl/{id}` | PL 단건 조회 | 🔲 구현예정 |
| `POST` | `/api/pl` | PL 생성 | 🔲 구현예정 |
| `PUT` | `/api/pl/{id}` | PL 수정 | 🔲 구현예정 |

**PL 응답 예시**:

```json
{
  "id": 1,
  "plNo": "PL-2026-001",
  "ciId": "CI2025001",
  "poId": "PO2025001",
  "plDate": "2026-04-15",
  "totalWeight": 2550.000,
  "totalPackages": 10,
  "items": [],
  "createdAt": "2026-04-15T09:00:00",
  "updatedAt": "2026-04-15T09:00:00"
}
```

**비고**: PL은 CI와 연동하여 포장 상세(중량, 수량, 포장 방법 등)를 기록한다.

---

### 4.4 생산지시서 (Production Orders)

#### `GET /api/production-orders` — 생산지시서 목록 조회 🔲 구현예정

등록된 모든 생산지시서 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `ProductionOrder[]`

```json
[
  {
    "id": 1,
    "productionOrderNo": "PRD-2026-001",
    "poId": "PO2025001",
    "poNo": "PO-2026-001",
    "orderDate": "2026-03-10",
    "dueDate": "2026-04-10",
    "status": "진행중",
    "items": [],
    "createdAt": "2026-03-10T09:00:00",
    "updatedAt": "2026-03-15T14:00:00"
  }
]
```

---

#### `GET /api/production-orders/{id}` — 생산지시서 단건 조회 🔲 구현예정

지정한 ID의 생산지시서를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 생산지시서 ID |

**응답 `200 OK`**: `ProductionOrder` (위 객체와 동일 구조)

---

#### `POST /api/production-orders` — 생산지시서 생성 🔲 구현예정

PO를 기반으로 생산지시서를 생성한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `poId` | `String` | O | PO ID (예: "PO2025001") |
| `managerId` | `Integer` | O | 담당자 user_id |
| `orderDate` | `String (date)` | O | 지시일 |
| `dueDate` | `String (date)` | O | 납기일 |
| `items` | `Array` | O | 생산 품목 목록 |

**응답 `201 Created`**: 생성된 `ProductionOrder` 객체

---

#### `PUT /api/production-orders/{id}` — 생산지시서 수정 🔲 구현예정

기존 생산지시서를 수정한다. 상태 변경을 포함한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 생산지시서 ID |

**요청 본문**: 생성과 동일 구조 + `status` 필드

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `String` | - | 상태 (`진행중` / `생산완료`) |

**응답 `200 OK`**: 수정된 `ProductionOrder` 객체

---

### 4.5 출하지시서 (Shipment Orders)

#### `GET /api/shipment-orders` — 출하지시서 목록 조회 🔲 구현예정

등록된 모든 출하지시서 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `ShipmentOrder[]`

```json
[
  {
    "id": 1,
    "shipmentOrderNo": "SO-2026-001",
    "poId": "PO2025001",
    "poNo": "PO-2026-001",
    "shipmentDate": "2026-04-20",
    "portOfLoadingId": 1,
    "portOfDischargeId": 2,
    "status": "출하준비",
    "items": [],
    "createdAt": "2026-04-15T09:00:00",
    "updatedAt": "2026-04-15T09:00:00"
  }
]
```

---

#### `GET /api/shipment-orders/{id}` — 출하지시서 단건 조회 🔲 구현예정

지정한 ID의 출하지시서를 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 출하지시서 ID |

**응답 `200 OK`**: `ShipmentOrder` (위 객체와 동일 구조)

---

#### `POST /api/shipment-orders` — 출하지시서 생성 🔲 구현예정

새로운 출하지시서를 생성한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `poId` | `String` | O | PO ID (예: "PO2025001") |
| `managerId` | `Integer` | O | 담당자 user_id |
| `shipmentDate` | `String (date)` | O | 출하 예정일 |
| `portOfLoadingId` | `Integer` | - | 선적항 ID |
| `portOfDischargeId` | `Integer` | - | 양륙항 ID |
| `items` | `Array` | O | 출하 품목 목록 |

**응답 `201 Created`**: 생성된 `ShipmentOrder` 객체

---

#### `PUT /api/shipment-orders/{id}` — 출하지시서 수정 🔲 구현예정

기존 출하지시서를 수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 출하지시서 ID |

**요청 본문**: 생성과 동일 구조

**응답 `200 OK`**: 수정된 `ShipmentOrder` 객체

---

### 4.6 출하현황 (Shipments)

#### `GET /api/shipments` — 출하현황 목록 조회 🔲 구현예정

전체 출하현황 목록을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Shipment[]`

```json
[
  {
    "id": 1,
    "shipmentOrderId": 1,
    "shipmentNo": "SHP-2026-001",
    "blNo": "BL20260420001",
    "vesselName": "EVER GIVEN",
    "etd": "2026-04-20",
    "eta": "2026-05-10",
    "status": "출하준비",
    "createdAt": "2026-04-20T09:00:00",
    "updatedAt": "2026-04-25T14:00:00"
  }
]
```

---

#### `GET /api/shipments/{id}` — 출하현황 단건 조회 🔲 구현예정

지정한 ID의 출하현황을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 출하 ID |

**응답 `200 OK`**: `Shipment` (위 객체와 동일 구조)

---

#### `PUT /api/shipments/{id}` — 출하 상태 변경 🔲 구현예정

출하현황의 상태를 변경한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 출하 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `String` | O | 상태 (`출하준비` / `출하완료`) |
| `blNo` | `String` | - | B/L 번호 |
| `vesselName` | `String` | - | 선박명 |
| `etd` | `String (date)` | - | 출항 예정일 |
| `eta` | `String (date)` | - | 도착 예정일 |

**응답 `200 OK`**: 수정된 `Shipment` 객체

---

### 4.7 매출·수금 (Collections)

#### `GET /api/collections` — 매출·수금 현황 조회 🔲 구현예정

전체 매출 및 수금 현황을 조회한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**응답 `200 OK`**: `Collection[]`

```json
[
  {
    "id": 1,
    "poId": "PO2025001",
    "poNo": "PO-2026-001",
    "clientId": 1,
    "clientName": "ABC Trading",
    "totalAmount": 15000.00,
    "collectedAmount": 10000.00,
    "remainingAmount": 5000.00,
    "currencyCode": "USD",
    "status": "미수금",
    "collectionDate": "2026-05-15",
    "createdAt": "2026-03-05T09:00:00",
    "updatedAt": "2026-05-15T14:00:00"
  }
]
```

---

#### `PUT /api/collections/{id}` — 수금 처리 🔲 구현예정

수금 내역을 등록/수정한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 수금 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `collectedAmount` | `BigDecimal` | O | 수금 금액 |
| `collectionDate` | `String (date)` | O | 수금일 |
| `note` | `String` | - | 비고 |

```json
{
  "collectedAmount": 5000.00,
  "collectionDate": "2026-06-01",
  "note": "2차 잔금 입금"
}
```

**응답 `200 OK`**: 수정된 `Collection` 객체

**비고**: `collectedAmount`가 `totalAmount`에 도달하면 `status`가 자동으로 `수금완료`로 변경된다.

---

### 4.8 결재 (Approval Requests)

#### `POST /api/approval-requests` — 결재 요청 생성 🔲 구현예정

문서(PI, PO 등)에 대한 결재 요청을 생성한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `documentType` | `String` | O | 문서 유형 (`PI` / `PO`) |
| `documentId` | `String` | O | 문서 ID (예: "PI2025001", "PO2025001") |
| `requesterId` | `Integer` | O | 요청자(사용자) ID |
| `approverId` | `Integer` | O | 결재자(사용자) ID |
| `comment` | `String` | - | 요청 사유 |

```json
{
  "documentType": "PI",
  "documentId": "PI2025001",
  "requesterId": 2,
  "approverId": 1,
  "comment": "PI-2026-001 결재 요청드립니다."
}
```

**응답 `201 Created`**:

```json
{
  "id": 1,
  "documentType": "PI",
  "documentId": "PI2025001",
  "requesterId": 2,
  "approverId": 1,
  "status": "대기",
  "comment": "PI-2026-001 결재 요청드립니다.",
  "createdAt": "2026-03-26T09:00:00",
  "updatedAt": "2026-03-26T09:00:00"
}
```

**비고**: 결재자(`approverId`)는 `position.level == 1` (팀장급)인 사용자만 지정 가능하다. Auth Service의 `hasApprovalAuthority()` 참조.

---

#### `PUT /api/approval-requests/{id}` — 결재 승인/반려 🔲 구현예정

결재 요청을 승인하거나 반려한다.

**요청 헤더**: `Authorization: Bearer {accessToken}`

**경로 파라미터**:

| 파라미터 | 타입 | 설명 |
|----------|------|------|
| `id` | `Integer` | 결재 요청 ID |

**요청 본문**:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `status` | `String` | O | `승인` / `반려` |
| `comment` | `String` | - | 승인/반려 사유 |

```json
{
  "status": "승인",
  "comment": "확인 완료. 승인합니다."
}
```

**응답 `200 OK`**: 수정된 `ApprovalRequest` 객체

**비고**: 결재 승인 시 해당 문서의 상태가 자동으로 `확정`으로 변경된다. 결재자 본인만 승인/반려 가능하다.

---

## 부록: 엔드포인트 요약표

### Auth Service (port 8011) — ✅ 구현완료

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `POST` | `/api/auth/login` | 로그인 |
| `POST` | `/api/auth/refresh` | 토큰 갱신 |
| `POST` | `/api/auth/logout` | 로그아웃 |
| `GET` | `/api/users` | 전체 사용자 조회 |
| `GET` | `/api/users/{id}` | 사용자 단건 조회 |
| `POST` | `/api/users` | 사용자 생성 |
| `PUT` | `/api/users/{id}` | 사용자 수정 |
| `PATCH` | `/api/users/{id}` | 내 정보 수정 |
| `PATCH` | `/api/users/{id}/status` | 사용자 상태 변경 |
| `GET` | `/api/positions` | 전체 직급 조회 |
| `POST` | `/api/positions` | 직급 생성 |
| `GET` | `/api/departments` | 전체 부서 조회 |
| `POST` | `/api/departments` | 부서 생성 |
| `DELETE` | `/api/departments/{id}` | 부서 삭제 |
| `GET` | `/api/company` | 회사 정보 조회 |
| `PUT` | `/api/company` | 회사 정보 수정 |

### Master Service (port 8012) — ✅ 구현완료

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/api/clients` | 전체 거래처 조회 |
| `GET` | `/api/clients/{id}` | 거래처 단건 조회 |
| `GET` | `/api/clients/department/{departmentId}` | 부서별 거래처 조회 |
| `POST` | `/api/clients` | 거래처 생성 |
| `PUT` | `/api/clients/{id}` | 거래처 수정 |
| `PATCH` | `/api/clients/{id}/status` | 거래처 상태 변경 |
| `GET` | `/api/items` | 전체 품목 조회 |
| `GET` | `/api/items/{id}` | 품목 단건 조회 |
| `POST` | `/api/items` | 품목 생성 |
| `PUT` | `/api/items/{id}` | 품목 수정 |
| `PATCH` | `/api/items/{id}/status` | 품목 상태 변경 |
| `GET` | `/api/buyers` | 전체 바이어 조회 |
| `GET` | `/api/buyers/{id}` | 바이어 단건 조회 |
| `GET` | `/api/buyers/client/{clientId}` | 거래처별 바이어 조회 |
| `POST` | `/api/buyers` | 바이어 생성 |
| `PUT` | `/api/buyers/{id}` | 바이어 수정 |
| `DELETE` | `/api/buyers/{id}` | 바이어 삭제 |
| `GET/POST/PUT/DELETE` | `/api/countries[/{id}]` | 국가 CRUD |
| `GET/POST/PUT/DELETE` | `/api/currencies[/{id}]` | 통화 CRUD |
| `GET/POST/PUT/DELETE` | `/api/incoterms[/{id}]` | 인코텀즈 CRUD |
| `GET/POST/PUT/DELETE` | `/api/ports[/{id}]` | 항구 CRUD |
| `GET/POST/PUT/DELETE` | `/api/payment-terms[/{id}]` | 결제조건 CRUD |

### Activity Service (port 8013) — 🔲 구현예정

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET` | `/api/activities` | 전체 활동기록 조회 |
| `POST` | `/api/activities` | 활동기록 생성 |
| `PUT` | `/api/activities/{id}` | 활동기록 수정 |
| `DELETE` | `/api/activities/{id}` | 활동기록 삭제 |
| `GET` | `/api/contacts` | 전체 컨택 조회 |
| `POST` | `/api/contacts` | 컨택 생성 |
| `PUT` | `/api/contacts/{id}` | 컨택 수정 |
| `DELETE` | `/api/contacts/{id}` | 컨택 삭제 |
| `GET` | `/api/email-logs` | 메일 이력 조회 |
| `GET` | `/api/activity-packages` | 전체 패키지 조회 |
| `GET` | `/api/activity-packages/{id}` | 패키지 단건 조회 |
| `POST` | `/api/activity-packages` | 패키지 생성 |
| `PUT` | `/api/activity-packages/{id}` | 패키지 수정 |
| `DELETE` | `/api/activity-packages/{id}` | 패키지 삭제 |

### Document Service (port 8014) — 🔲 구현예정

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `GET/POST/PUT/DELETE` | `/api/pi[/{id}]` | PI CRUD |
| `GET/POST/PUT/DELETE` | `/api/po[/{id}]` | PO CRUD |
| `GET/POST/PUT` | `/api/ci[/{id}]` | CI 조회/생성/수정 |
| `GET/POST/PUT` | `/api/pl[/{id}]` | PL 조회/생성/수정 |
| `GET/POST/PUT` | `/api/production-orders[/{id}]` | 생산지시서 조회/생성/수정 |
| `GET/POST/PUT` | `/api/shipment-orders[/{id}]` | 출하지시서 조회/생성/수정 |
| `GET/PUT` | `/api/shipments[/{id}]` | 출하현황 조회/상태변경 |
| `GET/PUT` | `/api/collections[/{id}]` | 매출·수금 조회/처리 |
| `POST` | `/api/approval-requests` | 결재 요청 생성 |
| `PUT` | `/api/approval-requests/{id}` | 결재 승인/반려 |
