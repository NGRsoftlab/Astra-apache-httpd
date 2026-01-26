## Definite image args
ARG image_registry
ARG image_name=astra
ARG image_version=1.8.x-slim

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                          Base image                         #
#             Init stage, install base application            #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
FROM ${image_registry}${image_name}:${image_version} AS base-stage

SHELL ["/bin/bash", "-exo", "pipefail", "-c"]

## Def initial arg(will be replaced with docker build opt)
ARG version=1.0.0
ARG httpd_identity=2.4.65

## Build args
ENV \
    VERSION="${version}" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=linux \
    TZ=Etc/UTC \
    MALLOC_ARENA_MAX=2 \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_RUN_DIR=/var/www/html

## Copy issue
COPY docs/issue /etc/issue

## Install build components
## Always use the latest version available for the current DEB distribution
# hadolint ignore=DL3027, SC2154
RUN \
    --mount=type=bind,source=./scripts,target=/usr/local/sbin,readonly \
## Install httpd
    httpd-install-approximately.sh "${httpd_identity}" \
## Deduplication cleanup
    && dedup-clean.sh /usr/

## Redirect file log to stdout/stderr fd
RUN \
    ln -sf /dev/stdout /var/log/apache2/access.log \
    && ln -sf /dev/stderr /var/log/apache2/error.log

RUN \
## Get image package dump
    mkdir -p /usr/share/rocks \
    && ( \
        echo "# os-release" && cat /etc/os-release \
        && echo "# dpkg-query" \
        && dpkg-query -f \
            '${db:Status-Abbrev},${binary:Package},${Version},${source:Package},${Source:Version}\n' \
            -W \
        ) >/usr/share/rocks/dpkg.query \
## Spot system
    && echo "Minimal Apache HTTP Server container version ${VERSION}" >>/etc/issue

## Add launch process ep
COPY configuration/httpd-foreground /usr/local/bin/

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                        Final image                          #
#             Second stage, compact optimize layer            #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
FROM scratch

COPY --from=base-stage / /

## Set base label
LABEL \
    maintainer="Vladislav Avdeev" \
    organization="NGRSoftlab"

## Set environment
ENV \
    LANG='en_US.UTF8' \
    LC_ALL='en_US.UTF8' \
    TERM='xterm-256color' \
    TZ=Etc/UTC \
    DEBIAN_FRONTEND='noninteractive' \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_LOG_DIR=/var/log/apache2 \
    APACHE_RUN_DIR=/var/www/html \
    APACHE_PID_FILE=/run/apache2/httpd.pid

## Set work directory
WORKDIR /

# https://httpd.apache.org/docs/2.4/stopping.html#gracefulstop
STOPSIGNAL SIGWINCH

## Be gentle and expose port
EXPOSE 80

## Run app
CMD ["httpd-foreground"]
