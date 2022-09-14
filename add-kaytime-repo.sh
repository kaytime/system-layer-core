#!/bin/bash

GIT_CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

unknown_os() {
    echo "Unfortunately, your operating system distribution and version are not supported by this script."
    echo
    echo "You can override the OS detection by setting os= and dist= prior to running this script."
    echo "You can find a list of supported OSes and distributions on our website: https://packagecloud.io/docs#os_distro_version"
    echo
    echo "For example, to force Ubuntu Trusty: os=ubuntu dist=trusty ./script.sh"
    echo
    echo "Please email support@packagecloud.io and let us know if you run into any issues."
    exit 1
}

gpg_check() {
    echo "Checking for gpg..."
    if command -v gpg >/dev/null; then
        echo "Detected gpg..."
    else
        echo "Installing gnupg for GPG verification..."
        apt-get install -y gnupg
        if [ "$?" -ne "0" ]; then
            echo "Unable to install GPG! Your base system has a problem; please check your default OS's package repositories because GPG should work."
            echo "Repository installation aborted."
            exit 1
        fi
    fi
}

curl_check() {
    echo "Checking for curl..."
    if command -v curl >/dev/null; then
        echo "Detected curl..."
    else
        echo "Installing curl..."
        apt-get install -q -y curl
        if [ "$?" -ne "0" ]; then
            echo "Unable to install curl! Your base system has a problem; please check your default OS's package repositories because curl should work."
            echo "Repository installation aborted."
            exit 1
        fi
    fi
}

install_debian_keyring() {
    if [ "${os,,}" = "debian" ]; then
        echo "Installing debian-archive-keyring which is needed for installing "
        echo "apt-transport-https on many Debian systems."
        apt-get install -y debian-archive-keyring &>/dev/null
    fi
}

detect_os() {

    os="debian"
    dist="trixie"

    echo "Operating system $os/$dist."
}

detect_version_id() {
    version_id="13"
}

main() {
    detect_os
    curl_check
    gpg_check
    detect_version_id

    # Need to first run apt-get update so that apt-transport-https can be
    # installed
    echo -n "Running apt-get update... "
    apt-get update &>/dev/null
    echo "done."

    # Install the debian-archive-keyring package on debian systems so that
    # apt-transport-https can be installed next
    install_debian_keyring

    echo -n "Installing apt-transport-https... "
    apt-get install -y apt-transport-https &>/dev/null
    echo "done."

    gpg_key_url="https://packagecloud.io/kaytime/$GIT_CURRENT_BRANCH/gpgkey"
    apt_config_url="https://packagecloud.io/install/repositories/kaytime/$GIT_CURRENT_BRANCH/config_file.list?os=${os}&dist=${dist}&source=script"

    apt_source_path="/etc/apt/sources.list.d/kaytime_$GIT_CURRENT_BRANCH.list"
    apt_keyrings_dir="/etc/apt/keyrings"
    if [ ! -d "$apt_keyrings_dir" ]; then
        mkdir -p "$apt_keyrings_dir"
    fi
    gpg_keyring_path="$apt_keyrings_dir/kaytime_$GIT_CURRENT_BRANCH-archive-keyring.gpg"

    echo -n "Installing $apt_source_path..."

    # create an apt config file for this repository
    curl -sSf "${apt_config_url}" >$apt_source_path
    curl_exit_code=$?

    if [ "$curl_exit_code" = "22" ]; then
        echo
        echo
        echo -n "Unable to download repo config from: "
        echo "${apt_config_url}"
        echo
        echo "This usually happens if your operating system is not supported by "
        echo "packagecloud.io, or this script's OS detection failed."
        echo
        echo "You can override the OS detection by setting os= and dist= prior to running this script."
        echo "You can find a list of supported OSes and distributions on our website: https://packagecloud.io/docs#os_distro_version"
        echo
        echo "For example, to force Ubuntu Trusty: os=ubuntu dist=trusty ./script.sh"
        echo
        echo "If you are running a supported OS, please email support@packagecloud.io and report this."
        [ -e $apt_source_path ] && rm $apt_source_path
        exit 1
    elif [ "$curl_exit_code" = "35" -o "$curl_exit_code" = "60" ]; then
        echo "curl is unable to connect to packagecloud.io over TLS when running: "
        echo "    curl ${apt_config_url}"
        echo "This is usually due to one of two things:"
        echo
        echo " 1.) Missing CA root certificates (make sure the ca-certificates package is installed)"
        echo " 2.) An old version of libssl. Try upgrading libssl on your system to a more recent version"
        echo
        echo "Contact support@packagecloud.io with information about your system for help."
        [ -e $apt_source_path ] && rm $apt_source_path
        exit 1
    elif [ "$curl_exit_code" -gt "0" ]; then
        echo
        echo "Unable to run: "
        echo "    curl ${apt_config_url}"
        echo
        echo "Double check your curl installation and try again."
        [ -e $apt_source_path ] && rm $apt_source_path
        exit 1
    else
        echo "done."
    fi

    echo -n "Importing packagecloud gpg key... "
    # import the gpg key
    curl -fsSL "${gpg_key_url}" | gpg --dearmor >${gpg_keyring_path}
    # grant 644 permisions to gpg keyring path
    chmod 0644 "${gpg_keyring_path}"
    # check for os/dist based on pre debian stretch
    if
        { [ "${os,,}" = "debian" ] && [ "${version_id}" -lt 9 ]; } ||
            { [ "${os,,}" = "ubuntu" ] && [ "${version_id}" -lt 16 ]; } ||
            { [ "${os,,}" = "linuxmint" ] && [ "${version_id}" -lt 19 ]; } ||
            { [ "${os,,}" = "raspbian" ] && [ "${version_id}" -lt 9 ]; } ||
            { { [ "${os,,}" = "elementaryos" ] || [ "${os,,}" = "elementary" ]; } && [ "${version_id}" -lt 5 ]; }
    then
        # move to trusted.gpg.d
        mv ${gpg_keyring_path} /etc/apt/trusted.gpg.d/kaytime_$GIT_CURRENT_BRANCH.gpg
        # deletes the keyrings directory if it is empty
        if ! ls -1qA $apt_keyrings_dir | grep -q .; then
            rm -r $apt_keyrings_dir
        fi
    fi
    echo "done."

    echo -n "Running apt-get update... "
    # update apt on this system
    apt-get update &>/dev/null
    echo "done."

    echo
    echo "The repository is setup! You can now install packages."
}

main
