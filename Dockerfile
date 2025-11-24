# Node.js LTS 버전 사용
FROM node:22

# 작업 디렉토리 설정
WORKDIR /app

# 패키지 설치를 위한 package.json 복사
COPY package*.json ./

# 종속성 설치
RUN npm install

# 앱 소스코드 복사
COPY . .

# 컨테이너가 사용할 포트 설정
EXPOSE 3000

# 컨테이너 실행 명령어
CMD ["node", "app.js"]