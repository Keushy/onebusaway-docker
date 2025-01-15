#########
# Maven #
#########

# Use a base image with Maven and Java pre-installed
FROM tomcat:8.5.100-jdk11-temurin AS builder

# Set the OneBusAway version to build
ARG OBA_VERSION=2.5.13-otsf
ENV OBA_VERSION=${OBA_VERSION}

# Update system packages and install Maven
RUN apt-get update && apt-get install -y maven

# Set the working directory
WORKDIR /oba

# Copy the necessary Maven files
COPY ./pom.xml ./pom.xml
COPY ./settings.xml /root/.m2/settings.xml

# Download and prepare the OneBusAway federation builder JAR
RUN mvn org.apache.maven.plugins:maven-dependency-plugin:3.2.0:get \
    --batch-mode \
    -Dartifact=org.onebusaway:onebusaway-transit-data-federation-builder:${OBA_VERSION}:jar:withAllDependencies && \
    cp /root/.m2/repository/org/onebusaway/onebusaway-transit-data-federation-builder/${OBA_VERSION}/onebusaway-transit-data-federation-builder-${OBA_VERSION}-withAllDependencies.jar \
       ./onebusaway-transit-data-federation-builder-withAllDependencies.jar

###########
# Bundler #
###########

# Use a lightweight base image for running the bundler
FROM tomcat:8.5.100-jdk11-temurin

# Set the OneBusAway version in the environment
ARG OBA_VERSION=2.5.13-otsf
ENV OBA_VERSION_ENV=$OBA_VERSION

# Set the working directory
WORKDIR /oba

# Copy the prepared JAR file from the builder stage
COPY --from=builder /oba/onebusaway-transit-data-federation-builder-withAllDependencies.jar .

# Copy the script for building the GTFS bundle
COPY ./build_bundle.sh .

# Ensure the script is executable
RUN chmod +x build_bundle.sh

# Command to run the bundler
CMD ["/oba/build_bundle.sh"]

# Uncomment this line for debugging purposes
# CMD ["tail", "-f", "/dev/null"]
