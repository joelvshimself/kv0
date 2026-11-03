FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci --only=production

COPY tsconfig.json ./
COPY src ./src

RUN npm install -D typescript tsx && npm run build

RUN npm prune --production

EXPOSE 3000

CMD ["npm", "start"]
