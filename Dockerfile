# Stage 1: Build the bundler
FROM maven:3.8.4-openjdk-11 as bundler

# Set working directory for bundler
WORKDIR /app/bundler

# Copy bundler files and build
COPY ./bundler/pom.xml ./pom.xml
COPY ./bundler/settings.xml /root/.m2/settings.xml
RUN mvn install

# Stage 2: Build the main application (oba_app)
FROM tomcat:8.5.100-jdk11-temurin as oba_app

# Set environment variables for the app
ENV JDBC_URL=jdbc:postgresql://localhost:5432/oba_database
ENV JDBC_DRIVER=org.postgresql.Driver
ENV JDBC_USER=oba_user
ENV JDBC_PASSWORD=oba_password
ENV TZ=America/Los_Angeles
ENV TEST_API_KEY=test

# Set working directory
WORKDIR /app/oba

# Copy the main application files and other necessary configurations
COPY ./oba /app/oba

# Expose necessary ports
EXPOSE 8080
EXPOSE 1234

# Run the application
CMD ["catalina.sh", "run"]
