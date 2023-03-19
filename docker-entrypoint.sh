#!/bin/bash -xeu

set -o pipefail

# k8s-git-server docker-entrypoint.sh
# This script takes a list of users and repos to create, ensures that all users exist,
# have SSH keys generated, k8s secrets with those keys created/up-to-date, and all repos
# exist and are owned by the appropriate user, while running an SSH daemon in the background.

# Vars:
# EXTERNAL_HOSTS : comma separated list of hosts to use for known_hosts secrets
# CONFIG_DIR : Directory where the user repo files are mounted.
#    Each file in this directory should be named for a user,
#    and contain a newline-separate list of absolute paths for repos to create for that user.
# SECRET_PREFIX : Prefix to come before the username when creating key secrets
# SECRET_SUFFIX : Suffix to come before the username when creating key secrets
# PRIVATE_KEY_KEY : Key name to store user's private key in the generated secret
# PUBLIC_KEY_KEY : Key name to store user's public key in the generated secret
# KNOWN_HOSTS_KEY : Key name to store known_hosts in the generated secret
# READY_FILE : File to touch when all users have been created and all repos configured

function indent_file {
    set +x
    indent="$1"
    file="$2"
    while read -r line; do
        echo "${indent}${line}"
    done < "${file}"
    set -x
}

function secret_patch {
    private_key="$1"
    public_key="$2"
    known_hosts="$3"
    echo "stringData:"
    echo "  '${PRIVATE_KEY_KEY}': |"
    indent_file "    " "${private_key}"
    echo "  '${PUBLIC_KEY_KEY}': |"
    indent_file "    " "${public_key}"
    echo "  '${KNOWN_HOSTS_KEY}': |"
    indent_file "    " "${known_hosts}"
}

ssh-keygen -A

"$(which sshd)" -D -e &
sshd_pid=$!

mkdir -p /root/.ssh
ssh-keygen -f /root/.ssh/id_rsa

cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

known_hosts=/root/.ssh/known_hosts

while ! ssh-keyscan localhost > "${known_hosts}" ; do
    echo "sshd is not yet up, waiting to generate known_hosts"
    sleep 5
done

sed -i "s|localhost|${EXTERNAL_HOSTS}|g" "${known_hosts}"

ls "${CONFIG_DIR}" | while read -r user ; do
    if ! id "${user}"; then
        adduser "${user}" -D
    fi
    if [ "${user}" == root ]; then
        user_home=/root
    else
        user_home="/home/${user}"
        usermod -p '*' "${user}"
    fi
    user_ssh="${user_home}/.ssh"
    user_private_key="${user_ssh}/id_rsa"
    user_public_key="${user_ssh}/id_rsa.pub"
    user_authorized_keys="${user_ssh}/authorized_keys"
    mkdir -p "${user_ssh}"
    if ! [ -f "${user_private_key}" ]; then
        ssh-keygen -f "${user_private_key}" ${SSH_KEYGEN_ARGS:-}
    fi
    ls "${user_ssh}"
    public_key="$(cat "${user_public_key}")"
    if ! grep -F "${public_key}" "${user_authorized_keys}" ; then
        echo >> "${user_authorized_keys}"
        cat "${user_public_key}" >> "${user_authorized_keys}"
    fi

    secret_name=""
    if [ -n "${SECRET_PREFIX}" ]; then
        secret_name="${secret_name}${SECRET_PREFIX}-"
    fi
    secret_name="${secret_name}${user}"
    if [ -n "${SECRET_SUFFIX}" ]; then
        secret_name="${secret_name}-${SECRET_SUFFIX}"
    fi
    if ! kubectl get secret "${secret_name}" ; then
        kubectl create secret generic "${secret_name}" \
            --from-file "${PRIVATE_KEY_KEY}=${user_private_key}" \
            --from-file "${PUBLIC_KEY_KEY}=${user_public_key}" \
            --from-file "${KNOWN_HOSTS_KEY}=/root/.ssh/known_hosts"
    else
        secret_patch \
            "${user_private_key}" \
            "${user_public_key}" \
            "${known_hosts}" \
            | kubectl patch secret "${secret_name}" --patch-file /dev/stdin
    fi

    chown -R "${user}" "${user_home}"
    chmod -R 0700 "${user_ssh}"

    while read -r repo ; do
        mkdir -p "${repo}"
        if ! git -C "${repo}" status; then
            git -C "${repo}" init --bare
        fi
        chown -R "${user}" "${repo}"
    done < "${CONFIG_DIR}/${user}"
done

touch "${READY_FILE}"

jobs

wait "${sshd_pid}"
