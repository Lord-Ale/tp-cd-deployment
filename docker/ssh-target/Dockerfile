FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    docker.io \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g pm2

RUN useradd -m -s /bin/bash deployer \
    && mkdir -p /home/deployer/.ssh /home/deployer/app \
    && chmod 700 /home/deployer/.ssh \
    && chown -R deployer:deployer /home/deployer

RUN mkdir /run/sshd \
    && echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config \
    && echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config \
    && echo 'PermitRootLogin no' >> /etc/ssh/sshd_config \
    && echo 'AllowUsers deployer' >> /etc/ssh/sshd_config \
    && ssh-keygen -A

RUN echo 'registry=http://verdaccio:4873' > /home/deployer/.npmrc \
    && chown deployer:deployer /home/deployer/.npmrc

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 3000

ENTRYPOINT ["/entrypoint.sh"]
