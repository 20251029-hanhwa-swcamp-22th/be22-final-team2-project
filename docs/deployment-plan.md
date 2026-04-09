# Team2 서버 배포 계획서

## 배포 로드맵

```
Phase 1: 로컬 Docker Compose     -> 개발/테스트 환경
Phase 2: 리눅스 서버 Docker Compose -> 스테이징 환경 (playdata4.iptime.org)
Phase 3: Kubernetes + Ingress     -> 프로덕션 환경 (AWS EKS + Route53)
```

---

# Phase 1 & 2: Docker Compose

## 1. 서버 정보

| 항목 | 값 |
|------|-----|
| 서버 URL | `playdata4.iptime.org` |
| SSH 접속 | 외부 `8000` -> 내부 `22` |
| SSH 계정 | `swcamp22-team2` |
| 사용 가능 포트 | 외부/내부 `8001 ~ 8050` |

```bash
# SSH 접속
ssh -p 8000 swcamp22-team2@playdata4.iptime.org
```

---

## 2. 포트 할당 계획

| 외부 포트 | 내부 포트 | 서비스 | 설명 |
|-----------|-----------|--------|------|
| 8001 | 8001 | **Frontend (Nginx)** | Vue 3 정적 파일 서빙 + API 리버스 프록시 |
| 8011 | 8011 | **Backend - Auth** | 인증/사용자/회사/부서/직급 관리 |
| 8012 | 8012 | **Backend - Master** | 마스터 데이터 (국가/통화/거래처/품목 등) |
| 8013 | 8013 | **Backend - Activity** | 활동/이벤트 관리 (기존 8083 -> 8013으로 변경) |
| 8014 | 8014 | **Backend - Documents** | 문서 관리 (기존 8084 -> 8014으로 변경) |
| 8006 | 3306 | **MariaDB** | 데이터베이스 (외부 접속용) |

> **참고:** Activity(8083), Documents(8084)는 할당 범위(8001~8050) 안이지만,
> 다른 서비스와 번호 체계를 맞추기 위해 801x 대역으로 통일합니다.
> 기존 포트를 유지하려면 8083/8084를 그대로 사용해도 됩니다.

---

## 3. 전체 아키텍처

```
  브라우저
    |
    v
playdata4.iptime.org:8001
    |
    v
+-------------------+
|   Nginx (FE)      |  :8001
|  Vue 3 정적 파일   |
|  + 리버스 프록시    |
+-------------------+
    |
    |  /api/auth/**  --> auth:8011
    |  /api/master/**  --> master:8012  (또는 /api/clients, /api/items 등)
    |  /api/activity/**  --> activity:8013
    |  /api/documents/**  --> documents:8014
    v
+----------+  +----------+  +------------+  +--------------+
|   Auth   |  |  Master  |  |  Activity  |  |  Documents   |
|  :8011   |  |  :8012   |  |   :8013    |  |    :8014     |
+----------+  +----------+  +------------+  +--------------+
    |              |              |                |
    v              v              v                v
+----------------------------------------------------------+
|                    MariaDB :3306                          |
|  team2_auth | team2_master | team2_activity | team2_docs  |
+----------------------------------------------------------+
```

---

## 4. Docker Compose 구성

### 4.1 디렉토리 구조 (서버)

```
/home/swcamp22-team2/
├── docker-compose.yml
├── nginx/
│   └── default.conf
├── frontend/
│   └── dist/              # Vue 빌드 결과물
├── backend-auth/
│   └── build/libs/*.jar
├── backend-master/
│   └── build/libs/*.jar
├── backend-activity/
│   └── build/libs/*.jar
├── backend-documents/
│   └── build/libs/*.jar
├── db/
│   └── init/
│       ├── 01-create-databases.sql
│       └── 02-init-data.sql
└── .env
```

### 4.2 환경변수 파일 (.env)

```env
# MariaDB
MARIADB_ROOT_PASSWORD=team2root!@#
MARIADB_USER=team2
MARIADB_PASSWORD=team2pass!@#

# JWT
JWT_SECRET=YourProductionSecretKeyMustBeAtLeast256BitsLong!!@@

# Mail (필요 시)
MAIL_USERNAME=your-email@gmail.com
MAIL_PASSWORD=your-app-password
```

### 4.3 docker-compose.yml

```yaml
version: "3.8"

services:
  # ──────────────────────────────────────
  # Database
  # ──────────────────────────────────────
  mariadb:
    image: mariadb:11
    container_name: team2-mariadb
    restart: always
    ports:
      - "8006:3306"
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
    volumes:
      - mariadb-data:/var/lib/mysql
      - ./db/init:/docker-entrypoint-initdb.d
    networks:
      - team2-net
    healthcheck:
      test: ["CMD", "healthcheck", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ──────────────────────────────────────
  # Backend - Auth (포트 8011)
  # ──────────────────────────────────────
  backend-auth:
    image: eclipse-temurin:21-jre
    container_name: team2-auth
    restart: always
    # 외부 노출 X - Nginx를 통해서만 접근 (신뢰 기반)
    expose:
      - "8011"
    volumes:
      - ./backend-auth/build/libs:/app
    working_dir: /app
    command: java -jar team2-backend-auth-0.0.1-SNAPSHOT.jar
    environment:
      SERVER_PORT: 8011
      DB_URL: jdbc:mariadb://mariadb:3306/team2_auth
      DB_USERNAME: root
      DB_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      DB_DRIVER: org.mariadb.jdbc.Driver
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
      JWT_SECRET: ${JWT_SECRET}
      MAIL_USERNAME: ${MAIL_USERNAME}
      MAIL_PASSWORD: ${MAIL_PASSWORD}
    depends_on:
      mariadb:
        condition: service_healthy
    networks:
      - team2-net

  # ──────────────────────────────────────
  # Backend - Master (포트 8012)
  # ──────────────────────────────────────
  backend-master:
    image: eclipse-temurin:21-jre
    container_name: team2-master
    restart: always
    expose:
      - "8012"
    volumes:
      - ./backend-master/build/libs:/app
    working_dir: /app
    command: java -jar team2-backend-master-0.0.1-SNAPSHOT.jar
    environment:
      SERVER_PORT: 8012
      DB_URL: jdbc:mariadb://mariadb:3306/team2_master
      DB_USERNAME: root
      DB_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      DB_DRIVER: org.mariadb.jdbc.Driver
      SPRING_JPA_HIBERNATE_DDL_AUTO: update
    depends_on:
      mariadb:
        condition: service_healthy
    networks:
      - team2-net

  # ──────────────────────────────────────
  # Backend - Activity (포트 8013)
  # ──────────────────────────────────────
  backend-activity:
    image: eclipse-temurin:21-jre
    container_name: team2-activity
    restart: always
    expose:
      - "8013"
    volumes:
      - ./backend-activity/build/libs:/app
    working_dir: /app
    command: java -jar team2-backend-activity-0.0.1-SNAPSHOT.jar
    environment:
      SERVER_PORT: 8013
      DB_URL: jdbc:mariadb://mariadb:3306/team2_activity
      DB_USERNAME: root
      DB_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      DOCUMENTS_SERVICE_URL: http://backend-documents:8014
      MAIL_USERNAME: ${MAIL_USERNAME}
      MAIL_PASSWORD: ${MAIL_PASSWORD}
    depends_on:
      mariadb:
        condition: service_healthy
    networks:
      - team2-net

  # ──────────────────────────────────────
  # Backend - Documents (포트 8014)
  # ──────────────────────────────────────
  backend-documents:
    image: eclipse-temurin:21-jre
    container_name: team2-documents
    restart: always
    expose:
      - "8014"
    volumes:
      - ./backend-documents/build/libs:/app
    working_dir: /app
    command: java -jar team2-backend-documents-0.0.1-SNAPSHOT.jar
    environment:
      SERVER_PORT: 8014
      DB_URL: jdbc:mariadb://mariadb:3306/team2_docs
      DB_USERNAME: root
      DB_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      AUTH_SERVICE_URL: http://backend-auth:8011
      MAIL_USERNAME: ${MAIL_USERNAME}
      MAIL_PASSWORD: ${MAIL_PASSWORD}
    depends_on:
      mariadb:
        condition: service_healthy
    networks:
      - team2-net

  # ──────────────────────────────────────
  # Frontend - Nginx (포트 8001)
  # ──────────────────────────────────────
  frontend:
    image: nginx:alpine
    container_name: team2-frontend
    restart: always
    ports:
      - "8001:80"
    volumes:
      - ./frontend/dist:/usr/share/nginx/html:ro
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend-auth
      - backend-master
      - backend-activity
      - backend-documents
    networks:
      - team2-net

volumes:
  mariadb-data:

networks:
  team2-net:
    driver: bridge
```

---

## 5. 신뢰 기반 인증/인가 구조

### 5.1 동작 원리

```
  브라우저 (Authorization: Bearer <JWT>)
      |
      v
  ┌──────────────────────────────────────────┐
  │  Nginx                                    │
  │                                            │
  │  1) /api/auth/login, /refresh  → 바로 통과  │
  │  2) 그 외 /api/** 요청이 오면:              │
  │     ├─ auth_request → Auth:8011/api/auth/validate │
  │     │   ├─ 200 OK + 헤더 반환 → 통과        │
  │     │   └─ 401 → 클라이언트에 401 반환       │
  │     └─ Auth가 반환한 헤더를 백엔드로 전달:   │
  │        X-User-Id, X-User-Role,             │
  │        X-User-Email, X-User-Department-Id  │
  └──────────────────────────────────────────┘
      |
      v
  ┌──────────────┐
  │ Master 등     │  → 헤더만 읽으면 됨 (JWT 라이브러리 불필요)
  │ Activity     │  → "Nginx가 검증했으니 이 헤더를 믿는다"
  │ Documents    │
  └──────────────┘
```

**핵심: Auth만 JWT를 알고, 나머지는 Nginx가 전달하는 X-User-* 헤더를 신뢰**

### 5.2 JWT Claims (Auth가 발급)

| Claim | 예시 | 설명 |
|-------|------|------|
| `sub` | `1` | userId |
| `email` | `admin@company.com` | 사용자 이메일 |
| `name` | `관리자` | 사용자 이름 |
| `role` | `ADMIN` | ADMIN / SALES / PRODUCTION / SHIPPING |
| `departmentId` | `1` | 소속 부서 ID |

### 5.3 Auth 검증 엔드포인트

```
GET /api/auth/validate
Authorization: Bearer <JWT>

→ 200 OK (유효한 토큰)
  X-User-Id: 1
  X-User-Email: admin@company.com
  X-User-Name: 관리자
  X-User-Role: ADMIN
  X-User-Department-Id: 1

→ 401 Unauthorized (무효/만료 토큰)
```

### 5.4 백엔드 서비스에서 헤더 읽기 (예시)

각 서비스는 JWT 라이브러리 없이, Nginx가 전달하는 헤더만 읽으면 됩니다.

```java
// 컨트롤러에서 바로 사용
@GetMapping
public ResponseEntity<List<ClientResponse>> getMyClients(
        @RequestHeader("X-User-Department-Id") Integer departmentId,
        @RequestHeader("X-User-Role") String role) {

    if ("ADMIN".equals(role)) {
        return ResponseEntity.ok(clientQueryService.getAllClients());
    }
    return ResponseEntity.ok(clientQueryService.getClientsByDepartmentId(departmentId));
}
```

### 5.5 인가(권한) 판단 기준

| 헤더 | 용도 |
|------|------|
| `X-User-Id` | 현재 로그인 사용자 식별 |
| `X-User-Role` | 역할 기반 접근 제어 (ADMIN은 전체, SALES는 본인 부서만 등) |
| `X-User-Department-Id` | 부서별 데이터 필터링 (RBAC) |
| `X-User-Email` | 감사 로그, 알림 수신자 |
| `X-User-Name` | 표시용 |

### 5.6 보안 전제 조건

- **내부 네트워크 신뢰**: 백엔드 서비스는 Docker 네트워크 내부에서만 접근 가능
- **외부 직접 접근 차단**: 백엔드 포트(8011~8014)는 외부 노출하지 않고, 반드시 Nginx(8001)를 경유
- **헤더 위조 방지**: Nginx가 `X-User-*` 헤더를 Auth 응답값으로 덮어쓰므로, 클라이언트가 직접 헤더를 보내도 무시됨

---

## 6. Nginx 설정

### nginx/default.conf

```nginx
server {
    listen 80;
    server_name localhost;

    # Vue SPA 정적 파일
    root /usr/share/nginx/html;
    index index.html;

    # SPA 라우팅 (Vue Router history mode)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # ─────────────────────────────────────
    # Auth 내부 검증용 (auth_request 대상)
    # ─────────────────────────────────────
    location = /_auth_validate {
        internal;
        proxy_pass http://backend-auth:8011/api/auth/validate;
        proxy_pass_request_body off;
        proxy_set_header Content-Length "";
        proxy_set_header Authorization $http_authorization;
    }

    # ─────────────────────────────────────
    # 인증 불필요 (로그인/토큰갱신)
    # ─────────────────────────────────────
    location /api/auth/login {
        proxy_pass http://backend-auth:8011/api/auth/login;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /api/auth/refresh {
        proxy_pass http://backend-auth:8011/api/auth/refresh;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # ─────────────────────────────────────
    # 인증 필요 - Auth 서비스 (사용자/회사/부서/직급)
    # ─────────────────────────────────────
    location /api/auth/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_email $upstream_http_x_user_email;
        auth_request_set $user_name $upstream_http_x_user_name;
        auth_request_set $user_role $upstream_http_x_user_role;
        auth_request_set $user_dept $upstream_http_x_user_department_id;

        proxy_pass http://backend-auth:8011/api/auth/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Email $user_email;
        proxy_set_header X-User-Name $user_name;
        proxy_set_header X-User-Role $user_role;
        proxy_set_header X-User-Department-Id $user_dept;
    }

    location /api/users/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_email $upstream_http_x_user_email;
        auth_request_set $user_name $upstream_http_x_user_name;
        auth_request_set $user_role $upstream_http_x_user_role;
        auth_request_set $user_dept $upstream_http_x_user_department_id;

        proxy_pass http://backend-auth:8011/api/users/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Email $user_email;
        proxy_set_header X-User-Name $user_name;
        proxy_set_header X-User-Role $user_role;
        proxy_set_header X-User-Department-Id $user_dept;
    }

    location /api/company {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-auth:8011/api/company;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/departments/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-auth:8011/api/departments/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/positions/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-auth:8011/api/positions/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    # ─────────────────────────────────────
    # 인증 필요 - Master 서비스
    # ─────────────────────────────────────
    location /api/buyers/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;
        auth_request_set $user_dept $upstream_http_x_user_department_id;

        proxy_pass http://backend-master:8012/api/buyers/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
        proxy_set_header X-User-Department-Id $user_dept;
    }

    location /api/clients/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;
        auth_request_set $user_dept $upstream_http_x_user_department_id;

        proxy_pass http://backend-master:8012/api/clients/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
        proxy_set_header X-User-Department-Id $user_dept;
    }

    location /api/countries/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-master:8012/api/countries/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/currencies/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-master:8012/api/currencies/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/incoterms/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-master:8012/api/incoterms/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/items/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-master:8012/api/items/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/payment-terms/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-master:8012/api/payment-terms/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    location /api/ports/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;

        proxy_pass http://backend-master:8012/api/ports/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
    }

    # ─────────────────────────────────────
    # 인증 필요 - Activity 서비스
    # ─────────────────────────────────────
    location /api/activities/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;
        auth_request_set $user_dept $upstream_http_x_user_department_id;

        proxy_pass http://backend-activity:8013/api/activities/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
        proxy_set_header X-User-Department-Id $user_dept;
    }

    # ─────────────────────────────────────
    # 인증 필요 - Documents 서비스
    # ─────────────────────────────────────
    location /api/documents/ {
        auth_request /_auth_validate;
        auth_request_set $user_id $upstream_http_x_user_id;
        auth_request_set $user_role $upstream_http_x_user_role;
        auth_request_set $user_dept $upstream_http_x_user_department_id;

        proxy_pass http://backend-documents:8014/api/documents/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-User-Id $user_id;
        proxy_set_header X-User-Role $user_role;
        proxy_set_header X-User-Department-Id $user_dept;
    }
}
```

---

## 6. DB 초기화 스크립트

### db/init/01-create-databases.sql

```sql
CREATE DATABASE IF NOT EXISTS team2_auth
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS team2_master
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS team2_activity
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS team2_docs
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

## 7. 배포 절차

### 7.1 로컬에서 빌드

```bash
# Frontend 빌드
cd team2-frontend
npm install && npm run build
# -> dist/ 폴더 생성

# Backend 각각 빌드 (Gradle)
cd team2-backend-auth
./gradlew clean bootJar

cd team2-backend-master
./gradlew clean bootJar

cd team2-backend-activity
./gradlew clean bootJar

cd team2-backend-documents
./gradlew clean bootJar
```

### 7.2 서버로 전송

```bash
SERVER="swcamp22-team2@playdata4.iptime.org"
PORT=8000

# 디렉토리 생성
ssh -p $PORT $SERVER "mkdir -p ~/frontend/dist ~/backend-auth/build/libs ~/backend-master/build/libs ~/backend-activity/build/libs ~/backend-documents/build/libs ~/nginx ~/db/init"

# Frontend
scp -P $PORT -r team2-frontend/dist/* $SERVER:~/frontend/dist/

# Backend JARs
scp -P $PORT team2-backend-auth/build/libs/*.jar $SERVER:~/backend-auth/build/libs/
scp -P $PORT team2-backend-master/build/libs/*.jar $SERVER:~/backend-master/build/libs/
scp -P $PORT team2-backend-activity/build/libs/*.jar $SERVER:~/backend-activity/build/libs/
scp -P $PORT team2-backend-documents/build/libs/*.jar $SERVER:~/backend-documents/build/libs/

# 설정 파일
scp -P $PORT docker-compose.yml $SERVER:~/
scp -P $PORT nginx/default.conf $SERVER:~/nginx/
scp -P $PORT db/init/*.sql $SERVER:~/db/init/
scp -P $PORT .env $SERVER:~/
```

### 7.3 서버에서 실행

```bash
ssh -p 8000 swcamp22-team2@playdata4.iptime.org

# 전체 서비스 시작
docker compose up -d

# 로그 확인
docker compose logs -f

# 개별 서비스 로그
docker compose logs -f backend-auth

# 서비스 재시작
docker compose restart backend-master

# 전체 중지
docker compose down
```

---

## 8. 접속 확인

```bash
# 프론트엔드
curl http://playdata4.iptime.org:8001

# Auth API
curl http://playdata4.iptime.org:8011/api/auth/login

# Master API
curl http://playdata4.iptime.org:8012/api/countries

# Activity API
curl http://playdata4.iptime.org:8013/api/activities

# Documents API
curl http://playdata4.iptime.org:8014/api/documents

# DB 직접 접속 (외부에서)
mysql -h playdata4.iptime.org -P 8006 -u root -p
```

---

## 9. 포트 사용 현황 요약

```
외부 노출 포트 (브라우저/클라이언트 접근 가능):
8001  ██ Frontend + API Gateway (Nginx)
8006  ██ MariaDB (개발용 외부 접속, 프로덕션에서는 제거)

내부 전용 포트 (Docker 네트워크 안에서만 접근):
8011  ██ Backend - Auth       (Nginx 경유만 허용)
8012  ██ Backend - Master     (Nginx 경유만 허용)
8013  ██ Backend - Activity   (Nginx 경유만 허용)
8014  ██ Backend - Documents  (Nginx 경유만 허용)
```

**외부 포트: 2개 / 가용 포트: 50개 -> 여유 48개**

---

## 10. 로컬 테스트 vs 리눅스 서버 차이점

| 항목 | 로컬 (Phase 1) | 리눅스 서버 (Phase 2) |
|------|----------------|----------------------|
| 접속 URL | `localhost:8001` | `playdata4.iptime.org:8001` |
| DB 외부 포트 | `3306:3306` | `8006:3306` |
| CORS origin | `http://localhost:8001` | `http://playdata4.iptime.org:8001` |
| docker-compose 위치 | 프로젝트 루트 | `~/` (홈 디렉토리) |

로컬 테스트 시에는 `docker-compose.yml`의 MariaDB 포트를 `3306:3306`으로 바꾸고, `.env`는 동일하게 사용하면 됩니다.

---

## 11. 주의사항

1. **DDL 전략 변경**: Auth/Master의 `ddl-auto`를 `create` -> `update`로 반드시 변경 (docker-compose 환경변수에서 처리)
2. **.env 파일 보안**: `.env` 파일은 절대 Git에 커밋하지 않기
3. **CORS 설정 변경**: 각 백엔드의 SecurityConfig에서 allowedOrigins를 `http://playdata4.iptime.org:8001`로 변경 필요
4. **서비스 간 통신**: Docker 네트워크 안에서는 컨테이너명으로 통신 (예: `http://backend-auth:8011`)
5. **프론트엔드 API URL**: 빌드 시 API base URL을 `http://playdata4.iptime.org:8001/api`로 설정 (Nginx 프록시 경유)
6. **data.sql 초기 데이터**: 첫 배포 시 `ddl-auto: create`로 한 번 실행 후, 이후 `update`로 변경

---
---

# Phase 3: Kubernetes + Ingress + Route53

## 12. 전체 아키텍처 (AWS EKS)

```
                    인터넷
                      |
              +-------v--------+
              |   Route53      |
              |  team2.example.com
              +-------+--------+
                      |
              +-------v--------+
              | AWS ALB        |
              | (Ingress)      |
              +-------+--------+
                      |
         +------------+------------+
         |     Kubernetes Cluster  |
         |         (EKS)          |
         |                         |
         |  ┌─────────────────┐    |
         |  │  Ingress Ctrl   │    |
         |  │  (nginx/alb)    │    |
         |  └────────+────────┘    |
         |           |             |
         |     ┌─────+─────┐      |
         |     |           |      |
         |  /          /api/*     |
         |     |           |      |
         |  ┌──v──┐  ┌────v────┐  |
         |  │ FE  │  │ BE pods │  |
         |  │ svc │  │ auth    │  |
         |  └─────┘  │ master  │  |
         |           │ activity│  |
         |           │ docs    │  |
         |           └────+────┘  |
         |                |       |
         |          ┌─────v─────┐ |
         |          │  MariaDB  │ |
         |          │ (RDS 또는  │ |
         |          │  StatefulSet)│
         |          └───────────┘ |
         +-------------------------+
```

---

## 13. Dockerfile (각 서비스별)

### Backend Dockerfile (공통 템플릿)

각 백엔드 서브모듈 루트에 `Dockerfile`을 추가합니다.

```dockerfile
# team2-backend-auth/Dockerfile (auth, master, activity, documents 동일 패턴)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY build/libs/*-SNAPSHOT.jar app.jar
EXPOSE 8011
ENTRYPOINT ["java", "-jar", "app.jar"]
```

| 서비스 | EXPOSE |
|--------|--------|
| auth | 8011 |
| master | 8012 |
| activity | 8013 |
| documents | 8014 |

### Frontend Dockerfile

```dockerfile
# team2-frontend/Dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

---

## 14. Kubernetes 매니페스트

### 14.1 Namespace

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team2
```

### 14.2 Secret (DB, JWT 등)

```yaml
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: team2-secrets
  namespace: team2
type: Opaque
stringData:
  MARIADB_ROOT_PASSWORD: "team2root!@#"
  JWT_SECRET: "YourProductionSecretKeyMustBeAtLeast256BitsLong!!@@"
  MAIL_USERNAME: "your-email@gmail.com"
  MAIL_PASSWORD: "your-app-password"
```

### 14.3 MariaDB (StatefulSet)

```yaml
# k8s/mariadb.yaml
apiVersion: v1
kind: Service
metadata:
  name: mariadb
  namespace: team2
spec:
  clusterIP: None
  ports:
    - port: 3306
  selector:
    app: mariadb
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mariadb
  namespace: team2
spec:
  serviceName: mariadb
  replicas: 1
  selector:
    matchLabels:
      app: mariadb
  template:
    metadata:
      labels:
        app: mariadb
    spec:
      containers:
        - name: mariadb
          image: mariadb:11
          ports:
            - containerPort: 3306
          env:
            - name: MARIADB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: team2-secrets
                  key: MARIADB_ROOT_PASSWORD
          volumeMounts:
            - name: mariadb-data
              mountPath: /var/lib/mysql
            - name: init-scripts
              mountPath: /docker-entrypoint-initdb.d
      volumes:
        - name: init-scripts
          configMap:
            name: mariadb-init
  volumeClaimTemplates:
    - metadata:
        name: mariadb-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

### 14.4 Backend Deployment + Service (공통 패턴)

```yaml
# k8s/backend-auth.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-auth
  namespace: team2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend-auth
  template:
    metadata:
      labels:
        app: backend-auth
    spec:
      containers:
        - name: backend-auth
          image: <ECR_REGISTRY>/team2-backend-auth:latest
          ports:
            - containerPort: 8011
          env:
            - name: SERVER_PORT
              value: "8011"
            - name: DB_URL
              value: "jdbc:mariadb://mariadb.team2.svc.cluster.local:3306/team2_auth"
            - name: DB_USERNAME
              value: "root"
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: team2-secrets
                  key: MARIADB_ROOT_PASSWORD
            - name: DB_DRIVER
              value: "org.mariadb.jdbc.Driver"
            - name: SPRING_JPA_HIBERNATE_DDL_AUTO
              value: "update"
            - name: JWT_SECRET
              valueFrom:
                secretKeyRef:
                  name: team2-secrets
                  key: JWT_SECRET
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: 8011
            initialDelaySeconds: 30
            periodSeconds: 10
          resources:
            requests:
              memory: "512Mi"
              cpu: "250m"
            limits:
              memory: "1Gi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-auth
  namespace: team2
spec:
  selector:
    app: backend-auth
  ports:
    - port: 8011
      targetPort: 8011
```

> **나머지 서비스도 동일 패턴** — 이미지명, 포트, DB_URL, 추가 환경변수만 다름:
>
> | 서비스 | 이미지 | 포트 | DB | 추가 환경변수 |
> |--------|--------|------|-----|--------------|
> | backend-master | team2-backend-master | 8012 | team2_master | - |
> | backend-activity | team2-backend-activity | 8013 | team2_activity | `DOCUMENTS_SERVICE_URL=http://backend-documents.team2.svc.cluster.local:8014` |
> | backend-documents | team2-backend-documents | 8014 | team2_docs | `AUTH_SERVICE_URL=http://backend-auth.team2.svc.cluster.local:8011` |

### 14.5 Frontend Deployment + Service

```yaml
# k8s/frontend.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: team2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: <ECR_REGISTRY>/team2-frontend:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: team2
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
```

### 14.6 Ingress (AWS ALB Ingress Controller)

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: team2-ingress
  namespace: team2
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/certificate-arn: <ACM_CERTIFICATE_ARN>
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: /
spec:
  rules:
    - host: team2.example.com
      http:
        paths:
          # Auth 서비스
          - path: /api/auth
            pathType: Prefix
            backend:
              service:
                name: backend-auth
                port:
                  number: 8011
          - path: /api/users
            pathType: Prefix
            backend:
              service:
                name: backend-auth
                port:
                  number: 8011
          - path: /api/company
            pathType: Prefix
            backend:
              service:
                name: backend-auth
                port:
                  number: 8011
          - path: /api/departments
            pathType: Prefix
            backend:
              service:
                name: backend-auth
                port:
                  number: 8011
          - path: /api/positions
            pathType: Prefix
            backend:
              service:
                name: backend-auth
                port:
                  number: 8011

          # Master 서비스
          - path: /api/buyers
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/clients
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/countries
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/currencies
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/incoterms
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/items
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/payment-terms
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012
          - path: /api/ports
            pathType: Prefix
            backend:
              service:
                name: backend-master
                port:
                  number: 8012

          # Activity 서비스
          - path: /api/activities
            pathType: Prefix
            backend:
              service:
                name: backend-activity
                port:
                  number: 8013

          # Documents 서비스
          - path: /api/documents
            pathType: Prefix
            backend:
              service:
                name: backend-documents
                port:
                  number: 8014

          # Frontend (기본 - 마지막에 배치)
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
```

---

## 15. Route53 설정

### 15.1 도메인 연결

```
team2.example.com  ->  A Record (Alias)  ->  ALB DNS Name
```

| 항목 | 값 |
|------|-----|
| Record Name | `team2.example.com` |
| Record Type | A (Alias) |
| Alias Target | ALB의 DNS name (Ingress 생성 시 자동 할당) |
| Routing Policy | Simple |

### 15.2 ACM 인증서 (HTTPS)

1. AWS Certificate Manager에서 `team2.example.com` 인증서 발급
2. Route53 DNS 검증으로 자동 인증
3. Ingress annotation의 `certificate-arn`에 인증서 ARN 설정

---

## 16. CI/CD 파이프라인 (GitHub Actions)

```
Push to main
    |
    v
GitHub Actions
    |
    ├── Build & Test (Gradle/npm)
    ├── Docker Build & Push (ECR)
    └── kubectl apply (EKS)
```

### 간략 워크플로우

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build & Push Docker images
        run: |
          # 각 서비스별 빌드 + 푸시
          for svc in backend-auth backend-master backend-activity backend-documents frontend; do
            docker build -t $ECR_REGISTRY/team2-$svc:$GITHUB_SHA ./team2-$svc
            docker push $ECR_REGISTRY/team2-$svc:$GITHUB_SHA
          done

      - name: Deploy to EKS
        run: |
          aws eks update-kubeconfig --name team2-cluster
          kubectl set image deployment/backend-auth \
            backend-auth=$ECR_REGISTRY/team2-backend-auth:$GITHUB_SHA \
            -n team2
          # ... 나머지 서비스도 동일
```

---

## 17. Phase별 전환 체크리스트

### Phase 1 -> Phase 2 (로컬 -> 리눅스 서버)

- [ ] `.env` 파일 서버에 복사 (비밀번호 변경)
- [ ] CORS origin을 `playdata4.iptime.org:8001`로 변경
- [ ] `docker compose up -d`로 서비스 기동
- [ ] 브라우저에서 `http://playdata4.iptime.org:8001` 접속 확인

### Phase 2 -> Phase 3 (Docker Compose -> K8s)

- [ ] AWS ECR 리포지토리 생성 (서비스당 1개, 총 5개)
- [ ] 각 서비스에 Dockerfile 추가
- [ ] EKS 클러스터 생성
- [ ] AWS Load Balancer Controller 설치
- [ ] K8s 매니페스트 적용 (`kubectl apply -f k8s/`)
- [ ] ACM 인증서 발급 + Ingress에 ARN 설정
- [ ] Route53에 A Record (Alias -> ALB) 등록
- [ ] CORS origin을 `https://team2.example.com`으로 변경
- [ ] HTTPS 접속 확인
- [ ] 서비스 간 통신 확인 (activity -> documents, documents -> auth)
- [ ] GitHub Actions CI/CD 파이프라인 구성
