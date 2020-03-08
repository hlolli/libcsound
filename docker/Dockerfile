FROM ubuntu:disco-20191011
MAINTAINER Hlöðver Sigurðsson <hlolli@gmail.com>
RUN apt-get update && \
        apt-get install -y software-properties-common && \
        add-apt-repository ppa:leaningtech-dev/cheerp-ppa && \
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 84540D4B9BF457D5 && \
        apt-get update && \
        apt-get install -y cheerp-core
