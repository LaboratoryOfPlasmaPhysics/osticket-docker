# taken from https://mpolinowski.github.io/docs/DevOps/Provisioning/2023-03-09--os-ticket-docker-2023/2023-03-09/
FROM php:8.1-fpm-alpine3.16

RUN set -ex; \
    \
    export CFLAGS="-Os"; \
    export CPPFLAGS="${CFLAGS}"; \
    export LDFLAGS="-Wl,--strip-all"; \
    \
    # Runtime dependencies
    apk add --no-cache \
        c-client \
        icu \
        libintl \
        libpng \
        libzip \
        msmtp \
        nginx \
        openldap \
        runit \
    ; \
    \
    # Build dependencies
    apk add --no-cache --virtual .build-deps \
        ${PHPIZE_DEPS} \
        gettext-dev \
        icu-dev \
        imap-dev \
        libpng-dev \
        libzip-dev \
        openldap-dev \
    ; \
    \
    # Install PHP extensions
    docker-php-ext-configure imap --with-imap-ssl; \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        gettext \
        imap \
        intl \
        ldap \
        mysqli \
        sockets \
        zip \
    ; \
    pecl install apcu; \
    docker-php-ext-enable \
        apcu \
        opcache \
    ; \
    \
    # Create msmtp log
    touch /var/log/msmtp.log; \
    chown www-data:www-data /var/log/msmtp.log; \
    \
    # Create data dir
    mkdir /var/lib/osticket; \
    \
    # Clean up
    apk del .build-deps; \
    rm -rf /tmp/pear /var/cache/apk/*
# DO NOT FORGET TO CHECK THE LANGUAGE PACK DOWNLOAD URL BELOW
ENV OSTICKET_VERSION=1.18.1 \
    OSTICKET_SHA256SUM=0802d63ed0705652d2c142b03a4bdb77a6ddec0832dfbf2748a2be38ded8ffeb
RUN set -ex; \
    \
    wget -q -O osTicket.zip https://github.com/osTicket/osTicket/releases/download/v${OSTICKET_VERSION}/osTicket-v${OSTICKET_VERSION}.zip; \
    echo "${OSTICKET_SHA256SUM}  osTicket.zip" | sha256sum -c; \
    unzip osTicket.zip 'upload/*'; \
    rm osTicket.zip; \
    mkdir /usr/local/src; \
    mv upload /usr/local/src/osticket; \
    # Hard link the sources to the public directory
    cp -al /usr/local/src/osticket/. /var/www/html; \
    # Remove setup
    rm -r /var/www/html/setup; \
    \
    for lang in ar_EG ar_SA az bg bn bs ca cs da de el es_AR es_ES es_MX et eu fa fi fr gl he hi \
        hr hu id is it ja ka km ko lt lv mk mn ms nl no pl pt_BR pt_PT ro ru sk sl sq sr sr_CS \
        sv_SE sw th tr uk ur_IN ur_PK vi zh_CN zh_TW; do \
        # This URL is the same as what is used by the official osTicket Downloads page. This URL is
        # used even for minor versions >= 14.
        wget -q -O /var/www/html/include/i18n/${lang}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/lang/1.14.x/${lang}.phar; \
    done
RUN set -ex; \
    \
    for plugin in audit auth-2fa auth-ldap auth-passthru auth-password-policy storage-fs; do \
        wget -q -O /var/www/html/include/plugins/${plugin}.phar \
            https://s3.amazonaws.com/downloads.osticket.com/plugin/${plugin}.phar; \
    done; 
COPY root /
VOLUME /osticket/uploads /osticket/config
CMD ["start"]
STOPSIGNAL SIGTERM
EXPOSE 443
#HEALTHCHECK CMD curl -fIsS https://localhost/ || exit 1
