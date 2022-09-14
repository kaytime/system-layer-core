#! /bin/sh

GIT_CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

git clone --branch $GIT_CURRENT_BRANCH https://github.com/kaytime/system-builder-kit builder

#	Wrap APT commands in functions.

source builder/configs/scripts/apt_funcs.sh

# Copy apt preference

cp builder/configs/files/preferences /etc/apt/preferences

# Adding repo keys

add_kaytime_key_compat

while :; do
	case $GIT_CURRENT_BRANCH in
	stable)
		add_kaytime_key_stable
		break
		;;
	unstable)
		add_kaytime_key_unstable
		break
		;;
	testing)
		add_kaytime_key_testing
		break
		;;
	*)
		echo "This branch $GIT_CURRENT_BRANCH doesn't not exist"
		exit
		break
		;;
	esac
done

# Build process

apt-get --yes update
apt-get --yes install wget equivs curl git

deps=$(sed -e '/^#.*$/d; /^$/d; /^\s*$/d' package/dependencies | paste -sd ,)
git_commit=$(git rev-parse --short HEAD)

printf >configuration "%s\n" \
	"Section: misc" \
	"Priority: optional" \
	"Homepage: https://kaytime.github.io" \
	"Package: system-layer-core" \
	"Version: $PROJECT_VERSION" \
	"Maintainer: Stephane Tsana <stephanetse@gmail.com>" \
	"Depends: $deps" \
	"Architecture: all" \
	"Description: Core layout metapackage for Kaytime."

equivs-build configuration
