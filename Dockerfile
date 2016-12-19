FROM python:2.7.12-wheezy
RUN apt-get update && \
    apt-get install -y iptables sudo

ADD src/* /usr/bin/

ENV PYTHONPATH="/usr/bin"
