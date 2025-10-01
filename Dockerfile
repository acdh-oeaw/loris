FROM ubuntu:24.04
LABEL org.opencontainers.image.authors=<mzoltak@oeaw.ac.at>
# install software
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    HOME=/opt \
    OPENJPG_VERSION=v2.5.4 \
    TZ='Europe/Vienna' \
    PYTHONPATH=/usr/local/lib/python3.8/site-packages 
 
# Add customized files 
COPY root /root

# Update packages and install tools
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y apache2 libapache2-mod-wsgi-py3 apache2-utils \
                       cron git unzip nano cmake locales vim git wget supervisor \
                       python3-venv python3-pip \
                       libwebp-dev libharfbuzz-dev libfribidi-dev libjpeg-turbo8-dev libfreetype6-dev zlib1g-dev \
                       openssl libglib2.0-dev gtk-doc-tools liblcms2-dev libffi-dev libjpeg-dev tzdata \
                       liblcms2-utils libssl-dev libffi-dev liblcms2-dev python3-dev libtiff5-dev  && \
    locale-gen en_US.UTF-8 && \
# Set time and generate locale
    echo $TZ > /etc/timezone && \ 
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
# Configure apache
    mv /root/000-default.conf /etc/apache2/sites-available/000-default.conf && \
    a2enmod rewrite && \
    a2enmod headers && \
    a2enmod expires && \
    a2enmod wsgi && \
# Supervisor
    mkdir -p /etc/supervisor/conf.d/ && \
    mv /root/supervisord.conf /etc/supervisor/conf.d/supervisord.conf && \
# Cron
    mv /root/loris-cron /etc/cron.d/loris-cron &&\
    crontab /etc/cron.d/loris-cron && \
# Cleanup
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
    git clone https://github.com/loris-imageserver/loris.git &&\
    cd /opt/loris && git checkout tags/v3.2.1 &&\ 
    cat /root/ArcheResolver.py >> /opt/loris/loris/resolver.py &&\
    mv /root/loris.conf /opt/loris/loris/data/loris.conf &&\
    apt-get remove -y python3-chardet &&\
    # patch loris so it accepts all formats supported by the pillow package
    sed -i -e 's/elif self.src_format in .*/elif self.src_format in Image.registered_extensions():/' loris/img_info.py &&\
    python3 -m venv /opt/loris/venv &&\
    export PATH="/opt/loris/venv/bin:$PATH" &&\
    pip install pip-tools &&\
    # fix dependencies
    sed -i -e 's/werkzeug .*/werkzeug >= 0.11.4,< 1.0/' requirements.in &&\
    pip-compile -r -U requirements.in &&\
    pip uninstall -y pip-tools &&\
    pip install . &&\
    python3 /opt/loris/bin/setup_directories.py &&\
    # ARCHE-specific stuff
    mv /root/restrictedAccess.png /opt/loris/restrictedAccess.png &&\
    mkdir /tmp/static && chown www-data:www-data /tmp/static

WORKDIR /opt/loris
VOLUME  /var/log/loris /var/cache/loris
EXPOSE 80
ENTRYPOINT ["/root/entrypoint.sh"]
CMD ["/usr/bin/supervisord"]

