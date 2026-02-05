#!/bin/sh -e

# Copied w/ love from the excellent hypnoglow/helm-s3

# Detect Helm version and use appropriate plugin manifest
update_plugin_manifest() {
    # Check for explicit version override (useful in test environments)
    if [ -n "$HELM_MAJOR_VERSION" ]; then
        helm_version="$HELM_MAJOR_VERSION"
    else
        # Detect from helm binary
        helm_version=$(helm version --short 2>/dev/null | sed -n 's/v\([0-9]*\).*/\1/p' | head -1)
    fi

    plugin_dir="${HELM_PLUGIN_DIR:-$(pwd)}"

    # Copy the old manifest for Helm3 version
    if [ "$helm_version" = "3" ] && [ -f "$plugin_dir/testdata/plugin-helm4.yaml" ]; then
        cp "$plugin_dir/testdata/plugin-helm3.yaml" "$plugin_dir/plugin.yaml"
    fi
}

# Only update manifest if not in development mode
# In development mode, tests will manage plugin.yaml directly
if [ -z "${HELM_PUSH_PLUGIN_NO_INSTALL_HOOK}" ]; then
    update_plugin_manifest
fi

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
    url="https://github.com/actiancorp/helm-push/releases/download/helm-push_v${version}_darwin_${arch}/cm-push-v${version}.tgz"
elif [ "$(uname)" = "Linux" ] ; then
    url="https://github.com/actiancorp/helm-push/releases/download/helm-push_v${version}_linux_${arch}/cm-push-v${version}.tgz"
else
    url="https://github.com/actiancorp/helm-push/releases/download/helm-push_v${version}_windows_${arch}/cm-push-v${version}.tgz"
fi

echo $url

mkdir -p "${HELM_PLUGIN_DIR}/bin"
mkdir -p "${HELM_PLUGIN_DIR}/releases/v${version}"

# Download with curl if possible.
if [ -x "$(which curl 2>/dev/null)" ]; then
    curl -sSL "${url}" -o "${HELM_PLUGIN_DIR}/releases/cm-push-v${version}.tgz"
    curl -sSL "${url}.prov" -o "${HELM_PLUGIN_DIR}/releases/cm-push-v${version}.tgz.prov"
else
    wget -q "${url}" -O "${HELM_PLUGIN_DIR}/releases/cm-push-v${version}.tgz"
    wget -q "${url}.prov" -O "${HELM_PLUGIN_DIR}/releases/cm-push-v${version}.tgz.prov"
fi
helm plugin verify "${HELM_PLUGIN_DIR}/releases/cm-push-v${version}.tgz"
tar xzf "${HELM_PLUGIN_DIR}/releases/cm-push-v${version}.tgz" -C "${HELM_PLUGIN_DIR}/releases/v${version}"
mv "${HELM_PLUGIN_DIR}/releases/v${version}/cm-push/bin/helm-cm-push" "${HELM_PLUGIN_DIR}/bin/helm-cm-push" || \
    mv "${HELM_PLUGIN_DIR}/releases/v${version}/cm-push/bin/helm-cm-push.exe" "${HELM_PLUGIN_DIR}/bin/helm-cm-push"
