#!/bin/sh

if [ "${TRAVIS_OS_NAME}" = "osx" ]; then
  brew update
  brew install node cmake
else
  sudo add-apt-repository ppa:ubuntu-toolchain-r/test -y
  sudo apt-get update -q
  sudo apt-get install -qqy nodejs cmake g++-4.8 libssl-dev libsasl2-dev sasl2-bin
fi

echo -e "machine github.ibm.com\n  login ${CI_USER_TOKEN}" >> ~/.netrc
git clone --depth=1 \
  https://github.ibm.com/mqlight/qpid-proton.git ~/.local/src/qpid-proton
cd ~/.local/src/qpid-proton \
  && mkdir -p build \
  && cd build \
  && cmake -DNOBUILD_JAVA=TRUE -DSASL_IMPL=none -DSSL_IMPL=none \
           -DCMAKE_BUILD_TYPE=RelWithDebInfo \
           -DCMAKE_INSTALL_PREFIX=${HOME}/.local .. \
  && cmake --build . --target install
for F in $(find ~/.local/lib -maxdepth 1 -type l); do
  cp --remove-destination ~/.local/lib/$(readlink $F) $F
done
cd ${TRAVIS_BUILD_DIR} \
  && mkdir -p node_modules \
  && npm install core-js request js-yaml
