FROM python:2.7.12-wheezy
RUN apt-get update && \
    apt-get install -y iptables sudo

ADD src/* /usr/bin/
RUN chmod +x /usr/bin/stop-firewall.sh

ENV PYTHONPATH="/usr/bin"
