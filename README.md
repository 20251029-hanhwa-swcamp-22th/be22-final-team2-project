<p align="center">
  <img src="https://img.shields.io/badge/Java-21-007396?style=for-the-badge&logo=openjdk&logoColor=white"/>
  <img src="https://img.shields.io/badge/Spring%20Boot-3.5-6DB33F?style=for-the-badge&logo=springboot&logoColor=white"/>
  <img src="https://img.shields.io/badge/Spring%20Cloud-2025.0-6DB33F?style=for-the-badge&logo=spring&logoColor=white"/>
  <img src="https://img.shields.io/badge/Vue-3-4FC08D?style=for-the-badge&logo=vuedotjs&logoColor=white"/>
  <img src="https://img.shields.io/badge/MariaDB-11-003545?style=for-the-badge&logo=mariadb&logoColor=white"/>
  <img src="https://img.shields.io/badge/k3s-FFC61C?style=for-the-badge&logo=k3s&logoColor=black"/>
  <img src="https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white"/>
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white"/>
  <img src="https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white"/>
</p>

<h1 align="center">SalesBoost</h1>
<h3 align="center">해외 B2B 영업관리 시스템</h3>

<p align="center">
PO(Purchase Order) 기반 무역서류 자동화와 거래 맥락 관리를 통해<br/>
해외 B2B 영업 담당자의 반복 업무를 줄이고, 본질적인 영업 활동에 집중할 수 있도록 지원합니다.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/tests-1086%20passed-brightgreen?style=flat-square"/>
  <img src="https://img.shields.io/badge/API%20endpoints-134-blue?style=flat-square"/>
  <img src="https://img.shields.io/badge/요구사항-98%2F98%20완료-success?style=flat-square"/>
</p>

---

## Table of Contents

- [프로젝트 개요](#프로젝트-개요)
- [팀 소개](#팀-소개)
- [프로젝트 배경](#프로젝트-배경)
- [주요 기능](#주요-기능)
- [시스템 아키텍처](#시스템-아키텍처)
- [서비스 소개](#서비스-소개)
- [인증 / 인가 아키텍처](#인증--인가-아키텍처)
- [E2E 워크플로우](#e2e-워크플로우)
- [기술 스택](#기술-스택)
- [디렉토리 구조](#디렉토리-구조)
- [데이터베이스 설계](#데이터베이스-설계)
- [배포 환경](#배포-환경)
- [CI/CD 파이프라인](#cicd-파이프라인)
- [테스트 현황](#테스트-현황)
- [프로젝트 일정](#프로젝트-일정)

---

## 프로젝트 개요

| 항목 | 내용 |
|:---:|---|
| **프로젝트명** | SalesBoost - 해외 B2B 영업관리 시스템 |
| **팀명** | 닥트리오 (2팀) |
| **기간** | 2026.02.27 ~ 2026.04.22 (8주) |
| **소속** | 한화시스템 BEYOND SW캠프 22기 |

---

## 팀 소개

> **수평적 구조** — 역할 분담 기반 자율 협업

<table align="center">
  <tr>
    <td align="center" width="200">
      <a href="https://github.com/zkfmak9257">
        <img src="https://github.com/zkfmak9257.png" width="100" style="border-radius:50%"/><br/>
        <b>강성훈</b>
      </a><br/>
      <sub>Developer</sub>
    </td>
    <td align="center" width="200">
      <a href="https://github.com/chanjin346">
        <img src="https://github.com/chanjin346.png" width="100" style="border-radius:50%"/><br/>
        <b>박찬진</b>
      </a><br/>
      <sub>Developer</sub>
    </td>
    <td align="center" width="200">
      <a href="https://github.com/fdrn9999">
        <img src="https://github.com/fdrn9999.png" width="100" style="border-radius:50%"/><br/>
        <b>정진호</b>
      </a><br/>
      <sub>Tech Lead</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
      <sub>Documents 서비스<br/>PDF 생성 · 결재 워크플로우<br/>서비스 간 연동</sub>
    </td>
    <td align="center">
      <sub>Activity 서비스<br/>Frontend (Vue 3)<br/>서비스 간 연동</sub>
    </td>
    <td align="center">
      <sub>Auth 서비스 · Master 서비스<br/>MSA 설계 / CI·CD / 인프라<br/>인증·인가 · 기준정보 관리</sub>
    </td>
  </tr>
</table>

---

## 프로젝트 배경

해외 제조업 기반 B2B 거래에서는 PI, PO, 생산/구매 지시서, 출하지시서, CI/PL 등 **단계별 문서가 매우 많고**, 동일 정보를 반복 입력하는 과정에서 **누락/오입력으로 인한 납기 지연과 신뢰도 하락**이 빈번하게 발생합니다.

또한 협의 사항, 회의록, 일정 등 **핵심 맥락이 개인별로 흩어져 업무 연속성이 단절**되는 문제가 반복되고 있습니다.

**SalesBoost**는 이러한 문제를 해결하기 위해 문서 자동화와 거래 맥락 통합 관리를 제공합니다.

---

## 주요 기능

### 1. 무역서류 자동화
- PO를 원천 데이터로 활용한 **생산지시서 / 출하지시서 자동 생성**
- **CI(Commercial Invoice), PL(Packing List) 자동 생성** 및 PDF 발행
- PI/PO 수정 시 하위 문서 **자동 동기화** + 리비전 이력
- 결재 요청/승인/반려 워크플로우

### 2. 영업 진행 현황 관리
- 출하 현황 추적 (준비 / 출하 / 운송중 / 도착 / 완료)
- 수금 관리 (미수금 / 수금완료, 월별 매출, 거래처별 수금)
- 대시보드 통합 현황 조회

### 3. 거래 맥락 관리 및 활동기록
- 거래처별 정보 페이지: 미팅 / 이슈 / 일정 / 문서 이력 **통합 관리**
- 활동기록 패키지(PDF): 담당자 변경 시 스냅샷 출력으로 **업무 연속성 유지**
- 연락처(Contact) 관리

### 4. 메일 발송 및 이력 관리
- CI/PL 상세 화면에서 **영업 담당자가 직접 메일 발송** (PDF 자동 첨부)
- SMTP(Gmail) 연동, 발송 이력 자동 기록 (Activity 서비스)
- 실패 메일 **1-click 재전송** (중복 방지 + SENDING 상태 관리)
- 비밀번호 초기화 메일 발송 (임시 비밀번호 방식)

### 5. 기준정보 관리
- 거래처 / 바이어 / 품목 / 국가 / 통화 / 항구 / 인코텀즈 / 결제조건 CRUD
- 부서 / 직급 / 사용자 / 회사정보 관리

---

## 시스템 아키텍처

```
  [브라우저]
     │ :8001
     ▼
┌─────────────┐
│nginx (Vue3) │ ← 정적 파일 서빙 + /api/* 리버스 프록시
│  :80→8001   │    X-User-* / X-Internal-Token 헤더 strip
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Gateway     │ ← JWT 검증 (JWKS) + RBAC + /internal denyAll
│   :8010     │    GlobalHeaderStripFilter (2차 헤더 방어)
└──────┬──────┘
       │
  ┌────┼────────────┬─────────────┬─────────────┐
  ▼    ▼            ▼             ▼             ▼
┌─────┐ ┌──────┐ ┌────────┐ ┌──────────┐ ┌──────────┐
│Auth │ │Master│ │Activity│ │Documents │ │ MariaDB  │
│:8011│ │:8012 │ │ :8013  │ │  :8014   │ │  :3306   │
└─────┘ └──────┘ └────────┘ └──────────┘ └──────────┘
  │                  ↕ Feign (Bearer JWT)      │
  │                  ↕ Feign (X-Internal-Token) │
  └──── JWKS ────────┴─────────────────────────┘
```

**외부 노출 포트**: 8001 (nginx) 1개만. 백엔드 4개 + Gateway 는 docker network 내부 전용.

---

## 서비스 소개

### Auth Service `:8011`
> 사용자 인증 · JWT 발급 · JWKS 공개키 배포 · RBAC 기반 권한 관리

| 도메인 | 주요 기능 |
|---|---|
| 인증 | JWT(RS256) 발급, RefreshToken 회전, 비밀번호 찾기(임시 PW 메일) |
| 사용자 | CRUD, 상태 관리(재직/휴직/퇴직), 비밀번호 변경/초기화 |
| 조직 | 부서 · 직급 CRUD, 회사정보 관리 |
| JWKS | `/.well-known/jwks.json` — 동적 kid(SHA-256), Cache-Control 1h |

### Master Service `:8012`
> 거래처 · 품목 · 국가 · 통화 등 기준정보(마스터 데이터) 관리

| 도메인 | 주요 기능 |
|---|---|
| 거래처 | CRUD + 부서별 거래처 조회 + 상태(활성/비활성) |
| 바이어 | 거래처 하위 담당자 관리 |
| 품목 | CRUD + 카테고리/상태 필터 |
| 기타 기준 | 국가 · 통화 · 항구 · 인코텀즈 · 결제조건 |

### Activity Service `:8013`
> 영업 활동기록 · 연락처 · 이메일 이력 · 활동 패키지(PDF 보고서) 관리

| 도메인 | 주요 기능 |
|---|---|
| 활동기록 | 미팅/이슈/일정 등록 · 수정 · 삭제, 우선순위 관리 |
| 연락처 | 거래처별 컨택 리스트 CRUD |
| 이메일 이력 | Documents 발송 결과 수신(X-Internal-Token), 실패 건 재전송 |
| 패키지 | 활동기록 묶음 PDF 보고서 생성 · 열람 권한 관리 |

### Documents Service `:8014`
> PI/PO/CI/PL/생산지시서/출하지시서/출하현황/수금/결재 — 무역서류 전 라이프사이클

| 도메인 | 주요 기능 |
|---|---|
| PI/PO | 견적송장 · 발주서 CRUD + 결재 워크플로우(등록/수정/삭제 요청) |
| CI/PL | PO 확정 시 자동 생성, PDF 발행, 메일 발송 |
| 생산/출하 | 지시서 생성, 출하현황 자동 생성, 상태 관리 |
| 수금 | 수금 등록 · 완료 처리 |
| 결재 | ApprovalRequest 생성/승인/반려 |
| 메일 | CI/PL PDF 첨부 이메일 발송 (Gmail SMTP), Activity 로그 자동 기록 |

### API Gateway `:8010`
> Spring Cloud Gateway (WebFlux) — JWT 검증 · RBAC · 헤더 방어 · 라우팅

- 4개 백엔드로 경로 기반 라우팅 (총 134 endpoints)
- `/api/**/internal/**` → `denyAll()` (서비스 간 시스템 호출 외부 차단)
- `GlobalHeaderStripFilter` — 외부 위조 헤더 (`X-User-*`, `X-Internal-Token`) 제거

---

## 인증 / 인가 아키텍처

### JWKS 기반 JWT 검증 플로우

```
                          ┌───────────────────────────────────┐
                          │ Auth Service (:8011)               │
                          │                                   │
                          │  [RSA Private Key] ──► JWT 서명    │
                          │  [RSA Public Key]  ──► JWKS 노출   │
                          │                                   │
                          │  GET /.well-known/jwks.json        │
                          │  → { keys: [{ kty:RSA, alg:RS256, │
                          │       kid:SHA256(pub), n, e }] }   │
                          │  Cache-Control: max-age=3600       │
                          └──────────┬────────────────────────┘
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
   ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
   │   Gateway    │      │   Master     │      │  Activity    │
   │  (:8010)     │      │  (:8012)     │      │  (:8013)     │
   │              │      │              │      │              │
   │ jwk-set-uri  │      │ jwk-set-uri  │      │ jwk-set-uri  │  + Documents
   │  → JWKS fetch│      │  → JWKS fetch│      │  → JWKS fetch│    (:8014)
   │  → kid 매칭   │      │  → kid 매칭   │      │  → kid 매칭   │
   │  → RS256 검증 │      │  → RS256 검증 │      │  → RS256 검증 │
   │  → 캐시 (auto)│      │  → 캐시 (auto)│      │  → 캐시 (auto)│
   └──────────────┘      └──────────────┘      └──────────────┘
```

**핵심**: Auth만 private key 보유 (발급). 나머지는 **JWKS 원격 fetch로 public key만 조회** (검증). 키 유출 면적 최소화.

### 로그인 → 토큰 발급 → API 호출 전체 흐름

```
[1. 로그인]
Browser → POST /api/auth/login { email, password }
  → Gateway (permitAll) → Auth Service
  → BCrypt 검증 → JWT 발급 (RS256 + kid)
  → AccessToken (body) + RefreshToken (HttpOnly 쿠키)
  ← 200 OK

[2. API 호출]
Browser → GET /api/clients (Authorization: Bearer <AT>)
  → Ingress → frontend nginx (헤더 strip 1차)
  → Gateway (JWKS 캐시에서 kid 매칭 → RS256 검증 → RBAC)
  → Master Service (자체 JWT 재검증 — defense in depth)
  ← 200 OK + 데이터

[3. 토큰 갱신 (AT 만료 시)]
Browser → POST /api/auth/refresh (RT 쿠키 자동 첨부)
  → Gateway (permitAll) → Auth Service
  → RT DB 조회 → 유효성 검증 → 기존 RT 삭제 + 신규 RT 발급 (rotation)
  → 새 AT (body) + 새 RT (쿠키)
  ← axios interceptor가 자동 처리 (사용자 개입 없음)

[4. 로그아웃]
Browser → POST /api/auth/logout
  → Auth Service → RT DB 삭제 + 쿠키 만료
  → AT는 15분 후 자연 만료 (서버 블랙리스트 없음)
```

### 3-tier 인증 수단

| 수단 | 용도 | 방향 |
|---|---|---|
| **JWT (Bearer)** | 사용자 인증 + RBAC | 브라우저 → Ingress → Gateway → 백엔드 |
| **Bearer 전파 (Feign)** | 사용자 트리거 서비스 간 호출 | Activity ↔ Documents ↔ Auth/Master |
| **X-Internal-Token** | 시스템 호출 (사용자 컨텍스트 없음) | Documents → Activity `/internal` 등 |

### k8s + Ingress 환경에서의 다층 방어 (5계층)

```
[외부 요청 — 인터넷]
  │
  ├─ (1) Ingress (nginx-ingress)
  │       /api/**/internal/** 는 Gateway가 denyAll
  │       일반 /api/* 만 Gateway로 라우팅
  │
  ├─ (2) Frontend nginx (Pod 내부)
  │       X-User-*, X-Internal-Token 헤더 강제 초기화
  │       → 외부에서 위조 헤더 주입 불가
  │
  ├─ (3) Gateway (Spring Cloud Gateway)
  │       JWT 검증 (JWKS 캐시 → kid 매칭 → RS256)
  │       RBAC (hasRole, hasAnyRole, authenticated)
  │       /api/**/internal/** denyAll (4개 경로)
  │       GlobalHeaderStripFilter (2차 헤더 방어)
  │
  ├─ (4) 각 백엔드 서비스 (defense in depth)
  │       자체 JWT 검증 (동일 JWKS)
  │       InternalApiTokenFilter: /internal 경로 X-Internal-Token 검증
  │       prod profile: INTERNAL_API_TOKEN blank 시 기동 실패 (fail-fast)
  │
  └─ (5) @PreAuthorize (메서드 레벨)
          hasRole('ADMIN'), hasAnyRole('ADMIN','SALES'), isAuthenticated()
          /internal 메서드: permitAll() (Filter가 이미 검증)
```

> **k8s 특이사항**: Pod 간 통신이 ClusterIP Service를 통하므로, 같은 namespace 내 다른 Pod가 직접 백엔드 호출 가능. 이때 **InternalApiTokenFilter + @PostConstruct fail-fast**가 마지막 방어선.

### JWT 스펙

| 항목 | 값 |
|---|---|
| 알고리즘 | RS256 (비대칭, alg confusion 차단) |
| Access Token TTL | 15분 |
| Refresh Token TTL | 7일 (HttpOnly + Secure + SameSite=Strict 쿠키) |
| RT 회전 | 사용 시마다 기존 삭제 + 신규 발급 |
| kid | `Base64URL(SHA-256(publicKey))` 동적 생성 |
| Claims | `sub(userId)`, `email`, `name`, `role`, `departmentId`, `iss`, `iat`, `exp` |
| RSA 키 저장 | k8s Secret (`team2-jwt-keys`) → Auth Pod `/run/secrets/jwt/` volumeMount |
| JWKS 캐시 | NimbusJwtDecoder 자동 (10분~1시간), HTTP Cache-Control 1h |

### RBAC 역할

| Role | 접근 범위 |
|---|---|
| `ADMIN` | 전체 (사용자 관리, 품목 CUD, 거래처 삭제 등) |
| `SALES` | 거래처 CUD, 활동/패키지/메일, PI/PO/CI/PL |
| `PRODUCTION` | 생산지시서 |
| `SHIPPING` | 출하지시서/출하현황 |

---

## E2E 워크플로우

### 핵심 비즈니스 흐름

```
[영업 담당자 로그인]
    │
    ▼
[PI(견적송장) 작성] → [결재 요청] → [승인] → [PI 확정]
    │
    ▼
[PO(발주서) 생성] → [결재 요청] → [승인] → [PO 확정]
    │
    ├──→ [CI(상업송장) 자동 생성] → [PDF 발행] → [메일 발송]
    ├──→ [PL(포장명세서) 자동 생성] → [PDF 발행] → [메일 발송]
    ├──→ [생산지시서 생성] → [생산완료]
    ├──→ [출하지시서 생성] → [출하완료]
    ├──→ [출하현황 자동 생성] → [상태 추적]
    └──→ [수금 자동 생성] → [수금완료 처리]

[활동기록] ← 각 단계에서 미팅/이슈/일정 기록
[메일 이력] ← 발송 성공/실패 자동 축적, 실패 건 1-click 재전송
[패키지 PDF] ← 담당자 변경 시 활동기록 스냅샷 인수인계
```

### 메일 발송 흐름 (Write Ownership 원칙)

```
[사용자 발송] Frontend → Gateway → Documents.sendEmail() → SMTP 발송
                                        ↓ logToActivity (X-Internal-Token)
                                   Activity.createEmailLogInternal → email_logs INSERT

[재전송]     Frontend → Gateway → Activity.resend()
                                        ↓ sendEmailWithoutLogging (X-Internal-Token)
                                   Documents → SMTP 발송 (로그 기록 생략)
                                   Activity → email_logs UPDATE (SENDING → SENT/FAILED)
```

> **Write Owner**: `email_logs` 테이블의 유일한 write owner 는 Activity. Documents 는 발송만.

---

## 기술 스택

### Backend
| 기술 | 버전 | 용도 |
|---|---|---|
| Java | 21 (LTS) | 메인 언어 |
| Spring Boot | 3.5.x | 마이크로서비스 프레임워크 |
| Spring Cloud | 2025.0.0 | Gateway, OpenFeign, Resilience4j |
| Spring Security | 6.x | JWT + OAuth2 Resource Server + Method Security |
| MyBatis | 3.0.x | CQRS Query 레이어 |
| JPA/Hibernate | 6.x | Command 레이어 |
| Resilience4j | — | Circuit Breaker + Fallback (Feign 연동) |
| Gradle | 8.12 | 빌드 도구 |

### Frontend
| 기술 | 버전 | 용도 |
|---|---|---|
| Vue | 3.x | SPA 프레임워크 (Composition API + `<script setup>`) |
| Vite | 6.x | 빌드 도구 |
| Tailwind CSS | 3.x | 유틸리티 CSS |
| Pinia | — | 상태 관리 |
| Axios | — | HTTP 클라이언트 (Bearer 자동 주입 + 401 refresh) |

### Infra / DevOps
| 기술 | 용도 |
|---|---|
| k3s | 경량 k8s (현재 운영) |
| nginx-ingress | Ingress Controller (NodePort :8001) |
| ArgoCD | GitOps 자동 배포 + UI (:8043) |
| ArgoCD Image Updater | ghcr.io 이미지 태그 자동 감지 → sync |
| GitHub Actions | CI (이미지 빌드 → ghcr.io 푸시, `:latest` + `:SHA`) |
| Kustomize | k8s 매니페스트 관리 (base/overlays) |
| Docker | 컨테이너 빌드 (multi-stage, non-root) |
| nginx | 프론트 정적 서빙 + API 리버스 프록시 (Pod 내부) |
| MariaDB 11 | RDBMS (k8s StatefulSet + PVC, 4 스키마 분리) |
| AWS EKS + ALB + RDS | Phase 3b 프로덕션 (계획) |

---

## 디렉토리 구조

```
be22-final-team2-project/         ← 루트 (서브모듈 오케스트레이션)
├── team2-backend-auth/           ← Auth Service (JWT 발급, 사용자, JWKS)
├── team2-backend-master/         ← Master Service (거래처, 품목, 기준정보)
├── team2-backend-activity/       ← Activity Service (활동기록, 연락처, 이메일 로그)
├── team2-backend-documents/      ← Documents Service (PI/PO/CI/PL, 결재, 수금)
├── team2-gateway/                ← API Gateway (Spring Cloud Gateway)
├── team2-frontend/               ← Frontend (Vue 3 + Vite + Tailwind)
├── team2-manifest/               ← 배포 매니페스트 (docker-compose, nginx, secrets) [private]
├── docs/                         ← 프로젝트 문서
│   ├── 2팀_기획서.docx.pdf
│   ├── 2팀_시스템 아키텍처.drawio
│   └── deployment-plan.md
├── ddl/                          ← DDL + API 명세서 + 요구사항명세서
│   ├── REST_API_명세서_개선.xlsx    ← 134 endpoints (Auth/Master/Activity/Documents)
│   ├── 2팀_요구사항명세서_v2.xlsx   ← 98건 요구사항 (전수 완료)
│   ├── integrated_ddl.sql
│   ├── integrated_erd.md
│   └── {service}_service.sql / .md
├── unit-test-scenarios/          ← 테스트 결과서
│   ├── 단위_테스트_결과서.xlsx      ← 834 tests / ALL GREEN
│   ├── 통합_테스트_결과서.xlsx      ← 249 tests / ALL GREEN
│   └── 단위_테스트_시나리오.xlsx
├── .github/workflows/
│   ├── full-validation.yml       ← E2E 통합 검증 GHA (self-hosted runner)
│   └── sync-submodules.yml       ← 서브모듈 포인터 자동 동기화 (5분 cron)
└── db/
    └── init/01-create-databases.sql
```

---

## 데이터베이스 설계

### 스키마 분리 (MSA 원칙)

| 스키마 | 서비스 | 주요 테이블 |
|---|---|---|
| `team2_auth` | Auth | users, departments, positions, company, refresh_tokens |
| `team2_master` | Master | clients, buyers, items, countries, currencies, ports, incoterms, payment_terms |
| `team2_activity` | Activity | activities, activity_packages, contacts, email_logs, email_log_types, email_log_attachments |
| `team2_docs` | Documents | proforma_invoices, purchase_orders, commercial_invoices, packing_lists, production_orders, shipment_orders, shipments, collections, approval_requests, docs_revision |

- **Cross-schema SQL 0건** — 모든 서비스 간 데이터 조회는 Feign 호출
- **스냅샷 패턴**: PI/PO/생산지시서에 발행 당시 거래처명/품목명/담당자명 저장 → 원본 변경에도 문서 무결

---

## 배포 환경

### Phase 1/2 — Docker Compose (완료)
> 로컬 개발 + 초기 스테이징. **현재는 k8s로 전환 완료.**

### Phase 3a — k3s + nginx-ingress + ArgoCD (현재 운영)

```
playdata4.iptime.org
     │
     │  할당 포트: 8000~8050
     │
     ├─ :8001 ──► nginx-ingress (NodePort) ──► Ingress Rules
     │                                           ├─ /api/*  → gateway:8010
     │                                           ├─ /.well-known/* → gateway:8010
     │                                           └─ /*      → frontend:80
     │
     ├─ :8043 ──► ArgoCD UI (NodePort, HTTPS)
     │             ID: admin / PW: kubectl secret 조회
     │
     └─ :8000 ──► SSH
```

#### 포트 할당표

| 외부 포트 | 내부 대상 | 용도 |
|----------|----------|------|
| **8000** | SSH :22 | 서버 접속 |
| **8001** | nginx-ingress NodePort | **사용자 접속 (SPA + API)** |
| **8006** | — (미사용, 구 compose MariaDB) | 비활성 |
| **8043** | ArgoCD Server NodePort | **ArgoCD UI (HTTPS)** |

#### k8s 리소스

| 서비스 | Pod Port | k8s Service | 외부 접근 |
|---|---|---|---|
| frontend | 80 | ClusterIP | Ingress `/` |
| gateway | 8010 | ClusterIP | Ingress `/api/*` |
| backend-auth | 8011 | ClusterIP | 내부 전용 |
| backend-master | 8012 | ClusterIP | 내부 전용 |
| backend-activity | 8013 | ClusterIP | 내부 전용 |
| backend-documents | 8014 | ClusterIP | 내부 전용 |
| team2-mariadb | 3306 | ClusterIP | 내부 전용 |

#### ArgoCD + Image Updater

| 컴포넌트 | Namespace | 역할 |
|---------|----------|------|
| argocd-server | argocd | GitOps 컨트롤러 + UI |
| argocd-image-updater | argocd | ghcr.io 이미지 태그 자동 감지 |
| salesboost (Application) | argocd | `team2-manifest/k8s/overlays/prod` watch → auto sync |

### Phase 3b — AWS EKS (계획)

```
Route53 → ALB → Ingress (ALB Ingress Controller)
                  ├─ /api/* → Gateway Service
                  └─ /*     → Frontend Service
                  TLS: ACM 인증서
                  DB: RDS Aurora MariaDB
```

> 상세: [`docs/k8s-전환-및-CICD-전략.md`](docs/k8s-전환-및-CICD-전략.md)

---

## CI/CD 파이프라인

> **"개발자는 코드만 push하면 끝. 나머지는 전부 자동."**

### Zero-Touch Delivery

코드 push 한 번이면 **이미지 빌드 → 레지스트리 → 태그 감지 → k8s 배포 → 서브모듈 포인터 갱신**까지 사람 개입 없이 완료됩니다.

```
개발자 push (main)
     │
     ├──► [GitHub Actions]              ← 각 서브모듈 자동 트리거
     │       docker build + push
     │       ghcr.io:latest + :${SHA}
     │              │
     │              ▼  (~2분 폴링)
     │    [ArgoCD Image Updater]        ← ghcr.io 레지스트리 watch
     │       newest-build 전략
     │       :latest 무시, SHA만 추적
     │              │
     │              ▼
     │    [ArgoCD auto sync]            ← GitOps 자동 배포
     │       prune + selfHeal
     │              │
     │              ▼
     │    [k8s Rolling Update]          ← Pod 무중단 교체
     │       readinessProbe 통과 후 트래픽 전환
     │
     └──► [Submodule Sync Workflow]     ← 루트 레포 포인터 자동 갱신
              5분 cron 또는 수동 트리거
              변경된 서브모듈만 감지 → commit + push
              [skip ci] 로 자기 자신 재트리거 방지
```

### 자동화 범위

| 단계 | 도구 | 사람 개입 |
|------|------|----------|
| 코드 push | 개발자 | **유일하게 사람이 하는 것** |
| Docker 이미지 빌드 + 푸시 | GitHub Actions | 자동 |
| 새 이미지 태그 감지 | ArgoCD Image Updater | 자동 |
| k8s Deployment 갱신 | ArgoCD auto sync | 자동 |
| Pod rolling update | Kubernetes | 자동 |
| 루트 레포 서브모듈 포인터 갱신 | GHA cron workflow | 자동 |
| Rollback | ArgoCD UI 1-click | 반자동 |

### 소요 시간

| 구간 | 시간 |
|------|------|
| GHA 빌드 + ghcr.io 푸시 | ~3-5분 |
| Image Updater 감지 | ~2분 |
| ArgoCD sync + Pod 교체 | ~1-2분 |
| 서브모듈 포인터 동기화 | ~5분 (cron) |
| **총 (push → 운영 반영)** | **~6-9분** |
| **총 (push → 루트 레포 갱신)** | **~10분 이내** |

### Rollback

```bash
# ArgoCD UI (https://playdata4.iptime.org:8043)
# → salesboost → History → 이전 revision → Rollback

# 또는 CLI
argocd app rollback salesboost <revision>
kubectl -n team2 set image deploy/서비스명 서비스명=ghcr.io/...:이전SHA
```

---

## 테스트 현황

| 서비스 | 단위 | 통합 | 합계 | 상태 |
|---|---|---|---|---|
| Auth | 124 | 92 | **216** | ALL GREEN |
| Master | 237 | 125 | **362** | ALL GREEN |
| Activity | 238 | 21 | **259** | ALL GREEN |
| Documents | 235 | 11 | **246** | ALL GREEN |
| Gateway | — | 3 | **3** | ALL GREEN |
| **합계** | **834** | **249+3** | **1086** | **0 FAIL** |

- JaCoCo 커버리지 리포트 (단위 테스트)
- JUnit 5 + Mockito + Spring Boot Test
- Integration Test: `@SpringBootTest` + `@AutoConfigureMockMvc` + H2 (MariaDB 모드)

---

## 프로젝트 일정

```
Week 1-2  요구사항 분석 · ERD · API 설계 · MSA 아키텍처 수립
Week 3-4  Auth/Master 핵심 CRUD · JWT 인증 · Gateway 라우팅
Week 5-6  Documents 서류 자동화 · Activity 활동기록 · Frontend 화면
Week 7    서비스 간 연동 · 메일 발송 · 결재 워크플로우 · 통합 테스트
Week 8    보안 강화 · 성능 최적화 · 문서화 · k8s 전환 준비
```

---

## 라이선스

본 프로젝트는 한화시스템 BEYOND SW캠프 22기 최종 프로젝트로 제작되었습니다.

---

<p align="center">
  <sub>Built with by 닥트리오 (Team 2) — 한화시스템 BEYOND SW캠프 22기</sub>
</p>
