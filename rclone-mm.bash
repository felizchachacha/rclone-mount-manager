#!/usr/bin/env bash

# rclone mount manage

set -e

readonly ME=$(realpath $0)
readonly MYDIR=$(dirname ${ME})
readonly MNT_ROOT=/mnt/rclone
readonly DEFS=(--fast-list)
readonly CONF_F=~/.config/rclone/rclone.conf
readonly CONF_BACKUP=/datos/git/storage/priv/rclone.conf
readonly LOGS_D=/var/log/rclone
readonly MNT_DEFS=( --vfs-cache-mode full --log-level INFO --cache-tmp-upload-path=/tmp/rclone/upload --cache-chunk-path=/tmp/rclone/chunks 
 --cache-workers=8 --cache-writes --cache-dir=/tmp/rclone/cachevfs --cache-db-path=/tmp/rclone/db --checkers=16 --daemon )


function listmounts() {
	mount ${*} | grep rclone
	exit
}

function mountone() {
	local mnt_name=${1}
	shift # past mount name
	local presence=$((${ME} ps | grep -v bash; ${ME} mount) | grep ${mnt_name})
	if [[ ${presence} != '' ]]; then
		echo "${mnt_name} already mounted:"
		echo "${presence}"
	else
		[ -d ${LOGS_D} ] ||  mkdir ${LOGS_D}
		logrotate /etc/logrotate.d/rclone.logrotate || rsync -uv --progress ${MYDIR}/etc/logrotate.d/rclone.logrotate /etc/logrotate.d/rclone.logrotate && logrotate /etc/logrotate.d/rclone.logrotate
		rclone mount ${mnt_name}: ${MNT_ROOT}/${mnt_name} --log-file=${LOGS_D}/${mnt_name}.log ${MNT_DEFS[*]} ${DEFS[*]} ${*}
	fi
}

function mountall() {
	for r in $(${ME} list); do
		mountone ${r} 
	done
}

function unmountone() {
	local mnt_name=${1}
	shift # past mount name
	[ -d ${mnt_name} ] && umount -v ${mnt_name} ${*} || umount -v ${MNT_ROOT}/${mnt_name} ${*}
}

function unmountall() {
	for m in $(${ME} mount | cut -d\: -f1); do
		unmountone ${m}
	done
}

[ ${#} -eq 0 ] && set -- list

while [ ${#} -gt 0 ]; do
	case ${1} in
		'-v')
			shift # past param
			set -x
		;;
		'ps')
			shift # past action
			ps -ef | grep rclone | grep -v "grep\|${0} ps"
		;;
		'configpath')
			echo "${CONF_F}"
			shift # past action
		;;
		'mount')
			shift # past action
			if [[ ${1} == '' ]]; then
				listmounts
			elif [[ ${1} == '-a' ]]; then
				shift # past param
				mountall ${*}
			else
				for r in ${*}; do
					mountone ${r} &
					shift # past value
				done
			fi
		;;
		'unmount')
			shift # past action
			if [[ ${1} == '' ]]; then
				listmounts
			elif [[ ${1} == '-a' ]]; then
				shift # past param
				unmountall ${*}
			else
				for m in ${*}; do
					unmountone ${m} &
					shift # past value
				done
			fi
		;;
		'df')
			shift # past action
			if [[ ${1} == '' ]]; then 
				df -hT ${*} $(mount | awk '/rclone/ {print $3}')
			else
				declare -a MountedRemotes
				for searchval in ${*}; do
					if ${ME} prov | grep ${searchval}; then
						shift # past value
						for r in $(${ME} prov ${searchval}); do
							${ME} df ${r} &
						done
					elif ${ME} mount | grep ${searchval}; then
						shift # past value
						MountedRemotes+=(${MNT_ROOT}/${searchval})
					fi
				done
				(( ${#MountedRemotes[@]} > 0 )) && df -hT ${MountedRemotes[*]}
			fi
		;;
		'cat')
                        shift # past action
			cat ${CONF_F} ${*}
		;;

		'vim')
                        shift # past action
			${ME} backupconf
			vim ${CONF_F} ${*}
			${ME} backupconf
		;;
		'countprov')
                        shift # past action
			${ME} cat | awk '/type =/ {print $3}' | sort | uniq -c | sort -n
		;;
		'prov')
                        shift # past action
			[[ ${1} == '' ]] && ${ME} cat | awk -vRS='\n\n' -vFS='\\[|\n|\\]|=| '  '/type = / {print $7"\t"$2}' | sort
			for searchval in ${*}; do
				shift # past value
				if [ -d ${searchval} ] && [[ $(dirname ${searchval}) == ${MNT_ROOT} ]]; then
					${ME} prov $(basename ${searchval})
				else
					${ME} cat |  awk -vRS='[' -vFS='=|\t| |\n|]' -vOFS='' "/type = ${searchval}/ {print \"${searchval}\t\"\$1} /^${searchval}\]/ {print \"${searchval}\t\"\$6}"
				fi
			done | sort
		;;
		'backupconf')
                        shift # past action
			cp -av ${CONF_F} ${CONF_BACKUP}
			pushd $(dirname ${CONF_BACKUP})
				git commit ${CONF_BACKUP} -m "${CONF_BACKUP} $(date +%F_%T)"
				git push
			popd
		;;
		'list')
                        shift # past action
			rclone listremotes ${*} | sed 's/\:$//g'
		;;
		*)
			rclone ${DEFS[*]} ${*}
                        shift # past action
		;;
	esac
done


