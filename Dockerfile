FROM wordpress:6-php8.4-apache
ENV TZ=Europe/Berlin
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        locales \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i -e 's/# de_DE.UTF-8/de_DE.UTF-8/' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug
COPY --from=wordpress:cli /usr/local/bin/wp /usr/local/bin/wp
