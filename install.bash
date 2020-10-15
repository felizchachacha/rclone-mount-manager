#!/usr/bin/env bash

set -xe

readonly MYDIR="$(dirname $(realpath ${0}))"

pushd ${MYDIR}

	readonly DIRNAME=$(basename `git rev-parse --show-toplevel`)
	readonly TARGETD=/opt/"${DIRNAME}"

	if [[ "${MYDIR}" == "${TARGETD}" ]]; then
		echo "${MYDIR} we are at the destination ${TARGETD}"
	else
		rsync -svauchHPxXlit --progress . "${TARGET}"/
	fi


popd
