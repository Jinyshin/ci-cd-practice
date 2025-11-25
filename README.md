# Blue/Green Deployment with GitHub Actions

Blue/Green 배포 전략을 사용하여 트래픽을 신규 컨테이너로 전환함으로써 서비스 중단 없이 안정적으로 애플리케이션을 배포하는 CI/CD 파이프라인 구현 프로젝트입니다.

## 개요

이 프로젝트는 다음과 같은 기술 스택을 사용합니다:

- **애플리케이션**: Node.js + Express
- **컨테이너화**: Docker, Docker Compose
- **리버스 프록시**: Nginx
- **CI/CD**: GitHub Actions
- **배포 전략**: Blue/Green Deployment
- **인프라**: AWS EC2

## 사전 준비

- AWS EC2 인스턴스 (Ubuntu)
- Docker Hub 계정
- GitHub Repository
- SSH 키 페어

## 프로젝트 구조

```
ci-practice/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions 워크플로우
├── app.js                     # Express 애플리케이션
├── Dockerfile                 # 도커 이미지 빌드 설정
├── .dockerignore              # 도커 빌드 제외 파일
├── package.json               # Node.js 의존성
└── README.md
```

**EC2 서버 (`~/bluegreen/`):**

```
bluegreen/
├── docker-compose.yml         # Blue/Green 컨테이너 및 Nginx 설정
└── nginx.conf                 # Nginx 리버스 프록시 설정
```

## 설정 가이드

### 1. GitHub Secret 환경 변수 등록

GitHub Repository의 `Settings` > `Secrets and variables` > `Actions`에서 다음 환경 변수를 등록합니다:

```
DOCKER_USERNAME=your-dockerhub-username
DOCKER_TOKEN=your-dockerhub-access-token

SERVER_USER=ubuntu
SERVER_HOST=your-ec2-public-ip

SSH_PRIVATE_KEY=
-----BEGIN RSA PRIVATE KEY-----
your-private-key-content
-----END RSA PRIVATE KEY-----
```

### 2. EC2 보안 그룹 설정

**중요**: 인바운드 규칙에서 다음 포트를 허용해야 합니다.

- AWS EC2 콘솔 → 인스턴스 선택 → 보안 그룹 → 인바운드 규칙 편집
- **SSH**: TCP, Port 22 (GitHub Actions 배포용)
- **HTTP**: TCP, Port 80 (애플리케이션 접근용)

### 3. Docker 네트워크 생성

EC2 서버에 SSH 접속 후, Blue/Green 컨테이너와 Nginx가 서로 통신할 수 있도록 공통 네트워크를 생성합니다:

```bash
docker network create backend-proxy
```

### 4. Docker Compose 설정

EC2 서버에서 작업 디렉토리를 생성하고 `docker-compose.yml` 파일을 작성합니다:

```bash
mkdir -p /home/ubuntu/bluegreen && cd /home/ubuntu/bluegreen
vi docker-compose.yml
```

**docker-compose.yml:**

```yaml
services:
  express-healthcheck-blue:
    image: yourdockerhub/express-healthcheck:latest
    container_name: express-healthcheck-blue
    restart: always
    ports:
      - "3001:3000"
    networks:
      - backend-proxy

  express-healthcheck-green:
    image: yourdockerhub/express-healthcheck:latest
    container_name: express-healthcheck-green
    restart: always
    ports:
      - "3002:3000"
    networks:
      - backend-proxy

  nginx-proxy:
    image: nginx:stable-alpine
    container_name: nginx-proxy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    networks:
      - backend-proxy

networks:
  backend-proxy:
    external: true
```

### 5. Nginx 설정

동일한 디렉토리에 `nginx.conf` 파일을 생성합니다:

```bash
vi nginx.conf
```

**nginx.conf:**

```nginx
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://express-healthcheck-blue:3000;  # 시작은 blue
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### 6. 파일 권한 설정

GitHub Actions가 SSH로 접속하는 계정의 소유권을 설정합니다:

```bash
sudo chown -R ubuntu:ubuntu /home/ubuntu/
```

**Docker 권한 부여:**

```bash
sudo usermod -aG docker ubuntu
sudo reboot
```

## 배포 프로세스

1. **코드 푸시**: `main` 브랜치에 코드를 푸시하면 GitHub Actions 워크플로우가 자동으로 실행됩니다.

2. **이미지 빌드 및 푸시**: Docker 이미지를 빌드하고 Docker Hub에 푸시합니다.

3. **Blue/Green 전환**:

   - 현재 실행 중인 컨테이너 확인 (Blue 또는 Green)
   - 새로운 컨테이너 실행
   - Health Check 수행 (최대 10회, 각 2초 간격)
   - Health Check 성공 시 Nginx 설정을 새 컨테이너로 전환
   - 이전 컨테이너 종료

4. **롤백**: Health Check 실패 시 자동으로 이전 컨테이너로 롤백됩니다.

### 배포 흐름 예시

```
최초 배포: Blue 컨테이너 실행
재배포 1: Green 컨테이너 실행 → Health Check → Nginx 전환 → Blue 중지
재배포 2: Blue 컨테이너 실행 → Health Check → Nginx 전환 → Green 중지
재배포 3: Green 컨테이너 실행 → Health Check → Nginx 전환 → Blue 중지
...
```

## 무중단 배포 테스트

배포가 정말 무중단으로 이루어지는지 확인하려면, 로컬에서 반복 요청을 보내면서 재배포를 진행합니다:

```bash
while true; do curl -s http://[EC2-PUBLIC-IP]/health; sleep 0.5; done
```

정상적인 경우 다음과 같이 응답이 끊김 없이 계속 출력됩니다:

```
OK - 15:23:01
OK - 15:23:01
OK - 15:23:02
OK - 15:23:02
OK - 15:23:03
...
```

**배포 중 컨테이너 상태 확인:**

EC2 서버에서 `docker ps`를 반복 실행하면 다음과 같은 변화를 관찰할 수 있습니다:

```bash
# 배포 시작 전: Blue만 실행 중
CONTAINER ID   IMAGE                                 STATUS          NAMES
fc125b3d3147   jinyshin/express-healthcheck:latest   Up 33 minutes   express-healthcheck-blue
0b0914c245ec   nginx:stable-alpine                   Up 4 minutes    nginx-proxy

# 배포 중: Blue와 Green 모두 실행 중 (Health Check 진행)
CONTAINER ID   IMAGE                                 STATUS          NAMES
6125896c1900   jinyshin/express-healthcheck:latest   Up 2 minutes    express-healthcheck-green
fc125b3d3147   jinyshin/express-healthcheck:latest   Up 35 minutes   express-healthcheck-blue
0745ae2a2284   nginx:stable-alpine                   Up 2 minutes    nginx-proxy

# 배포 완료: Green만 실행 중 (Blue 종료됨)
CONTAINER ID   IMAGE                                 STATUS          NAMES
a9a638414fc4   jinyshin/express-healthcheck:latest   Up 15 seconds   express-healthcheck-green
8c2369258d7f   nginx:stable-alpine                   Up 12 seconds   nginx-proxy
```
