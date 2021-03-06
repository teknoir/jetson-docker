#FROM  balenalib/jetson-nano-ubuntu:bionic as app_build
FROM  balenalib/intel-nuc-debian:buster-build as yolo-app-build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt-get --no-install-recommends install -y build-essential gcc make libssl-dev git

RUN CMAKE_VERSION=3.15 && \
    CMAKE_BUILD=3.15.0 && \
    curl -L https://cmake.org/files/v${CMAKE_VERSION}/cmake-${CMAKE_BUILD}.tar.gz | tar -xzf - && \
    cd /cmake-${CMAKE_BUILD} && \
    ./bootstrap --parallel=$(grep ^processor /proc/cpuinfo | wc -l) && \
    make -j"$(grep ^processor /proc/cpuinfo | wc -l)" install && \
    rm -rf /cmake-${CMAKE_BUILD}

ENV PAHO_MQTT_HOME=/paho.mqtt
ENV C_INCLUDE_PATH=${PAHO_MQTT_HOME}/include:${C_INCLUDE_PATH}
ENV CPATH=${PAHO_MQTT_HOME}/include:$CPATH
WORKDIR ${PAHO_MQTT_HOME}
RUN git clone https://github.com/eclipse/paho.mqtt.c.git && \
    cd paho.mqtt.c && git checkout v1.3.1 && \
    cmake -Bbuild -H. -DPAHO_WITH_SSL=TRUE -DPAHO_BUILD_DOCUMENTATION=FALSE -DPAHO_BUILD_SAMPLES=FALSE -DPAHO_ENABLE_TESTING=FALSE -DCMAKE_INSTALL_PREFIX=${PAHO_MQTT_HOME} && \
    cmake --build build/ --target install

RUN git clone https://github.com/eclipse/paho.mqtt.cpp && \
    cd paho.mqtt.cpp && \
    cmake -Bbuild -H. -DPAHO_BUILD_DOCUMENTATION=FALSE -DPAHO_BUILD_SAMPLES=FALSE -DCMAKE_INSTALL_PREFIX=${PAHO_MQTT_HOME} -DCMAKE_PREFIX_PATH=${PAHO_MQTT_HOME} && \
    cmake --build build/ --target install

RUN cp -rf ${PAHO_MQTT_HOME}/lib/* /usr/lib/ && \
    cp -rf ${PAHO_MQTT_HOME}/include/* /usr/include/

WORKDIR /darknet
RUN git clone https://github.com/AlexeyAB/darknet.git && \
    cd darknet && \
    make LIBSO=1
#WORKDIR /darknet
#RUN git clone https://github.com/AlexeyAB/darknet.git && \
#    cd darknet && \
#    ./build.sh

RUN cp -rf /darknet/darknet/libdarknet.so /usr/lib/ && \
    cp -rf /darknet/darknet/include/* /usr/include/

WORKDIR /app
ADD ./app /app
RUN cmake -Bbuild -H. -DCMAKE_INSTALL_PREFIX=/app && \
    cmake --build build/ --target install

##########################
FROM  balenalib/intel-nuc-debian:buster-build as app_release

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt-get --no-install-recommends install -y openssl

ENV PAHO_MQTT_HOME=/paho.mqtt
COPY --from=yolo-app-build ${PAHO_MQTT_HOME}/lib /usr/lib
COPY --from=yolo-app-build /darknet/darknet/libdarknet.so /usr/lib
COPY --from=yolo-app-build /darknet/darknet/darknet /usr/bin
COPY --from=yolo-app-build /darknet/darknet/uselib /usr/bin
COPY --from=yolo-app-build /darknet/darknet/data/person.jpg /root
COPY --from=yolo-app-build /app/bin /usr/bin

STOPSIGNAL SIGINT
CMD ["/usr/bin/teknoir_app"]