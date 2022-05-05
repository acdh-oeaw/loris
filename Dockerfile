FROM ubuntu:20.04
MAINTAINER Dalibor Pančić <dalibor.pancic@oeaw.ac.at>
# install software
ENV DEBIAN_FRONTEND=noninteractive
RUN sed -i -e 's~http://archive~http://at.archive~' /etc/apt/sources.list && \
  apt-get update && apt-get dist-upgrade -y && \
  apt-get install -y supervisor apache2 apache2-utils libapache2-mpm-itk links curl vim locales \
                     libapache2-mod-wsgi-py3 python3-pip python3-virtualenv sudo cron \
                     libmysqlclient-dev python3-dev git  && \
  a2enmod rewrite && \
  a2enmod headers && \
  a2enmod proxy && \
  a2enmod proxy_http && \
  apt-get clean && \
  sed -i -e 's/StartServers.*/StartServers 1/g' /etc/apache2/mods-enabled/mpm_prefork.conf && \
  sed -i -e 's/MinSpareServers.*/MinSpareServers 1/g' /etc/apache2/mods-enabled/mpm_prefork.conf
# set up utf-8 locale (defaults in offical centos/ubuntu images are POSIX)
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:ean


ENV HOME=/opt \
    USER=loris \
    OPENJPG_VERSION=v2.4.0 \
    TZ='Europe/Vienna' \
    PYTHONPATH=/usr/local/lib/python3.8/site-packages 
 
# Add customized files 
COPY custom /custom

# Update packages and install tools
RUN apt-get update && apt-get upgrade -y && apt-get install -y apache2 libapache2-mod-wsgi-py3 libwebp-dev wget unzip nano cmake apache2-utils \
                                                               python-setuptools python3-pip \
                                                               libharfbuzz-dev libfribidi-dev libjpeg-turbo8-dev libfreetype6-dev zlib1g-dev \
                                                               openssl libglib2.0-dev gtk-doc-tools liblcms2-dev libffi-dev libjpeg-dev tzdata \
                                                               liblcms2-utils libssl-dev libffi-dev liblcms2-dev python3-dev libtiff5-dev  && \
    a2enmod expires && \
    a2enmod wsgi && \
    a2enmod proxy_balancer && \
    a2enmod ssl && \
    a2dismod mpm_itk && \
# Set time
    echo $TZ > /etc/timezone && \ 
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean 
# Download and compile Openjpg tag $OPENJPG_VERSION
RUN mkdir /tmp/openjpeg && \
    cd  /tmp/openjpeg && \
    git clone https://github.com/uclouvain/openjpeg.git ./ && \
    git checkout tags/$OPENJPG_VERSION && \
    mkdir build && \
    cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make && make install && make clean && \
    rm -fR /tmp/openjpeg && \
# Install kakadu
    cd /usr/local/lib && \
    wget --no-check-certificate https://github.com/loris-imageserver/loris/raw/development/lib/Linux/x86_64/libkdu_v74R.so && \
    chmod 755 libkdu_v74R.so && \
    cd /usr/local/bin && \
    wget --no-check-certificate https://github.com/loris-imageserver/loris/raw/development/bin/Linux/x86_64/kdu_expand && \
    chmod 755 kdu_expand && \
# shortlinks for other libraries
    ln -s /usr/lib/`uname -i`-linux-gnu/libfreetype.so /usr/lib/ && \
    ln -s /usr/lib/`uname -i`-linux-gnu/libjpeg.so /usr/lib/ && \
    ln -s /usr/lib/`uname -i`-linux-gnu/libz.so /usr/lib/ && \
    ln -s /usr/lib/`uname -i`-linux-gnu/liblcms.so /usr/lib/ && \
    ln -s /usr/lib/`uname -i`-linux-gnu/libtiff.so /usr/lib/ && \
    echo "/usr/local/lib" >> /etc/ld.so.conf && ldconfig

# Get loris
RUN cd /opt && \
    git clone https://github.com/loris-imageserver/loris.git && \
    cd /opt/loris && git checkout tags/v3.2.1 && \ 
# Configure apache
    cp /custom/000-default.conf /etc/apache2/sites-available/000-default.conf && \
# Add test images
    mkdir -p /usr/local/share/images /var/cache/loris /certs && \
    mkdir -p /usr/local/share/images/loris && \
    mkdir -p /tmp/loris/tmp && \ 
# Set user to loris
    adduser $USER --disabled-password --gecos "" --home /var/www/loris && \
    usermod -a -G $USER $USER 
# Install Loris

RUN cd /opt/loris && \
    sudo pip install configobj && \
    pip install requests && \
    pip install mock && \
    pip install responses && \
    pip3 install Pillow && \
    rm -f /opt/loris/loris/data/loris.conf && \
    cp /custom/loris.conf /opt/loris/loris/data/loris.conf 

WORKDIR /opt/loris

RUN python3 setup.py build && \
    python3 setup.py install && \
    python3 /opt/loris/bin/setup_directories.py && \
    cp /custom/supervisord.conf /etc/supervisor/conf.d/supervisord.conf && \
    cp -r /custom/cleanScripts /cleanScripts && \
    cp /custom/loris-cron /etc/cron.d/ && \
    chmod 0644 /etc/cron.d/loris-cron && \
    crontab /etc/cron.d/loris-cron && \
    cp /custom/entrypoint.sh / && \
    chmod +x /entrypoint.sh && \
    # Clean
    rm -fR /custom && \
    cd /certs && openssl req -newkey rsa:2048 -nodes -x509 -days 365 -subj "/C=AT/ST=Vienna/L=Vienna/O=ACDH/OU=AG2/CN=loris.acdh-cluster.arz.oeaw.ac.at" -out loris.acdh-cluster.arz.oeaw.ac.at.pem -keyout loris.acdh-cluster.arz.oeaw.ac.at.key   
#@INJECT_USER@

VOLUME  /usr/local/share/images  /var/log/loris /var/cache/loris

EXPOSE 443

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord"]

