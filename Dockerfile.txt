# Use a base image that supports 32-bit binaries
FROM i386/ubuntu:20.04

# Update the package list and install necessary tools
RUN apt-get update && \
    apt-get install -y nasm gcc libc6-dev

# Create a working directory
WORKDIR /usr/src/app
