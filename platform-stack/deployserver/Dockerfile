FROM alpine:3.21.3

RUN apk update

RUN apk add --no-cache \
    python3 \
    openssh \
    sudo \
    ca-certificates \
    shadow \
    fuse-overlayfs # mount program required by podman to work, as the defult overlay driver of alpine (overlay) cannot
                   # run on top of another overlay filesystem (which is the case when running inside a docker container)

RUN update-ca-certificates

# Ok for testing purposes, DO NOT USE IN PRODUCTION!
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN echo "root:root" | chpasswd

RUN rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Exposes port not to host, but to other containers, which allows for inter container communication
EXPOSE 22

# Ok for testing purposes, DO NOT USE IN PRODUCTION, AS KEYS ARE FIXED WITH THE IMAGE!
RUN ssh-keygen -A

CMD ["/usr/sbin/sshd", "-D"]

