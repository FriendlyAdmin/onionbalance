#
# This Dockefile will download and build the most recent possible version of Onionbalance,
# it will also copy Tor from a sister image and configure Supervisor to run both apps.
#
# To sucessfully build an image from this Dockerfile the following build ARGs must be provided:
# PYTHON_VERSION, TOR_VERION, ONIONBALANCE_VERSION
#

# Python version to be used for all stages.
ARG PYTHON_VERSION

# Tor image version to use.
ARG TOR_VERSION



#
### Declare Tor image as a separate stage to copy necessary stuff from it into the finale stage below.
#
FROM friendlyadmin/tor:$TOR_VERSION as tor-copy



#
### Final stage
#
FROM python:$PYTHON_VERSION-alpine

# Onionbalance app version to use.
ARG ONIONBALANCE_VERSION

# Build dependencies for Onionbalance and git to download it.
RUN apk --no-cache --update add --virtual .build-deps \
        git \
        gcc \
        musl-dev \
        python3-dev \
        libffi-dev \
        openssl-dev \
        && \
    # Download Onionbalance.
    git clone https://gitlab.torproject.org/asn/onionbalance.git && \
    # Build Onionbalance.
    cd onionbalance && \
    python setup.py install && \
    # Remove dependencies.
    apk --no-cache del .build-deps && \
    # Delete apk cache to save some space.
    rm -rf /var/cache/apk/*

# Check that we have the requested Onionbalance version by quietly grepping the output of --version command.
RUN onionbalance --version | grep -qm1 $ONIONBALANCE_VERSION

# Tor-related directories. Configured in default.torrc and other torrc files.
ENV DATA_DIR=/var/lib/tor
ENV HS_DATA_DIR=/var/lib/hs_data
ENV CONFIG_DIR=/usr/local/etc/tor

# We will run both Tor and Onionbalance from this user:group.
ENV USER=tor
ENV GROUP=tor

WORKDIR '/'

RUN addgroup -g 101 -S $GROUP && \
    adduser -D -H -u 100 -s /sbin/nologin -G $GROUP -S $USER

# Take everything we need for Tor from our Tor image.
COPY --from=tor-copy --chown=$USER:$GROUP /usr/local/ /usr/local/
COPY --from=tor-copy --chown=$USER:$GROUP /usr/local/bin/dockerize /usr/local/bin/dockerize
COPY --from=tor-copy --chown=$USER:$GROUP $DATA_DIR $DATA_DIR
COPY --from=tor-copy --chown=$USER:$GROUP $HS_DATA_DIR $HS_DATA_DIR
COPY --from=tor-copy --chown=$USER:$GROUP $CONFIG_DIR $CONFIG_DIR

# Fix permissions on Tor directories.
RUN \
    chmod 0700 $DATA_DIR && \
    chmod 0700 $HS_DATA_DIR

RUN \
    # Update apk, then update all built-in packages with the latest stable versions from pre-configured repositories.
    apk update && \
    apk --no-cache upgrade && \
    # Curl will be used for healthchecks.
    # Tini will be used as a standart entrypoint.
    # Supervisor is needed to run two processes in a single container.
    apk --no-cache add curl tini supervisor && \
    # Add apk edge repos to get the edge versions of packages.
    # We will restore the original repo list from this file to keep everything neat afterwards.
    cp /etc/apk/repositories /etc/apk/default-repositories && \
    echo 'http://dl-cdn.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories && \
    echo 'http://dl-cdn.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
    # Get edge verions of Tor runtime dependencies.
    apk --no-cache --update add \
        libevent \
        openssl \
        musl \
        xz-libs \
        zlib \
        zstd-libs \
        zstd \
        && \
    # Delete apk cache to save some space.
    rm -rf /var/cache/apk/* && \
    # Restore the default apk repo list.
    mv -f /etc/apk/default-repositories /etc/apk/repositories

# Tor config can be safely baked in.
COPY --chown=$USER:$GROUP torrc /etc/tor/torrc

# As well as supervisor config.
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Declare anonymous volumes for this directories to persist data and run containers in read-only mode.
VOLUME $DATA_DIR $HS_DATA_DIR /tmp

# Run everything from a generic user.
USER $USER:$GROUP

# Run tini as a host proccess.
# Escpecially important since we're using two pretty underdeveloped pieces of software.
ENTRYPOINT [ "/sbin/tini", "--" ]

# Supervisord will handle running both processes for us.
CMD [ "supervisord", "-c", "/etc/supervisor/supervisord.conf" ]
