FROM quay.io/redhatgov/workshop-dashboard:latest

USER root

COPY . /tmp/src

# oc login 시 서버 주소가 생략되고 SSL 경고 프롬프트가 대기함으로써 발생하는 크래시 방지
RUN sed -i 's/oc login \$KUBECTL_CA_ARGS/oc login --server=https:\/\/\$KUBERNETES_SERVER --insecure-skip-tls-verify/g' /opt/workshop/bin/setup-environ.sh

RUN rm -rf /tmp/src/.git* && \
    chown -R 1001 /tmp/src && \
    chgrp -R 0 /tmp/src && \
    chmod -R g+w /tmp/src

ENV TERMINAL_TAB=split

USER 1001

RUN /usr/libexec/s2i/assemble
