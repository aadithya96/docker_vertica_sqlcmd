FROM ubuntu:16.04

LABEL maintainer="aadithya <aadithya@carestack.com>"

ARG VERTICA_PACKAGE="vertica_9.3.0-0_amd64.deb"

ENV SHELL "/bin/bash"
ENV DEBIAN_FRONTEND noninteractive
ENV TERM 1

ADD ${VERTICA_PACKAGE} /tmp/
ADD scripts/debian_cleaner.sh /tmp/

RUN apt-get update && apt-get install -y \
	curl apt-transport-https debconf-utils \
    && rm -rf /var/lib/apt/lists/*

# adding custom MS repository
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/16.04/prod.list > /etc/apt/sources.list.d/mssql-release.list

RUN /usr/bin/apt-get update -yqq \
 && /usr/bin/apt-get upgrade --no-install-recommends -yqq \
 && /usr/bin/apt-get install --no-install-recommends -yqq curl ca-certificates locales \
 && /usr/bin/chsh -s /bin/bash root \
 && /bin/rm /bin/sh && ln -s /bin/bash /bin/sh \
 && /usr/sbin/groupadd -r verticadba \
 && /usr/sbin/useradd -r -m -s /bin/bash -g verticadba dbadmin \
 && su - dbadmin -c 'mkdir /tmp/.python-eggs' \
 && /usr/sbin/locale-gen en_US en_US.UTF-8 \
 && /usr/sbin/dpkg-reconfigure locales \
 && /usr/bin/apt-get install --no-install-recommends -yqq openssh-server openssh-client mcelog sysstat dialog \
                             libexpat1 iproute2 ntp \
 && /usr/bin/dpkg -i /tmp/${VERTICA_PACKAGE} \
 && rm /tmp/${VERTICA_PACKAGE}

# install SQL Server drivers and tools
RUN apt-get update && ACCEPT_EULA=Y apt-get install -y msodbcsql mssql-tools
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN /bin/bash -c "source ~/.bashrc"

RUN apt-get -y install locales
RUN locale-gen en_US.UTF-8
RUN update-locale LANG=en_US.UTF-8

RUN /opt/vertica/sbin/install_vertica --license CE --accept-eula --hosts 127.0.0.1 \
                                      --dba-user-password-disabled --failure-threshold NONE # --no-system-configuration

RUN /usr/bin/apt-get remove --purge -y curl ca-certificates libpython2.7 \
 && /bin/bash /tmp/debian_cleaner.sh

ENV PYTHON_EGG_CACHE /tmp/.python-eggs
ENV VERTICADATA /home/dbadmin/docker
VOLUME /home/dbadmin/
ENTRYPOINT ["/opt/vertica/bin/docker-entrypoint.sh"]
ADD ./docker-entrypoint.sh /opt/vertica/bin/

CMD /bin/bash 

EXPOSE 5433/tcp
EXPOSE 5433/udp