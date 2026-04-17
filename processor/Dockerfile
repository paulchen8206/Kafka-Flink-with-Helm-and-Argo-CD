FROM maven:3.9.9-eclipse-temurin-17 AS build

WORKDIR /workspace

COPY pom.xml ./
COPY src ./src

RUN mvn -q -DskipTests package

FROM eclipse-temurin:17-jre

WORKDIR /app

COPY --from=build /workspace/target/realtime-processor-0.1.0-all.jar /app/app.jar

ENTRYPOINT ["java", "--add-opens=java.base/java.util=ALL-UNNAMED", "-jar", "/app/app.jar"]
