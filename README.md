# SalesBoost - 해외 B2B 영업관리 시스템

> PO(Purchase Order) 기반 무역서류 자동화와 거래 맥락 관리를 통해 해외 B2B 영업 담당자의 반복 업무를 줄이고, 본질적인 영업 활동에 집중할 수 있도록 지원하는 시스템입니다.

## 프로젝트 개요

| 항목 | 내용 |
|---|---|
| 프로젝트명 | SalesBoost - 해외 B2B 영업관리 시스템 |
| 팀명 | 닥트리오 (2팀) |
| 팀원 | 강성훈, 박찬진, 정진호 |
| 프로젝트 기간 | 2026.02.27 ~ 2026.04.22 (8주) |
| 소속 | 한화시스템 BEYOND SW캠프 22기 |

## 프로젝트 배경

해외 제조업 기반 B2B 거래에서는 PI, PO, 생산/구매 지시서, 출하지시서, CI/PL 등 단계별 문서가 매우 많고, 동일 정보를 반복 입력하는 과정에서 누락/오입력으로 인한 납기 지연과 신뢰도 하락이 빈번하게 발생합니다. 또한 협의 사항, 회의록, 일정 등 핵심 맥락이 개인별로 흩어져 업무 연속성이 단절되는 문제가 반복되고 있습니다.

## 주요 기능

### 1. 무역서류 자동화
- PO를 원천 데이터로 활용한 생산지시서/출하지시서 자동 생성
- CI(Commercial Invoice), PL(Packing List) 자동 생성 및 PDF 발행
- PI/PO 수정 시 하위 문서 자동 동기화
- 지시번호 자동 발번

### 2. 영업 진행 현황 관리
- 출하 현황 추적 (준비/출하/운송중/도착/완료)
- 지연 상태 관리 (정상/지연위험/지연)
- 판매 현황 조회 (수금/미수금, 월별 매출, 거래처별 수금 현황)

### 3. 거래 맥락 관리 및 활동기록
- 거래처별 정보 페이지: 협의 사항, 회의록, 일정, 문서 이력, 이슈 등 통합 관리
- 활동기록 자동 패키지(PDF): 담당자 변경 시 스냅샷 출력으로 업무 연속성 유지
- 담당자 기반 권한 정책 및 자동 이관

### 4. 메일 발송 및 이력 관리
- SMTP(Gmail/Naver) 연동 PDF 첨부 메일 발송
- Thymeleaf 기반 표준화된 메일 템플릿
- 거래처별 메일 발송 이력 자동 축적 및 조회

## 기술 스택

### Backend
- Java 21, Spring Boot 3
- Spring Web (REST), Spring Validation
- Spring Security + JWT (RBAC)
- JPA (Command) + MyBatis (Query) — CQRS 패턴
- Flyway (DB Migration)
- OpenHTMLtoPDF (PDF 생성)
- Spring Boot Mail (SMTP) + Thymeleaf (메일 템플릿)
- Swagger (API 문서화)

### Frontend
- Vue 3, Vite
- Pinia (상태 관리), Vue Router
- Tailwind CSS
- Axios, Chart.js

### Data
- MariaDB (주 DB) — AWS RDS Primary/StandBy 구성 (Multi-AZ Sync Replication)
- Redis — Amazon ElastiCache (캐시/세션)

### Infrastructure & DevOps
- **AWS**: VPC (Multi-AZ), ALB, RDS, ElastiCache, S3, CloudFront, NAT Gateway
- **Container/Orchestration**: Docker, Kubernetes (EKS), CoreDNS
- **CI/CD**: GitHub Actions
  - Frontend: Vue3 Build → S3 배포 → CloudFront Invalidation
  - Backend: Spring Boot Build → Docker Image → kubectl apply

## 시스템 아키텍처

```
[User] → [CloudFront + S3] (Frontend)
[User] → [ALB] → [EKS Cluster]
                    ├── Auth Pod
                    ├── Master Pod
                    ├── Document Pod
                    └── Activity Pod
                         ↓
              [RDS MariaDB Primary/StandBy]
              [ElastiCache for Redis]

[Developer] → [GitHub] → [GitHub Actions] → Build & Deploy
```

- **Multi-AZ 배포**: AZ1/AZ2에 걸친 고가용성 구성
- **네트워크**: Public Subnet (NAT Gateway, ALB) + Private Subnet (App Pods, DB)
- **서비스 간 통신**: OpenFeign (동기), Redis Pub/Sub (비동기)

## 마이크로서비스 구성

| 서비스 | 담당자 | 핵심 기능 |
|---|---|---|
| Auth Service | 정진호 | JWT 발급/검증, RBAC 권한 관리, 담당자 변경 시 권한 이관, 사용자 관리 |
| Master Service | 정진호 | 거래처/품목 CRUD, 통화/국가/항구 정보  |
| Document Service | 강성훈 | PI/PO CRUD, 생산/출하 지시서 자동 생성, CI/PL 자동 생성, 출하/수금 현황 관리 |
| Activity Service | 박찬진 |  활동기록 ,활동기록 패키지, 거래처 연락망 관리, 메일 이력 관리 |

### 공통 역할

| 담당자 | 공통 역할 |
|---|---|
| 정진호 | GitOps 설정, CI/CD 파이프라인, AWS 인프라 관리 |
| 강성훈 | 프론트엔드 공통 컴포넌트, 레이아웃/라우팅 |
| 박찬진 | GitHub 공통설정 (MileStone 등) |

## 프로젝트 일정

| 단계 | 기간 | 마일스톤 |
|---|---|---|
| 1 | 02/27 ~ 03/13 | 기획 (기획서, 요구사항 정의서, 아키텍처 설계, WBS, ERD, 화면설계서) |
| 2 | 03/09 ~ 03/20 | 프론트엔드 설계 및 구축 |
| 3 | 03/23 ~ 04/10 | 백엔드 설계 및 구축 (중간발표 03/23) |
| 4 | 04/13 ~ 04/17 | 시스템 통합 및 테스트 |
| 5 | 04/20 ~ 04/22 | 최종 발표 (04/22) |
