#!/bin/bash -xeu

set -o pipefail

# k8s-git-server docker-entrypoint.sh
# This script takes a list of users and repos to create, ensures that all users exist,
# have SSH keys generated, k8s secrets with those keys created/up-to-date, and all repos
# exist and are owned by the appropriate user, while running an SSH daemon in the background.

# Vars:
# EXTERNAL_HOST : Hostname of the server to push to
# REPO_DIR : Directory that repo source volumes are mounted
#   Each directory should be in the format of $REPO_DIR/$USER/$REPO/.k8s-git-server
#   This trailing directory is required so that the full repo path can be determined
# PRIVATE_KEY_KEY : Key name to obtain user's private key in the generated secret
# PUBLIC_KEY_KEY : Key name to obtain user's public key in the generated secret
# KNOWN_HOSTS_KEY : Key name to obtain known_hosts in the generated secret

git --version

ls "${REPO_DIR}" | while read -r git_user ; do
    user_git_dir="${REPO_DIR}/${git_user}"
    if [ "${git_user}" == "root" ]; then
        user_home=/root
    else
        user_home="/home/${git_user}"
    fi
    user_ssh="${user_home}/.ssh"
    user_private_key="${user_ssh}/${PRIVATE_KEY_KEY}"
    user_known_hosts="${user_ssh}/${KNOWN_HOSTS_KEY}"
    find "${user_git_dir}/" -type d -name ".k8s-git-server" | while read -r full_repo_path ; do
        repo_path="${full_repo_path##${user_git_dir}}"
        repo_path="${repo_path%%/.k8s-git-server}"
        tmprepo=$(mktemp -d)
        rmdir "${tmprepo}"
        cp -r "${full_repo_path}" "${tmprepo}"
        rm -rf "${tmprepo}/.git"
        (
            cd "${tmprepo}"
            git init
            git config user.name "k8s-git-server ${git_user}"
            git config user.email "${git_user}@k8s-git-server.example.com"
            git config core.sshCommand "ssh -vvv -i '${user_private_key}' -o 'UserKnownHostsFile=${user_known_hosts}'"
            git add -A
            git commit -m 'k8s-git-server'
            git remote add k8s-git-server "ssh://${git_user}@${EXTERNAL_HOST}${repo_path}"
            git push -v -u k8s-git-server --force master
        )
    done
done
