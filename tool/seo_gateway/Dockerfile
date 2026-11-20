FROM node:22-alpine

WORKDIR /app
ENV NODE_ENV=production \
    PORT=8080 \
    FLUTTER_WEB_ROOT=/app/build/web

COPY build/web /app/build/web
COPY tool/seo_gateway/server.mjs /app/tool/seo_gateway/server.mjs

EXPOSE 8080
CMD ["node", "tool/seo_gateway/server.mjs"]
