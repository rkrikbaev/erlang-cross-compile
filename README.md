Erlang OTP 22.3 environment

Build docker image for ARM

`docker buildx build --platform linux/arm/v7 --build-arg HOST_ARCH=linux-armv4 -f ./Dockerfile -t rkrikbaev/erlang_build-armv7:otp22.3 .`

Build docker image for ARM64

`docker buildx build --platform linux/arm/v7 --build-arg HOST_ARCH=linux-armv4 -f ./Dockerfile -t rkrikbaev/erlang_build-armv7:otp22.3 .`

Build docker image for x86_64

`docker buildx build --platform linux/arm/v7 --build-arg HOST_ARCH=linux-armv4 -f ./Dockerfile -t rkrikbaev/erlang_build-armv7:otp22.3 .`
