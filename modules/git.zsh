#!/usr/bin/env zsh

# All of the expensive calls rolled into one method
git-revparse-target() {
    pushd "$1"
    {
        \git rev-parse "$@" 2>/dev/null
    } always { [[ "$1" == "$OCWD" ]] || popd }
}
is-git-repository() { \git rev-parse --is-inside-work-tree 2>/dev/null }

(( ${+gitrp_safeparms} == 1 )) || local -ar gitrp_safeparms=(
    --show-toplevel
    --git-dir
    --is-bare-repository
    --show-superproject-working-tree
)
# NOTE: --show-superproject-working-tree This must be last; it returns nothing (not even a blank line) when there's no submodule

local ___AR="repo_remotes=( ) git_status=( )  repo_submodules=( )" ___AS="git_property_map=( ) repo_status_unstaged=( ) repo_status_staged=( ) repo_subtrees=( ) repo_submodule_branches=( )"
alias repo-details:locals="local -a ${___AR}; local -A ${___AS}; local REPO_ABSOLUTE_ROOT=''"
alias repo-details:globals="typeset -gxa ${___AR}; typeset -gxA ${___AS}; typeset -g REPO_ABSOLUTE_ROOT=''"

repo-details() {
    repo-details:globals

    is-git-repository || return $?

    get-gitcommands() {
        \git remote -v 2>/dev/null || { return 1 }
        print -- '--'
        \git rev-parse HEAD 2>/dev/null || print detached
        \git rev-parse "${gitrp_safeparms[@]}" 2>/dev/null || {
            print -- 'not initialized'
            return 1
        }
        print -- $'--'
        \git submodule --quiet foreach 'git rev-parse --show-toplevel --abbrev-ref HEAD'
        print -- $'--'
        # \git submodule --quiet foreach 'git rev-parse --symbolic --branches'
        \git status --porcelain -b 2>/dev/null
    }

    store-array-slice() {
        (( $# >= 1 )) || { print -- "$0: Invalid Usage"; exit 1 }
        local __AR_NAME="$1"; shift
        (( $# == 0 )) && set -A "$__AR_NAME" || set -A "$__AR_NAME" "${(@)${(@)argv[1,$(( ${argv[(i)--]} - 1 ))]}[@]}"
        shift $(( ${#${(P@)__AR_NAME}} + 1 ))
        typeset -ga new_argv=( "$@" )
    }
    local -a git_remotes=( ) git_props=( ) submod_result=( ) git_submodule_branches=( )
    () {

        local -a new_argv=( )
        [[ "${argv[1]}" == '--' ]] && { shift; typeset -gxa git_remotes=( ) } || {
            store-array-slice git_remotes "$@"; argv=( "${new_argv[@]}" )
        }
        [[ "${argv[1]}" == '--' ]] && { shift; typeset -gxa git_props=( ) } || {
            [[ "${argv[1]}" != 'HEAD' ]] || shift
            store-array-slice git_props "$@"; argv=( "${new_argv[@]}" )
        }
        [[ "${argv[1]}" == '--' ]] && { shift; typeset -gxa submod_result=( ) } || {
            store-array-slice submod_result "$@"; argv=( "${new_argv[@]}" )
        }
        typeset -gxa git_status=( "$@" )

    } "${${(f)$(get-gitcommands)}[@]}"
    (( $? == 0 )) || return 1

    local -r REPO_CONFIG="${${(M)git_status[@]:#\#*}##\#\# }"
    git_status=( "${git_status[@]:#\#\# *}" )

    local -A prop_map=(
        nearest-root  "${git_props[2]}"
        git-rev       "${git_props[1]}"
        local-branch  "${${${(M)REPO_CONFIG:#* on *}:+${REPO_CONFIG##* }}:-${REPO_CONFIG%%...*}}"
        remote-branch "${${${${(M)REPO_CONFIG:#* on *}:+[none]}:-${REPO_CONFIG##*...}}%%[[:space:]\[]*}"
        has-commits   "${${${(M)REPO_CONFIG:#No commits yet on *}:+0}:-1}"
        has-remotes   "${${${(M)${#git_remotes[@]}:#0}:+no}:-yes}"
        ahead-by      "${${${(M)REPO_CONFIG:#*\[ahead*}:+${${REPO_CONFIG##*\[ahead[[:space:]]}%%[\],]*}}:-0}"
        behind-by     "${${${(M)REPO_CONFIG:#*(\[|, )behind*}:+${${REPO_CONFIG##*(\[|, )behind[[:space:]]}%%[\],]*}}:-0}"
        git-dir       "${${${git_props[3]}:A}##${git_props[2]}/}"
        is-bare       "${${${(M)${git_props[4]}:#true}:+1}:-0}"
        parent-repo   "${git_props[5]:-}"
        is-submodule  0
    )
    [[ "${${prop_map[git-dir]}:h:t}" != "modules" ]] || {
        prop_map[is-submodule]=1
    }

    [[ "${prop_map[local-branch]}" != "${prop_map[remote-branch]}" ]] || prop_map[remote-branch]=''

    [[ -z "${submod_result}" ]] || {
        typeset -ga repo_submodules=( "${${(M@)submod_result[@]:#/*}[@]##${prop_map[nearest-root]}/}" )
        typeset -gA repo_submodule_branches=( "${submod_result[@]}" )
    }

    typeset -ga u_ren=( ${(@)${(M)git_status:#([AMDR ]R *)}##???} )  \
             u_mod=( ${(@)${(M)git_status:#([AMDR ]M *)}##???} )     \
             u_add=( ${(@)${(M)git_status:#([AMDR ]A *)}##???} )     \
             u_del=( ${(@)${(M)git_status:#([AMDR ]D *)}##???} )     \
             u_new=( ${(@)${(M)git_status:#\?\?*}##???} )            \
             s_mod=( ${(@)${(M)git_status:#R[AMDR ] *}##???} )       \
             s_ren=( ${(@)${(M)git_status:#M[AMDR ] *}##???} )       \
             s_add=( ${(@)${(M)git_status:#A[AMDR ] *}##???} )       \
             s_del=( ${(@)${(M)git_status:#D[AMDR ] *}##???} )
    set +x
    local RP=''
    for RP in u_{ren,mod,add,del,new}; do repo_status_unstaged+=( "${RP##u_}-paths"  "${(j.:.)${(q@)${(P@)RP}}}" "${RP##u_}-len" ${#${(P@)RP}} ); done
    for RP in s_{ren,mod,add,del}; do repo_status_staged+=( "${RP##s_}-paths"  "${(j.:.)${(q@)${(P@)RP}}}" "${RP##s_}-len" ${#${(P@)RP}} ); done

    typeset -gA git_property_map=( "${(kv)prop_map[@]}" )

    if [[ "${git_property_map[remote-branch]}" == '[none]' ]]; then git_property_map[remote-branch]=''; fi

}

plib_is_git() print -n -- ${${$(\git branch 2>/dev/null):+1}:-0}
plib_git_remote_defined() print -n -- ${${$(\git remote -v 2>/dev/null):+1}:-0}

plib_git_branch(){
    __ref=$(\git symbolic-ref HEAD 2> /dev/null) || __ref="detached" || return;
    echo -n "${__ref#refs/heads/}";
    unset __ref;
}

plib_git_rev(){
    __rev=$(\git rev-parse HEAD | cut -c 1-7);
    echo -n "${__rev}";
    unset __rev;
}



plib_git_remote_name(){
    if \git remote -v | grep origin > /dev/null; then
        echo -ne "origin"
    else
        echo -ne "`\git remote -v | head -1 | awk '{print $1}' | tr -d " \n"`"
    fi
}

plib_git_dirty(){

    [[ -z "${PLIB_GIT_TRACKED_COLOR}" ]] && PLIB_GIT_TRACKED_COLOR=green
    [[ -z "${PLIB_GIT_UNTRACKED_COLOR}" ]] && PLIB_GIT_UNTRACKED_COLOR=red

    [[ -z "${PLIB_GIT_ADD_SYM}" ]] && PLIB_GIT_ADD_SYM=+
    [[ -z "${PLIB_GIT_DEL_SYM}" ]] && PLIB_GIT_DEL_SYM=-
    [[ -z "${PLIB_GIT_MOD_SYM}" ]] && PLIB_GIT_MOD_SYM=⭑
    [[ -z "${PLIB_GIT_NEW_SYM}" ]] && PLIB_GIT_NEW_SYM=?

    __git_st=$(\git status --porcelain 2>/dev/null)

    __mod_t=$(echo ${__git_st} | grep '^M[A,M,D,R, ]\{1\} \|^R[A,M,D,R, ]\{1\} ' | wc -l | tr -d ' ');
    __add_t=$(echo ${__git_st} | grep '^A[A,M,D,R, ]\{1\} ' | wc -l | tr -d ' ');
    __del_t=$(echo ${__git_st} | grep '^D[A,M,D,R, ]\{1\} ' | wc -l | tr -d ' ');

    __mod_ut=$(echo ${__git_st} | grep '^[A,M,D,R, ]\{1\}M \|^[A,M,D,R, ]\{1\}R ' | wc -l | tr -d ' ');
    __add_ut=$(echo ${__git_st} | grep '^[A,M,D,R, ]\{1\}A ' | wc -l | tr -d ' ');
    __del_ut=$(echo ${__git_st} | grep '^[A,M,D,R, ]\{1\}D ' | wc -l | tr -d ' ');

    __new=$(echo ${__git_st} | grep '^?? ' | wc -l | tr -d ' ');

    [[ "$__add_t" != "0" ]]  && echo -n " %F{$PLIB_GIT_TRACKED_COLOR}${PLIB_GIT_ADD_SYM}%f";
    [[ "$__add_ut" != "0" ]] && echo -n " %F{$PLIB_GIT_UNTRACKED_COLOR}${PLIB_GIT_ADD_SYM}%f";
    [[ "$__mod_t" != "0" ]]  && echo -n " %F{$PLIB_GIT_TRACKED_COLOR}${PLIB_GIT_MOD_SYM}%f";
    [[ "$__mod_ut" != "0" ]] && echo -n " %F{$PLIB_GIT_UNTRACKED_COLOR}${PLIB_GIT_MOD_SYM}%f";
    [[ "$__del_t" != "0" ]]  && echo -n " %F{$PLIB_GIT_TRACKED_COLOR}${PLIB_GIT_DEL_SYM}%f";
    [[ "$__del_ut" != "0" ]] && echo -n " %F{$PLIB_GIT_UNTRACKED_COLOR}${PLIB_GIT_DEL_SYM}%f";
    [[ "$__new" != "0" ]]    && echo -n " %F{$PLIB_GIT_UNTRACKED_COLOR}${PLIB_GIT_NEW_SYM}%f";

    unset __mod_ut __new_ut __add_ut __mod_t __new_t __add_t __del
}

plib_git_left_right(){
    [[ -z "${PLIB_GIT_PUSH_SYM}" ]] && PLIB_GIT_PUSH_SYM=↑
    [[ -z "${PLIB_GIT_PULL_SYM}" ]] && PLIB_GIT_PULL_SYM=↓
    if [[ "$(plib_git_remote_defined)" == 1 ]]; then
        function _branch(){
            __ref=$(\git symbolic-ref HEAD 2> /dev/null) || __ref="detached" || return;
            echo -ne "${__ref#refs/heads/}";
            unset __rev;
        }
        if [[ $(plib_git_branch) != "detached" ]]; then
            __pull=$(\git rev-list --left-right --count `_branch`...`plib_git_remote_name`/`_branch` 2>/dev/null | awk '{print $2}' | tr -d ' \n');
            __push=$(\git rev-list --left-right --count `_branch`...`plib_git_remote_name`/`_branch` 2>/dev/null | awk '{print $1}' | tr -d ' \n');
            [[ "$__pull" != "0" ]] && [[ "$__pull" != "" ]] && echo -n " ${__pull}${PLIB_GIT_PULL_SYM}";
            [[ "$__push" != "0" ]] && [[ "$__push" != "" ]] && echo -n " ${__push}${PLIB_GIT_PUSH_SYM}";

            unset __pull __push __branch
        fi
    fi
}

plib_git_commit_since(){
    __sedstr='s| year\(s\)\{0,1\}|Y|g;s| month\(s\)\{0,1\}|Mo|g;s| week\(s\)\{0,1\}|W|g;s| day\(s\)\{0,1\}|D|g;s| hour\(s\)\{0,1\}|H|g;s| minute\(s\)\{0,1\}|Mi|g;s| second\(s\)\{0,1\}|S|g'
    __commit_since=`git log -1 --format='%cr' | sed ${__sedstr} | tr -d " ago\n"`

    echo -ne "${__commit_since}"

    unset __commit_since __sedstr
}

plib_is_git_rebasing(){
    [[ $(ls `git rev-parse --git-dir` | grep rebase-apply) ]] && echo -ne 1 || echo -ne 0
}
