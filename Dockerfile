ARG GCC_RELEASE=13.2.0
FROM registry.gitlab.com/doragasu/docker-deb-m68k:$GCC_RELEASE AS buildstage
USER root
RUN apt-get update && apt-get install -y git wget flex bison gperf zlib1g-dev build-essential openjdk-17-jre-headless unzip
RUN mkdir -p /tmp

# Use --build-arg=SGDK_RELEASE=<branch> switch to change
ARG SGDK_RELEASE=master
# Use --build-arg=ENABLE_MEGAWIFI=y to enable MegaWiFi support
ARG ENABLE_MEGAWIFI=n
RUN cd /tmp && git clone https://github.com/Stephane-D/SGDK.git && cd SGDK && git checkout $SGDK_RELEASE
RUN test "$ENABLE_MEGAWIFI" = "y" && sed -i 's/#define MODULE_MEGAWIFI *0/#define MODULE_MEGAWIFI         1/' /tmp/SGDK/inc/config.h || /bin/true

# Download compatible SJASM sources
RUN mkdir -p "/tmp/build/sjasm" && cd "/tmp/build/sjasm" && \
	wget https://github.com/Konamiman/Sjasm/archive/v0.39h.tar.gz -O sjasm-0.39h.tar.gz
RUN mkdir -p "/tmp/build/maccer" && cd "/tmp/build/maccer" && \
	wget --user-agent="Mozilla/4.0" http://gendev.spritesmind.net/files/maccer-026k02.zip
COPY build_sgdk /tmp/SGDK
COPY patches /tmp/SGDK/patches
# Patch SGDK and build required binaries
RUN cd /tmp/SGDK && for file in patches/*; do patch -p1 < $file; done
RUN cd /tmp/SGDK && ./build_sgdk
RUN rm /tmp/SGDK/build_sgdk /tmp/SGDK/patches -r

# Second stage
FROM registry.gitlab.com/doragasu/docker-deb-m68k:$GCC_RELEASE
USER root
RUN apt-get update && apt-get install -y openjdk-17-jre-headless
COPY --from=buildstage /tmp/SGDK /sgdk
ENV GDK=/sgdk
ENV PATH=$PATH:$GDK/bin

USER m68k
WORKDIR /m68k
ENTRYPOINT [ "make", "-f", "/sgdk/makefile.gen" ]
