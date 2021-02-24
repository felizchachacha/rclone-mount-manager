#!/usr/bin/env bash

set -xe

readonly MYREALDIR="$(dirname $(realpath ${0}))"

pushd ${MYREALDIR}

	readonly DIRNAME=$(basename `git rev-parse --show-toplevel`)
	readonly TARGETD=/opt/"${DIRNAME}"

	if [[ "${MYREALDIR}" == "${TARGETD}" ]]; then
		echo "${MYREALDIR} we are at the destination ${TARGETD}"
	else
		rsync -svauchHPxXlit --progress . "${TARGET}"/ &
		cp -rv --backup etc/* /etc/
	fi

popd
