FROM debian:buster as builder
WORKDIR /build/

RUN echo "deb-src http://deb.debian.org/debian buster main" >> /etc/apt/sources.list
RUN echo "deb http://deb.debian.org/debian/ stretch main contrib non-free" >> /etc/apt/sources.list
RUN apt update && apt install -y build-essential fakeroot dpkg-dev autoconf automake pkg-config libnl-genl-3-dev libssl1.0-dev devscripts quilt git-core git
RUN apt source hostapd=2:2.7+git20190128+0c1e29f-6+deb10u2
RUN apt build-dep -y hostapd

# apt source will automatically unpack to wpa-2.4
WORKDIR /build/wpa-2.7+git20190128+0c1e29f

# TODO fix patch for v2.7
COPY ./patches/0001-noscan.patch /build/wpa-2.7+git20190128+0c1e29f/debian/patches/2020-09/0001-noscan.patch

ENV QUILT_PATCHES debian/patches
ENV DEBEMAIL kek@local.patcher
RUN echo "2020-09/0001-noscan.patch" >> /build/wpa-2.7+git20190128+0c1e29f/debian/patches/series
RUN dch -i -m "No scan patch a.k.a force 40MHz"
RUN debuild -uc -us -b

FROM debian:buster-slim
WORKDIR /opt/hostapd/

RUN apt update \
        && apt install -y libnl-3-200 libnl-genl-3-200 libnl-route-3-200 isc-dhcp-server iptables iproute2 \
        && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && mkdir -p /var/lib/dhcp/ \
    && touch /var/lib/dhcp/dhcpd.leases

COPY --from=builder /build/hostapd_2.7* /opt/hostapd/

RUN dpkg -i *.deb
RUN rm *.deb

COPY scripts/ /opt/hostapd/
RUN chmod +x /opt/hostapd/apmanager

ENTRYPOINT ["/opt/hostapd/apmanager"]