FROM ghcr.io/frepple/frepple-community:latest

## Add uzerp app
COPY ./uzerp /usr/share/frepple/venv/lib/python3.12/site-packages/freppledb/uzerp

## Install required python packages
RUN apt-get -y -q update && \
  DEBIAN_FRONTEND=noninteractive apt-get -y install python3-bcrypt python3-passlib python3-phpserialize && \
  apt-get -y purge --autoremove && \
  apt-get clean && \
  rm -rf *.deb /var/lib/apt/lists/* /etc/apt/sources.list.d/pgdg.list
