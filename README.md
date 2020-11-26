# FriendlyAdmin/onionbalance

Onionbalance and Tor neatly packaged in a single Docker image.

Built for Docker Hub automatically by utilizing a GitHub hook, see `hooks/build` for details.

[Onionbalance](https://onionbalance-v3.readthedocs.io/en/latest/) is a Tor-specific utility for running a Tor hidden service. It fetches hidden service descriptors from multiple backend .onion addresses and publishes them all under a single frontend (public) .onion address.

Tor on a client will fetch all of the descriptors and choose one to request at random. If the hidden service isn't available under a chosen descriptor - Tor will try another one, until it reaches the service or runs out of decriptors. Effectively performing a randomized round-robin load-balancing. 

Onionbalance also allows a hidden service operator to keep the keys of his public .onion address separate from the actual production server.

See [Onionbalance docs](https://onionbalance-v3.readthedocs.io/en/latest/) for more details.

[Docker Hub repo](https://hub.docker.com/r/friendlyadmin/onionbalance)

## Usage

To run the image you must provide an Onionbalance config file `onionbalance.config.yaml` (see `example_onionbalance.config.yaml` in this repo) and keys for a frontend (public) .onion address `hs_ed25519_secret_key` and `hs_ed25519_public_key`.

The easiest way to run this image is by using Docker Compose utility and a config `onionbalance/docker-compose.yaml` from [this repo](https://github.com/FriendlyAdmin/tor-hs).

Or run it as a standalone container like so:

```
docker container run --read-only -d --name=onionbalance \
    -v onionbalance.config.yaml:/onionbalance/config.yaml:ro \
    -v hs_ed25519_secret_key:/var/lib/hs_data/hs_ed25519_secret_key:ro \
    -v hs_ed25519_public_key:/var/lib/hs_data/hs_ed25519_public_key:ro
    friendlyadmin/onionbalance:latest
```

## Building

To build the image manually run from inside the repo root directory:

```
docker build \
    --build-arg PYTHON_VERSION=3.9 \
    --build-arg TOR_VERSION=0.4.4.6 \
    --build-arg ONIONBALANCE_VERSION=0.2.0 \
    -t YOUR_DESIRED_IMAGE_TAG \
    .
```

You must provide `PYTHON_VERSION`, `TOR_VERSION` and `ONIONBALANCE_VERSION` build arguments.

See tags on [Docker Hub Python repo](https://hub.docker.com/_/python) for what Python image versions are available.

See tags on [FriendlyAdmin/tor image](https://hub.docker.com/r/friendlyadmin/tor) for what Tor versions are available.

See [Onionbalance repo](https://gitlab.torproject.org/asn/onionbalance) for the latest Onionbalance version.

## See also

[FriendlyAdmin/tor](https://github.com/FriendlyAdmin/tor) - General purpose Tor Docker image used in building the Onionbalance image.

[FriendlyAdmin/tor-hs](https://github.com/FriendlyAdmin/tor-hs) - A pre-made simple Docker Compose configuration for running an Onionbalanced Tor hidden service.
