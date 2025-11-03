# base image
ARG ARCH=arm64v8
FROM $ARCH/debian:buster-slim

# args
ARG VCS_REF
ARG BUILD_DATE

# environment
ENV ADMIN_PASSWORD=admin

# install packages (每行一个包，分步安装并检查错误)
RUN apt-get update

# 逐个安装并检查，失败时输出具体包名
RUN apt-get install -y sudo || { echo "安装失败：sudo"; exit 1; }
RUN apt-get install -y cups || { echo "安装失败：cups"; exit 1; }
RUN apt-get install -y cups-bsd || { echo "安装失败：cups-bsd"; exit 1; }
RUN apt-get install -y cups-filters || { echo "安装失败：cups-filters"; exit 1; }
RUN apt-get install -y foomatic-db-compressed-ppds || { echo "安装失败：foomatic-db-compressed-ppds"; exit 1; }
RUN apt-get install -y printer-driver-all || { echo "安装失败：printer-driver-all"; exit 1; }
RUN apt-get install -y openprinting-ppds || { echo "安装失败：openprinting-ppds"; exit 1; }
RUN apt-get install -y hpijs-ppds || { echo "安装失败：hpijs-ppds"; exit 1; }
RUN apt-get install -y hp-ppd || { echo "安装失败：hp-ppd"; exit 1; }
RUN apt-get install -y hplip || { echo "安装失败：hplip"; exit 1; }  # 大概率是这个包在ARM64上有问题
RUN apt-get install -y dumb-init || { echo "安装失败：dumb-init"; exit 1; }

# 清理缓存
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# add print user
RUN adduser --home /home/admin --shell /bin/bash --gecos "admin" --disabled-password admin \
  && adduser admin sudo \
  && adduser admin lp \
  && adduser admin lpadmin

# disable sudo password checking
RUN echo 'admin ALL=(ALL:ALL) ALL' >> /etc/sudoers

# enable access to CUPS
RUN /usr/sbin/cupsd \
  && while [ ! -f /var/run/cups/cupsd.pid ]; do sleep 1; done \
  && cupsctl --remote-admin --remote-any --share-printers \
  && kill $(cat /var/run/cups/cupsd.pid) \
  && echo "ServerAlias *" >> /etc/cups/cupsd.conf

# copy /etc/cups for skeleton usage
RUN cp -rp /etc/cups /etc/cups-skel

# set default password for user 'admin' to 'admin'
RUN echo "admin:admin" | chpasswd

# user management script
ADD user-management.bash /usr/local/bin/user-management

# starting command
ADD docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
CMD ["dumb-init", "-v", "/usr/local/bin/docker-entrypoint.sh"]

# volumes
VOLUME ["/etc/cups"]

# ports
EXPOSE 631

# healthcheck
HEALTHCHECK --interval=30s --timeout=10s --retries=3 CMD pidof cupsd > /dev/null 2>&1
