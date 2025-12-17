#!/bin/sh -e

# Copied w/ love from the excellent hypnoglow/helm-s3

if [ -n "${HELM_PUSH_PLUGIN_NO_INSTALL_HOOK}" ]; then
    echo "Development mode: not downloading versioned release."
    exit 0
fi

version="$(cat ${HELM_PLUGIN_DIR}/plugin.yaml | grep "version" | cut -d '"' -f 2)"
echo "Downloading and installing helm-push v${version} ..."

url=""

# convert architecture of the target system to a compatible GOARCH value.
# Otherwise failes to download of the plugin from github, because the provided
# architecture by `uname -m` is not part of the github release.
arch=""
case $(uname -m) in
  x86_64)
    arch="amd64"
    ;;
  armv6*)
    arch="armv6"
    ;;
  # match every arm processor version like armv7h, armv7l and so on.
  armv7*)
    arch="armv7"
    ;;
  aarch64 | arm64)
    arch="arm64"
    ;;
  *)
    echo "Failed to detect target architecture"
    exit 1
    ;;
esac


if [ "$(uname)" = "Darwin" ]; then
    url="https://github.com/ActianCorp/helm-push/releases/download/v${version}/helm-push_${version}_darwin_${arch}.tar.gz"
elif [ "$(uname)" = "Linux" ] ; then
    url="https://github.com/ActianCorp/helm-push/releases/download/v${version}/helm-push_${version}_linux_${arch}.tar.gz"
else
    url="https://github.com/ActianCorp/helm-push/releases/download/v${version}/helm-push_${version}_windows_${arch}.tar.gz"
fi

echo $url

mkdir -p "${HELM_PLUGIN_DIR}/bin"
mkdir -p "${HELM_PLUGIN_DIR}/releases/v${version}"

# Download with curl if possible.
if [ -x "$(which curl 2>/dev/null)" ]; then
    curl -sSL "${url}" -o "${HELM_PLUGIN_DIR}/releases/v${version}.tar.gz"
else
    wget -q "${url}" -O "${HELM_PLUGIN_DIR}/releases/v${version}.tar.gz"
fi
tar xzf "${HELM_PLUGIN_DIR}/releases/v${version}.tar.gz" -C "${HELM_PLUGIN_DIR}/releases/v${version}"
mv "${HELM_PLUGIN_DIR}/releases/v${version}/bin/helm-cm-push" "${HELM_PLUGIN_DIR}/bin/helm-cm-push" || \
    mv "${HELM_PLUGIN_DIR}/releases/v${version}/bin/helm-cm-push.exe" "${HELM_PLUGIN_DIR}/bin/helm-cm-push"
