###########
# Builder #
###########

FROM tomcat:8.5.100-jdk11-temurin AS builder

# Define the OneBusAway and connector versions as build arguments
ARG OBA_VERSION=2.5.13-otsf
ARG MYSQL_CONNECTOR_VERSION=8.4.0
ARG POSTGRESQL_CONNECTOR_VERSION=42.7.4

# Set environment variables for these versions
ENV OBA_VERSION=${OBA_VERSION} \
    MYSQL_CONNECTOR_VERSION=${MYSQL_CONNECTOR_VERSION} \
    POSTGRESQL_CONNECTOR_VERSION=${POSTGRESQL_CONNECTOR_VERSION}

# Install necessary dependencies
RUN apt-get update && \
    apt-get install -y maven golang && \
    apt-get clean

# Build the template renderer (hbs_renderer)
WORKDIR /oba/template_renderer
COPY ./config/template_renderer .
RUN go build -o hbs_renderer

# Configure OBA with Maven
WORKDIR /oba/libs
COPY ./config/pom.xml ./pom.xml
COPY ./config/settings.xml /root/.m2/settings.xml

# Download and install dependencies
RUN mvn -f pom.xml install --batch-mode -DskipTests

# Run custom script to retrieve Maven artifacts
COPY ./retrieve_maven_artifacts.sh .
RUN chmod +x ./retrieve_maven_artifacts.sh && ./retrieve_maven_artifacts.sh

##########
# Server #
##########

FROM tomcat:8.5.100-jdk11-temurin AS server

# Set environment variables
ENV CATALINA_HOME=/usr/local/tomcat
ENV TZ=America/New_York

# Set user/group arguments for non-root user creation
ARG GID=1000
ARG UID=1000
ARG GROUP=oba_group
ARG USER=oba_user

# Install necessary tools for the server
RUN apt-get update && \
    apt-get install -y jq python3-pip supervisor tzdata unzip wget && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Supervisor-dependent startup
RUN pip install supervisord-dependent-startup && \
    apt remove -y python3-pip

# Copy hbs_renderer from builder stage
COPY --from=builder /oba/template_renderer/hbs_renderer /usr/local/bin/hbs_renderer

# Configure time zone
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

# Create non-root user and assign ownership
RUN groupadd -g $GID $GROUP && \
    useradd -d /home/$USER -u $UID -m -s /bin/bash -g $GROUP $USER && \
    chown -R $USER:$GROUP $CATALINA_HOME && \
    mkdir -p /var/log/tomcat8 && \
    chown -R $USER:$GROUP /var/log/tomcat8

##########
# Configure OBA Bundle Builder
##########

WORKDIR /oba/libs
COPY --from=builder --chown=oba_user:oba_group /oba/libs/onebusaway-transit-data-federation-builder-withAllDependencies.jar .

##########
# Copy Config Files
##########

WORKDIR /oba/config

COPY ./config/context.xml.hbs .
COPY ./config/onebusaway-api-webapp-data-sources.xml.hbs .
COPY ./config/onebusaway-transit-data-federation-webapp-data-sources.xml.hbs .

##########
# Configure OBA Server and Web Apps
##########

WORKDIR $CATALINA_HOME/webapps

# Configure onebusaway-api-webapp
COPY --from=builder --chown=oba_user:oba_group /oba/libs/onebusaway-api-webapp.war .
RUN mkdir ROOT && \
    cd ROOT && \
    jar xvf ../onebusaway-api-webapp.war && \
    rm ../onebusaway-api-webapp.war

COPY --from=builder --chown=oba_user:oba_group /oba/libs/mysql-connector-j.jar $CATALINA_HOME/webapps/ROOT/WEB-INF/lib/
COPY --from=builder --chown=oba_user:oba_group /oba/libs/postgresql.jar $CATALINA_HOME/webapps/ROOT/WEB-INF/lib/

# Configure onebusaway-transit-data-federation-webapp
COPY --from=builder --chown=oba_user:oba_group /oba/libs/onebusaway-transit-data-federation-webapp.war .
RUN mkdir onebusaway-transit-data-federation-webapp && \
    cd onebusaway-transit-data-federation-webapp && \
    jar xvf ../onebusaway-transit-data-federation-webapp.war && \
    rm ../onebusaway-transit-data-federation-webapp.war

COPY --from=builder --chown=oba_user:oba_group /oba/libs/mysql-connector-j.jar onebusaway-transit-data-federation-webapp/WEB-INF/lib/
COPY --from=builder --chown=oba_user:oba_group /oba/libs/postgresql.jar onebusaway-transit-data-federation-webapp/WEB-INF/lib/

##########
# Set Up Logs and Clean Up
##########

RUN mkdir -p /opt/oba/logs && \
    chown -R oba_user:oba_group /opt/oba/logs && \
    chmod 755 /opt/oba/logs

RUN apt-get autoremove -y && apt-get clean
RUN rm -rf /oba/webapps

##########
# JMX Exporter Setup
##########

RUN mkdir -p /app && \
    wget -O /app/jmx_prometheus_javaagent.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.19.0/jmx_prometheus_javaagent-0.19.0.jar

COPY ./jmx_exporter_config.yml /app/jmx_exporter_config.yml

# Set JVM options to include JMX exporter
ENV JAVA_OPTS="-javaagent:/app/jmx_prometheus_javaagent.jar=1234:/app/jmx_exporter_config.yml"

##########
# Bootstrapper and Supervisor
##########

COPY bootstrap.sh /oba/bootstrap.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /oba/bootstrap.sh

# Start Supervisor to manage processes
CMD ["supervisord", "-n"]
