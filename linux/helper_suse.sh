# Adds the NR repo
add_repo() {
    zypper -n install wget gnupg

    [ "$STAGING_REPO" = "true" ] && repo="staging" || repo="production" ;
    cp "$repo"/newrelic-infra-centos.repo /etc/yum.repos.d/newrelic-infra.repo

    wget -nv -O- http://nr-downloads-main.s3-website-us-east-1.amazonaws.com/infrastructure_agent/gpg/newrelic-infra.gpg |  gpg --import
    zypper --gpg-auto-import-keys ref
    zypper -n ref -r newrelic-infra
}

install_agent() {
    zypper -n install newrelic-infra
}

# Install package from local file
install_local() {
    zypper -n install "./dist/${INTEGRATION}-${TAG}-1.x86_64.rpm"
}

# Install package from repository
install_repo() {
    zypper -n install "$INTEGRATION"
}
