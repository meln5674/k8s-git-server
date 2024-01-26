#!/bin/bash -xeu

set -o pipefail

# k8s-git-server docker-entrypoint.sh
# This script takes a list of users and repos to create, ensures that all users exist,
# have SSH keys generated, k8s secrets with those keys created/up-to-date, and all repos
# exist and are owned by the appropriate user, while running an SSH daemon in the background.

# Vars:
# EXTERNAL_HOST : Hostname of the server to push to
# REPO_FLAGS : Extra flags when copying the repository. Copy is performed via tar c | tar x, flags are provided to tar c
# PRIVATE_KEY_KEY : Key name to obtain user's private key in the generated secret
# PUBLIC_KEY_KEY : Key name to obtain user's public key in the generated secret
# KNOWN_HOSTS_KEY : Key name to obtain known_hosts in the generated secret

git --version
svn --version

ls "${REPO_DIR}" | while read -r scm_user ; do
    user_repo_dir="${REPO_DIR}/${scm_user}"
    if [ "${scm_user}" == "root" ]; then
        user_home=/root
    else
        user_home="/home/${scm_user}"
    fi
    user_ssh="${user_home}/.ssh"
    user_private_key="${user_ssh}/${PRIVATE_KEY_KEY}"
    user_known_hosts="${user_ssh}/${KNOWN_HOSTS_KEY}"
    find "${user_repo_dir}/" -type d -name ".k8s-git-server" | while read -r full_repo_path ; do
        repo_path="${full_repo_path##${user_repo_dir}}"
        repo_path="${repo_path%%/.k8s-git-server}"
        repo_flags_file="${user_repo_dir}/${repo_path}/.flags"
        if [ -f "${repo_flags_file}" ]; then
            mapfile -t repo_flags < "${repo_flags_file}" 
        else
            repo_flags=()
        fi
        tmprepo="$(mktemp -d)"
        tar -c -h --exclude='.git/*' -C "${full_repo_path}" "${repo_flags[@]}" . | tar -x -v -C "${tmprepo}" --no-same-owner 
        if [ -e "${user_repo_dir}/${repo_path}/.git" ]; then
            (
                cd "${tmprepo}"
                git init
                ls -la
                git config user.name "k8s-git-server ${scm_user}"
                git config user.email "${scm_user}@k8s-git-server.example.com"
                git config core.sshCommand "ssh -v -i '${user_private_key}' -o 'UserKnownHostsFile=${user_known_hosts}'"
                git add -A
                git commit -m 'k8s-git-server'
                git remote add k8s-git-server "ssh://${scm_user}@${EXTERNAL_HOST}${repo_path}"
                git push -v -u k8s-git-server --force master
            )
        fi
        if [ -e "${user_repo_dir}/${repo_path}/.svn" ]; then
            svn_url="svn+ssh://${scm_user}@${EXTERNAL_HOST}${repo_path}"
            export SVN_SSH="ssh -v -i '${user_private_key}' -o 'UserKnownHostsFile=${user_known_hosts}'"
            if [ -z "$(svn ls "${svn_url}")" ]; then
                (
                    cd "${tmprepo}"
                    svn checkout "${svn_url}" .
                    tar -c -h --exclude='.git/*' -C "${full_repo_path}" "${repo_flags[@]}" . | tar -x -v -C . --no-same-owner 
                    svn add --force .
                    svn commit -m 'k8s-git-server'
                )
            else
                (
                    cd "${tmprepo}"
                    svn checkout "${svn_url}" .
                    svn update
                    find "./" -maxdepth 1 '!' '(' -name '.svn' ')' -exec rm -rf '{}' ';'
                    tar -c -h --exclude='.git/*' -C "${full_repo_path}" "${repo_flags[@]}" . | tar -x -v -C . --no-same-owner 
                    svn resolve -R --accept working .
                    svn add --force .
                    svn commit -m 'k8s-git-server'
                )
           fi
        fi
    done
done

