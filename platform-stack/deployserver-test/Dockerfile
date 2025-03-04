FROM ubuntu:24.04

RUN apt update

RUN apt install -y --no-install-recommends \
    python3 \
    openssh-server \
    sudo \
    ca-certificates

RUN update-ca-certificates

# Ok for testing purposes, DO NOT USE IN PRODUCTION!
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN echo "root:root" | chpasswd

RUN service ssh start

RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Exposes port not to host, but to other containers, which allows for inter container communication
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

