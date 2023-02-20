FROM reg.docker.alibaba-inc.com/cnstack/cnstack-java:1.0-beta
MAINTAINER jingfeng.xjf <jingfeng.xjf@alibaba-inc.com>

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