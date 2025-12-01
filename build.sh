#!/bin/bash

JMETER_VERSION=${JMETER_VERSION:-"5.5"}
IMAGE_TIMEZONE=${IMAGE_TIMEZONE:-"America/Bogota"}

# Example build line
docker build  --build-arg JMETER_VERSION=${JMETER_VERSION} --build-arg TZ=${IMAGE_TIMEZONE} -t "justb4/jmeter:${JMETER_VERSION}" .
