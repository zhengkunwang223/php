#!/bin/sh

export MC="-j$(nproc)"

echo
echo "============================================"
echo "Install extensions from   : install.sh"
echo "PHP version               : ${PHP_VERSION}"
echo "Extra Extensions          : ${PHP_EXTENSIONS}"
echo "Multicore Compilation     : ${MC}"
echo "Container package url     : ${CONTAINER_PACKAGE_URL}"
echo "Work directory            : ${PWD}"
echo "============================================"
echo


isPhpVersionGreaterOrEqual() {
    local PHP_MAJOR_VERSION=$(php -r "echo PHP_MAJOR_VERSION;")
    local PHP_MINOR_VERSION=$(php -r "echo PHP_MINOR_VERSION;")

    if [ "$PHP_MAJOR_VERSION" -gt "$1" ] || [ "$PHP_MAJOR_VERSION" -eq "$1" ] && [ "$PHP_MINOR_VERSION" -ge "$2" ]; then
        return 1
    else
        return 0
    fi
}

install_php_extensions() {
    local extension=$1
     install-php-extensions $extension
     if [ $? -eq 0 ]; then
       echo "------ install-php-extensions $extension succeeded ------"
     else
       echo "------ install-php-extensions $extension failed ------"
     fi
}

pecl_install() {
    local extension=$1
    printf "\n" | pecl install $extension
    if [ $? -eq 0 ]; then
      docker-php-ext-enable $extension
      echo "------ pecl install $extension succeeded ------"
    else
      echo "------ pecl install $extension failed ------"
    fi
}

docker_php_ext_install() {
   local extension=$1
   docker-php-ext-install ${MC} $extension
    if [ $? -eq 0 ]; then
        echo "------ docker-php-ext-install install $extension succeeded ------"
    else
        echo "------ docker-php-ext-install install $extension failed------"
    fi
}

install_extension() {
    local extension=$1
    printf "\n" | pecl install $extension
    if [ $? -eq 0 ]; then
       docker-php-ext-enable $extension
       echo "------ pecl install $extension succeeded ------"
    else
       echo "------ pecl install $extension failed use docker-php-ext-install------"
       docker-php-ext-install ${MC} $extension
       if [ $? -eq 0 ]; then
         echo "------ docker-php-ext-install install $extension succeeded ------"
       else
         echo "------ docker-php-ext-install install $extension failed use install-php-extensions------"
         install-php-extensions $extension
         if [ $? -eq 0 ]; then
           echo "------ install-php-extensions $extension succeeded ------"
         else
           echo "------ install-php-extensions $extension failed ------"
         fi
       fi
    fi
}



install_gd() {
    isPhpVersionGreaterOrEqual 8 0
    if [ "$?" = "1" ]; then
        # "--with-xxx-dir" was removed from php 7.4,
        # issue: https://github.com/docker-library/php/issues/912
        options="--with-freetype --with-jpeg --with-webp"
    else
        options="--with-gd --with-freetype-dir=/usr/include/ --with-png-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-webp-dir=/usr/include/"
    fi
    apt-get install -y  \
        libfreetype6 \
        libfreetype6-dev \
        libpng-dev \
        libwebp-dev \
        libjpeg-dev \
    && docker-php-ext-configure gd ${options} \
    && docker-php-ext-install ${MC} gd \
    && apt-get purge -y \
        libfreetype6-dev \
        libpng-dev \
    && apt-get autoremove -y
}

install_event() {
    apt-get install -y libevent-dev
    apt-get install libssl-dev
    export is_sockets_installed=$(php -r "echo extension_loaded('sockets');")

    if [ "${is_sockets_installed}" = "" ]; then
        echo "---------- event is depend on sockets, install sockets first ----------"
        docker-php-ext-install sockets
    fi

    mkdir event
    tar -xf event-3.1.3.tgz -C event --strip-components=1
    cd event && phpize && ./configure && make  && make install

    docker-php-ext-enable --ini-name event.ini event
}


install_msg() {
    if [ $? -eq 0 ]; then
        echo "------ install $1 succeeded ------"
    else
        echo "------ install $1 failed ------"
    fi
}

install_memcache() {
   pecl install memcache
   install_msg memcache
   docker-php-ext-enable memcache
}

install_pdo_pgsql() {
    apt-get update && apt-get install -y libpq-dev 
    install_msg pdo_pgsql
    docker-php-ext-install ${MC} pdo_pgsql
}

install_pdo_mysql() {
    docker-php-ext-install ${MC} pdo_mysql
    install_msg pdo_mysql
}

install_yaf() {
    pecl install yaf
    install_msg yaf
    docker-php-ext-enable yaf
}
apt-get update

echo "${PHP_EXTENSIONS}" | tr ',' '\n' | while read -r extension; do
    echo "------ install extension: $extension ------"
    
    if [ "$extension" = "gd" ]; then
        install_gd
    elif [ "$extension" = "memcache" ]; then
        install_memcache   
    elif [ "$extension" = "yaf" ]; then
        install_yaf   
    elif [ "$extension" = "pdo_pgsql" ]; then
        install_pdo_pgsql  
    elif [ "$extension" = "pdo_mysql" ]; then
        install_pdo_mysql
    elif [ "$extension" = "event" ]; then
        install_event    
    elif [ "$extension" = "yaml" ]; then
        apt-get install -y libyaml-dev
        pecl_install yaml
    elif [ "$extension" = "mongodb" ]; then
        apt-get install -y  libssl-dev
        pecl_install mongodb
    elif [ "$extension" = "mcrypt" ]; then
        apt-get install -y libmcrypt-dev
        pecl_install mcrypt
    elif [ "$extension" = "ssh2" ]; then
        apt-get install -y libssh2-1-dev libssh2-1
        pecl_install ssh2
    elif [ "$extension" = "rdkafka" ]; then
        apt-get install -y librdkafka-dev
        pecl_install rdkafka 
    elif [ "$extension" = "varnish" ]; then
        apt-get install -y  libvarnishapi-dev
        pecl_install varnish
    elif [ "$extension" = "bcmath" ]; then
        docker_php_ext_install bcmath
    elif [ "$extension" = "pcntl" ]; then
        docker_php_ext_install pcntl
    elif [ "$extension" = "shmop" ]; then
        docker_php_ext_install shmop  
    elif [ "$extension" = "gettext" ]; then
        docker_php_ext_install gettext
    elif [ "$extension" = "sockets" ]; then
        docker_php_ext_install sockets
    elif [ "$extension" = "sysvsem" ]; then
        docker_php_ext_install sysvsem
    elif [ "$extension" = "opcache" ]; then
        docker_php_ext_install opcache
    elif [ "$extension" = "mysqli" ]; then
        docker_php_ext_install mysqli                                    
    elif [ "$extension" = "sodium" ]; then
        apt-get install -y  libsodium-dev
        docker_php_ext_install sodium
    elif [ "$extension" = "zip" ]; then
        apt-get update && apt-get install -y  libzip-dev
        docker_php_ext_install zip    
    elif [ "$extension" = "memcached" ]; then
        install_php_extensions memcached 
    elif [ "$extension" = "redis" ]; then
        install_php_extensions redis
    elif [ "$extension" = "xdebug" ]; then
        install_php_extensions xdebug
    elif [ "$extension" = "imap" ]; then
        install_php_extensions imap
    elif [ "$extension" = "intl" ]; then
        install_php_extensions intl
    elif [ "$extension" = "swoole" ]; then
        install_php_extensions swoole
    elif [ "$extension" = "pgsql" ]; then
        install_php_extensions pgsql
    elif [ "$extension" = "curl" ]; then
        install_php_extensions curl
    elif [ "$extension" = "sourceguardian" ]; then
        install_php_extensions sourceguardian
    elif [ "$extension" = "snmp" ]; then
        install_php_extensions snmp
    elif [ "$extension" = "mbstring" ]; then
        install_php_extensions mbstring
    elif [ "$extension" = "pdo_firebird" ]; then
        install_php_extensions pdo_firebird
    elif [ "$extension" = "pdo_dblib" ]; then
        install_php_extensions pdo_dblib
    elif [ "$extension" = "pdo_oci" ]; then
        install_php_extensions pdo_oci
    elif [ "$extension" = "pdo_odbc" ]; then
        install_php_extensions pdo_odbc
    elif [ "$extension" = "oci8" ]; then
        install_php_extensions oci8
    elif [ "$extension" = "odbc" ]; then
        install_php_extensions odbc
    elif [ "$extension" = "soap" ]; then
        install_php_extensions soap
    elif [ "$extension" = "xsl" ]; then
        install_php_extensions xsl
    elif [ "$extension" = "xmlrpc" ]; then
        install_php_extensions xmlrpc
    elif [ "$extension" = "readline" ]; then
        install_php_extensions readline
    elif [ "$extension" = "snmp" ]; then
        install_php_extensions snmp
    elif [ "$extension" = "tidy" ]; then
        install_php_extensions tidy
    elif [ "$extension" = "gmp" ]; then
        install_php_extensions gmp
    elif [ "$extension" = "ldap" ]; then
        install_php_extensions ldap
    elif [ "$extension" = "imagick" ]; then
        install_php_extensions imagick
    elif [ "$extension" = "amqp" ]; then
        install_php_extensions amqp
    elif [ "$extension" = "zookeeper" ]; then
        install_php_extensions zookeeper
    else 
        install_extension $extension
    fi 
done

docker-php-source delete 
