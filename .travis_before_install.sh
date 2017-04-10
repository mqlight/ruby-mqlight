#!/bin/sh

if [ "${TRAVIS_OS_NAME}" = "osx" ]; then
  brew update
  brew install node cmake coreutils findutils
  CP=gcp
  FIND=gfind
else
  sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
  sudo apt-get update -q
  sudo apt-get install -qqy nodejs cmake g++-4.8 libssl-dev libsasl2-dev sasl2-bin
  CP=cp
  FIND=find
fi

git clone --depth=1 \
  https://github.com/mqlight/qpid-proton.git ~/.local/src/qpid-proton
cd ~/.local/src/qpid-proton \
  && mkdir -p build \
  && cd build \
  && cmake -DNOBUILD_JAVA=TRUE -DSASL_IMPL=none -DSSL_IMPL=none \
           -DCMAKE_BUILD_TYPE=RelWithDebInfo \
           -DCMAKE_INSTALL_PREFIX=${HOME}/.local .. \
  && cmake --build . --target install
for F in $(${FIND} ~/.local/lib* -maxdepth 1 -type l); do
  ${CP} --remove-destination ~/.local/lib/$(readlink $F) $F
done
${CP} -R ~/.local/include ${TRAVIS_BUILD_DIR}/include
${CP} -R ~/.local/lib*/* ${TRAVIS_BUILD_DIR}/lib/ 
cd ${TRAVIS_BUILD_DIR} \
  && mkdir -p node_modules \
  && npm install core-js request js-yaml
