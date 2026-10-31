SHELL := /bin/bash

.PHONY: all prepare menuconfig download build collect clean distclean deps

all:
	bash scripts/build.sh all

prepare:
	bash scripts/build.sh prepare

menuconfig:
	bash scripts/build.sh menuconfig

download:
	bash scripts/build.sh download

build:
	bash scripts/build.sh build

collect:
	bash scripts/build.sh collect

clean:
	bash scripts/build.sh clean

distclean:
	bash scripts/build.sh distclean

deps:
	bash scripts/install-deps.sh
