#!/bin/bash

#Install the AVR toolchain:
sudo apt-get install gcc-avr avr-libc avrdude

# Initialize the 00_ArduinoCore submodule
git submodule update --init --recursive
