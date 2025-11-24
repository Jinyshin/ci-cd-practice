# CI/CD Practice

GitHub Actions를 사용한 CI/CD 파이프라인 실습 프로젝트입니다.

## 프로젝트 개요

간단한 Express.js 애플리케이션을 통해 **지속적 통합(CI)** 과 **지속적 배포(CD)** 를 구현한 프로젝트입니다.
코드가 `main` 브랜치에 푸시되면 자동으로 테스트를 실행하고, Docker 이미지를 빌드하여 AWS EC2에 배포합니다.

## 기술 스택

- **Runtime**: Node.js 22
- **Framework**: Express.js
- **Testing**: Jest, Supertest
- **CI/CD**: GitHub Actions
- **Containerization**: Docker
- **Deployment**: AWS EC2

## 프로젝트 구조

```
ci-practice/
├── .github/
│   └── workflows/
│       └── ci-cd.yml          # GitHub Actions 워크플로우
├── tests/
│   └── app.test.js            # 테스트 파일
├── app.js                      # Express 애플리케이션
├── Dockerfile                  # Docker 이미지 빌드 설정
├── package.json
└── README.md
```

## 주요 기능

### 1. Continuous Integration (CI)

- **자동 테스트**: `main` 브랜치에 Push 또는 Pull Request 시 자동 테스트 실행
- **멀티 버전 테스트**: Node.js 19.x, 20.x, 22.x 환경에서 병렬 테스트

### 2. Continuous Deployment (CD)

- **Docker 이미지 빌드**: 테스트 통과 시 자동으로 Docker 이미지 빌드
- **Docker Hub 푸시**: 빌드된 이미지를 Docker Hub에 자동 업로드
- **자동 배포**: EC2 인스턴스에 SSH 접속하여 Docker Compose로 배포

## CI/CD 파이프라인 흐름

```
1. 코드 Push (main 브랜치)
   ↓
2. 테스트 실행 (Jest)
   - Node.js 19.x
   - Node.js 20.x
   - Node.js 22.x
   ↓
3. Docker 이미지 빌드 및 푸시
   ↓
4. EC2 배포
   - SSH 접속
   - Docker Compose로 컨테이너 업데이트
```

## 로컬 실행 방법

### 1. 의존성 설치

```bash
npm install
```

### 2. 애플리케이션 실행

```bash
npm start
```

서버가 실행되면 `http://localhost:3000`에서 "Hello, World!"를 확인할 수 있습니다.

### 3. 테스트 실행

```bash
npm test
```

## GitHub Actions 설정

### 필수 Secrets

GitHub 리포지토리의 Settings > Secrets and variables > Actions에 다음 값을 등록해야 합니다:

| Secret 이름       | 설명                   | 예시                                    |
| ----------------- | ---------------------- | --------------------------------------- |
| `DOCKER_USERNAME` | Docker Hub 사용자 이름 | `your-username`                         |
| `DOCKER_TOKEN`    | Docker Hub 액세스 토큰 | Docker Hub에서 발급                     |
| `SSH_PRIVATE_KEY` | EC2 SSH 프라이빗 키    | `~/.ssh/id_rsa` 내용                    |
| `SERVER_HOST`     | EC2 퍼블릭 DNS         | `ec2-xx-xx-xx-xx.compute.amazonaws.com` |
| `SERVER_USER`     | EC2 사용자 이름        | `ubuntu`                                |

### Actions 권한 설정

Settings > Actions > General에서:

- **Actions permissions**: `Allow all actions and reusable workflows` 선택
- **Workflow permissions**: `Read and write permissions` 선택

## AWS EC2 배포 설정

### 1. Docker 설치 (EC2)

```bash
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker ubuntu
```

### 2. 프로젝트 디렉토리 생성 (EC2)

```bash
mkdir -p /home/ubuntu/backend
cd /home/ubuntu/backend
```

### 3. docker-compose.yml 작성 (EC2)

```yaml
services:
  express-hello-world:
    image: your-username/express-hello-world:latest
    ports:
      - "3000:3000"
    container_name: express-hello-world
```

### 4. 보안 그룹 설정

AWS EC2 인스턴스의 보안 그룹에서 다음 포트를 개방해야 합니다:

- **TCP 22번 포트**: GitHub Actions가 SSH로 배포 명령 실행
- **TCP 3000번 포트**: 브라우저에서 애플리케이션 접근

## 워크플로우 단계별 설명

### Job 1: Test

다양한 Node.js 버전에서 애플리케이션 테스트를 실행합니다.

```yaml
- 코드 체크아웃
- Node.js 환경 설정
- 의존성 설치
- 테스트 실행
```

### Job 2: Build and Push Image

테스트 통과 후 Docker 이미지를 빌드하고 Docker Hub에 푸시합니다.

```yaml
- Docker Hub 로그인
- Docker 이미지 빌드 (linux/amd64)
- Docker Hub에 푸시
```

### Job 3: Deploy

EC2 인스턴스에 최신 이미지를 배포합니다.

```yaml
- SSH 키 준비
- Docker/Node.js 설치 확인 (미설치 시 자동 설치)
- Docker Compose로 컨테이너 업데이트
```
