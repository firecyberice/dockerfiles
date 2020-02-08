FROM debian:buster AS wsgi

RUN apt-get update && \
    apt-get install -y \
    apache2 \
    git \
    python3 \
    python3-pip \
    libapache2-mod-wsgi-py3 \
    python3-dev \
    default-libmysqlclient-dev && \
    apt-get autoclean

ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_LOCK_DIR=/var/run/apache2

RUN a2enmod wsgi \
    && mkdir -p /docker-entrypoint-init.d

COPY src/fs/ /
# django project name used by apache2
ENV APP_NAME=demoapp
# app webroot
WORKDIR /var/www/app
VOLUME ["/var/www/static"]
EXPOSE 80
# end apache2 config

ENTRYPOINT ["docker-entrypoint.sh"]
#RUN pip3 install Django==1.10.4



FROM wsgi AS release

RUN apt-get install -y  \
    python3-mysqldb

RUN pip3 install \
    mysqlclient \
    PyMySQL

ENV APP_NAME=src/nsupdate
ARG NSUPDATE_VERSION
ENV NSUPDATE_VERSION=${NSUPDATE_VERSION:-master}

LABEL nsupdate.info.branch=${NSUPDATE_VERSION}

RUN echo "nsupdate version: ${NSUPDATE_VERSION}"
#RUN pip3 install --install-option="--prefix=/var/www/app" nsupdate
# get sources
RUN git clone --branch ${NSUPDATE_VERSION} https://github.com/nsupdate-info/nsupdate.info /var/www/app/

COPY src/nsupdate /var/www/app/${APP_NAME}

# install dependencies
RUN chown -R 33:33 /var/www/app \
    && pip3 install -r requirements.d/all.txt \
    && pip3 install -r requirements.d/dev.txt \
    && pip3 install -e .

#RUN pip3 install python-social-auth==0.2.21

ENV DJANGO_SETTINGS_MODULE=settings
ENV SECRET_KEY=demokey
RUN a2enmod remoteip

COPY src/init.sh /docker-entrypoint-init.d/
COPY src/apache2.conf /etc/apache2/sites-enabled/000-default.conf

