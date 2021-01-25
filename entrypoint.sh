#!/bin/bash

set -o errexit
set -o pipefail

[[ -n $GITHUB_ACTION_PATH ]] || GITHUB_ACTION_PATH=$(pwd)
[[ -n $PKGDIR ]] || PKGDIR="./dist"

if [[ -z $POST_INSTALL ]]; then
    POST_INSTALL="
    test -e /var/db/newrelic-infra/newrelic-integrations/bin/${INTEGRATION}
    /var/db/newrelic-infra/newrelic-integrations/bin/${INTEGRATION} -show_version 2>&1 | grep -e $TAG
    "
fi
POST_INSTALL="$POST_INSTALL
$POST_INSTALL_EXTRA"

function build_and_test() {
    if [[ $1 = "true" ]]; then upgradesuffix="-upgrade"; fi
    dockertag="$INTEGRATION:$distro-$TAG$upgradesuffix"

    if ! docker build -t "$dockertag" -f "$GITHUB_ACTION_PATH/dockerfiles-test/Dockerfile-$distro"\
      --build-arg TAG="$TAG"\
      --build-arg INTEGRATION="$INTEGRATION"\
      --build-arg UPGRADE="$1"\
      --build-arg PKGDIR="$PKGDIR"\
    .; then
        echo "❌ Clean install failed on $distro" 1>&2
        return 1
    fi
    echo "✅ Installation for $dockertag succeeded"

    echo "ℹ️ Running post-installation checks"
    echo "$POST_INSTALL" | grep -e . | while read -r check; do
      if ! ( echo "$check" | docker run --rm -i "$dockertag" ); then
        echo "$check"
        echo "❌ Failed for $INTEGRATION:$distro-$TAG"
        return 2
      fi
    done
    echo "✅ Post-installation checks for $dockertag succeeded"
    return 0
}

echo "$DISTROS" | tr " " "\n" | while read -r distro; do
    echo "::group::Build base image for $distro"
    docker build -t "$distro-base" -f "$GITHUB_ACTION_PATH/dockerfiles-base/Dockerfile-base-$distro" .
    echo "::endgroup::"

    echo "::group::Clean install on $distro"
    build_and_test false
    echo "::endgroup::"

    if [[ "$UPGRADE" = "true" ]]; then
        echo "::group::Upgrade path on $distro"
        build_and_test true
        echo "::endgroup::"
    else
        echo "ℹ️ Skipping upgrade path on $distro"
    fi
done
