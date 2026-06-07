FROM eclipse-temurin:26.0.1_8-jre-alpine-3.23

RUN addgroup -S nonRootGroup && adduser -S nonRootUser -G nonRootGroup

RUN mkdir -p /app && chown -R nonRootUser:nonRootGroup /app

RUN apk add --no-cache wget

COPY --chown=appuser:appgroup target/*.jar /app/app.jar

ENV SPRING_MAIN_BANNER-MODE=off

USER nonRootUser

WORKDIR /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]