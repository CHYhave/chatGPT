FROM docker.io/library/java:latest
MAINTAINER haoyu.chy <949687815@qq.com>

ADD bin /home/admin/bin

ENV JAR_FILE=/home/admin/chatGPT/chatGPT.jar \
    TZ=Asia/Shanghai

ENV TERM xterm

RUN mkdir -p /home/admin/chatGPT && \
    mkdir -p /home/admin/chatGPT/logs

COPY target/*.jar  /home/admin/chatGPT/chatGPT.jar

RUN chown -R admin:admin /home/admin  && chmod -R 755 /home/admin
RUN export PATH=$PATH:/home/admin/bin

CMD ["/bin/bash", "/home/admin/bin/start.sh"]