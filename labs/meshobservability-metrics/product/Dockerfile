FROM registry.ocp4.example.com:8443/ubi8/nodejs-16

COPY package.json package-lock.json ./
RUN npm ci

COPY . ./

EXPOSE 8080
CMD ["node", "server.js"]
