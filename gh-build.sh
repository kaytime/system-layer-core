#! /bin/sh

apt-get --yes update
apt-get --yes install wget equivs curl git

deps=$(sed -e '/^#.*$/d; /^$/d; /^\s*$/d' package/dependencies | paste -sd ,)

printf >configuration "%s\n" \
	"Section: admin" \
	"Priority: required" \
	"Homepage: https://kaytime.github.io" \
	"Package: system-layer-core" \
	"Version: 0.1.0+alpha" \
	"Maintainer: Stephane Tsana <stephanetse@gmail.com>" \
	"Depends: $deps" \
	"Architecture: all" \
	"Description: Core layout metapackage for Kaytime."

equivs-build configuration
