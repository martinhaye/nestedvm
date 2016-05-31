FROM n3ziniuka5/ubuntu-oracle-jdk:14.04-JDK8
MAINTAINER Martin Haye <m1@snyder-haye.com>

# Install build prerequisites
RUN apt-get update && apt-get install -y wget unzip build-essential curl libgmp3-dev libmpfr-dev libmpc-dev git

# Grab the nestedvm source code, and perform one minor patch
RUN cd /usr/local && wget https://github.com/tewarfel/nestedvm/archive/master.zip -O nestedvm.zip && unzip nestedvm.zip && rm nestedvm.zip
RUN cd /usr/local && mv nestedvm-master nestedvm && perl -p -i -e 's/http:\/\/www.arglist.com\/regex\/files\/regex3.8a.tar.gz/https:\/\/github.com\/xerial\/sqlite-jdbc\/raw\/master\/archive\/regex3.8a.tar.gz/g' nestedvm/upstream/Makefile

# Build GCC and then clean up after it to make our image a bit smaller
RUN cd /usr/local/nestedvm && make upstream/tasks/build_gcc && rm -rf upstream/build/gcc-* upstream/build/binutils-*

# Now build nestedvm and its dependencies
RUN cd /usr/local/nestedvm && make && make unix_runtime.jar && make compiler.jar && make nestedvm.jar && make test

# Install some useful wrapper scripts and instructions
RUN echo '#!/bin/sh\n\
/usr/local/nestedvm/upstream/install/bin/mips-unknown-elf-gcc -O3 -mmemcpy -ffunction-sections -fdata-sections -falign-functions=512 -fno-rename-registers -fno-schedule-insns -fno-delayed-branch  -march=mips1 -specs=/usr/local/nestedvm/upstream/install/mips-unknown-elf/lib/crt0-override.spec -I. -Wall -Wno-unused $*'\
> /usr/local/bin/nestedvm-cc && \
echo '#!/bin/sh\n\
/usr/local/nestedvm/upstream/install/bin/mips-unknown-elf-gcc -march=mips1 -specs=/usr/local/nestedvm/upstream/install/mips-unknown-elf/lib/crt0-override.spec --static -Wl,--gc-sections $*'\
> /usr/local/bin/nestedvm-link && \
echo '#!/bin/sh\n\
/usr/bin/java -jar /usr/local/nestedvm/compiler.jar $*'\
> /usr/local/bin/nestedvm-trans && \
echo '#!/bin/bash\n\
if [ "$#" -lt 3 ]; then\n\
    echo "Usage: $0 jarname package.Classname cfiles..." && exit 1\n\
fi\n\
set -e\n\
set -x\n\
JAR_FILE="$1" && shift && CLASS_NAME="$1" && shift && C_SRCS="$*"\n\
BUILD_DIR="/tmp/nestedvm_c2jar_build" && rm -rf $BUILD_DIR && mkdir -p $BUILD_DIR\n\
/usr/local/bin/nestedvm-cc -o $BUILD_DIR/intermediate.mips $C_SRCS\n\
unzip -q -d $BUILD_DIR /usr/local/nestedvm/unix_runtime.jar && rm -rf $BUILD_DIR/META_INF\n\
/usr/local/bin/nestedvm-trans -o unixRuntime -outformat class -d $BUILD_DIR $CLASS_NAME $BUILD_DIR/intermediate.mips && rm $BUILD_DIR/intermediate.mips\n\
/usr/bin/jar cvfe "$JAR_FILE" $CLASS_NAME -C $BUILD_DIR . >/dev/null\n\
rm -rf $BUILD_DIR'\
> /usr/local/bin/nestedvm-c2jar && \
chmod +x /usr/local/bin/nestedvm-* && \
cd /usr/local/nestedvm/src/tests && nestedvm-c2jar Test.jar tests.Test Test.c && java -jar Test.jar && rm Test.jar && \
echo 'echo ""\n\
echo "Welcome to nestedvm."\n\
echo ""\n\
echo "The following wrappers are installed in /usr/local/bin:"\n\
echo "  nestedvm-c2jar (top-level wrapper)"\n\
echo "  nestedvm-cc, nestedvm-link, nestedvm-trans (mid-level wrappers)"\n\
echo "Full build in /usr/local/nestedvm"\n\
echo ""\n'\
>> /root/.bashrc
