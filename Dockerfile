FROM eclipse-temurin:17-jdk-alpine AS build
WORKDIR /workspace/app

# Optimizar caché de capas copiando primero solo los archivos necesarios para resolver dependencias
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# Descargar dependencias para aprovechar la caché
RUN chmod +x ./mvnw && ./mvnw dependency:go-offline -B

# Ahora copiar el código fuente y compilar
COPY src src
RUN ./mvnw package -DskipTests
RUN mkdir -p target/dependency && (cd target/dependency; jar -xf ../*.jar)

FROM eclipse-temurin:17-jre-alpine
VOLUME /tmp
ARG DEPENDENCY=/workspace/app/target/dependency

# Instalar curl para healthcheck
RUN apk add --no-cache curl

COPY --from=build ${DEPENDENCY}/BOOT-INF/lib /app/lib
COPY --from=build ${DEPENDENCY}/META-INF /app/META-INF
COPY --from=build ${DEPENDENCY}/BOOT-INF/classes /app

# Crear usuario no-root
RUN addgroup --system --gid 1001 appgroup && \
    adduser --system --uid 1001 --ingroup appgroup appuser && \
    chown -R appuser:appgroup /app
USER appuser

EXPOSE 8761
ENTRYPOINT ["java","-Djava.security.egd=file:/dev/./urandom","-cp","app:app/lib/*","com.uguimar.servicediscovery.ServiceDiscoveryApplication"]