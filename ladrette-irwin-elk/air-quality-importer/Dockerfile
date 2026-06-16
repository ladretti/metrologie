FROM docker.elastic.co/logstash/logstash:8.19.16

USER root
RUN mkdir -p /data
COPY datasets/Air_Quality.log /data/Air_Quality.log
COPY air-quality-importer/pipeline/air-quality.conf /usr/share/logstash/pipeline/logstash.conf

USER logstash
ENV XPACK_MONITORING_ENABLED=false
ENV LS_JAVA_OPTS="-Xms256m -Xmx256m"
