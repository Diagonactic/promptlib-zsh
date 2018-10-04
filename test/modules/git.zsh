#!/bin/zsh
source ../test.zsh
source "../../modules/git.zsh"

# Create test repositories

alias return:cleanup-fail='() { (( $# == 1 )) && cleanup_fail "$1" || cleanup_fail }'
declare -i IS_DIRTY=0
cleanup() {
    (( $# >= 1 )) || __ut/die_usage 1 "Function $0: Expected 'fail' or 'success' as first parameter and (optional) message as second parameter"
    [[ "$1" == (success|fail)* ]] || __ut/die_usage 1 "Function $0: Expected 'fail' or 'success' as first parameter - got '$1'"
    local -ir IS_FAILURE="${${${(M)1:#fail*}:+1}:-0}"; shift
    [[ -z "${1:-}" ]] || { local -r MSG="${2:-}"; shift }

    print-cleanup-result() {
        case "$IS_FAILURE" in
            (0) (( ${+MSG} == 0 ))       || __success "$1"
                (( ${+CLEAN_MSG} == 0 )) || { __print_fail "$CLEAN_MSG"; return 2 }
                ;;
            (1) (( ${+CLEAN_MSG} == 0 )) || 1+=$'\n\t - '"$CLEAN_MSG"
                __print_fail "$1"
                return 1
                ;;
        esac
    }
    safe-remove-test-repo() {
        if (( $# != 1 )) || [[ -z "${1:-}" ]]; then __ut/die_usage 1 "Function $0: Expected path to remove"; fi
        local -r REPO="$1"
        {
            if [[ -d "$REPO" ]]; then
                if [[ "$REPO" != '/' && "$REPO" != "$HOME/"* && "$REPO" == /* ]]; then
                    rm -rf "$REPO" || { local -r CLEAN_MSG="Failed to remove '$REPO'"; print-cleanup-result; exit 1 }
                    return 0
                fi
                local -r CLEAN_MSG="Failed to remove '$REPO' - the path looked too dangerous to 'rm -rf'.  Remove it manually"
                print-cleanup-result && IS_DIRTY=0 || return $?
            else
                if (( IS_FAILURE == 1 || ${+CLEAN_MSG} == 1 || ${+MSG} == 1 )); then
                        print-cleanup-result || return $?
                fi
            fi
        } always { IS_DIRTY=0 }
    }
    [[ -z "$REPO" ]] || safe-remove-test-repo "$REPO"
    [[ -z "$REPO_ALT" ]] || safe-remove-test-repo "$REPO_ALT"
}
reset_test_repos() {
    reset-repo() {
        if [[ -n "$1" && -d "$1" && "$1" == /tmp* ]]; then
            rm -rf "$1/*" "$1/.*" && return 0 || __fail "Falied to clear repository at: '$REPO'"
        fi
        __fail "Failed to clean repository at '$REPO' - it didn't exist or its name was possibly unsafe"
    }
    reset-repo "$REPO"
    reset-repo "$REPO_ALT"
}
create_test_repos() {
    pushd "$REPO_ALT"
    {
        command git init > /dev/null 2>&1
    } always { popd }
    pushd "$REPO"
    {
        command git init > /dev/null 2>&1
    } always { popd }
}
yes_no() {
    print_value "$1" "${${${(M)2:#1}:+yes}:-no}"
}
print_value() {
    print -- "${(r.20.)1}: '$2'"
}
print_values() {
    # set -x
    # print -l "${(kv)git_property_map[@]}"
    # local KEY=''
    # for KEY in "${(k)git_property_map[@]}"; do
    #     print -- "k:'$KEY' -:- v:'${git_property_map[$KEY]}'"
    # done
    if (( ${#git_remotes[@]} > 0 )); then
        __ut/center $'\e[4;36m Remotes \e[0;37m' '-'
        __dump_array 7 "${git_remotes[@]}"
    else
        print -- "No Remotes"
    fi
    if (( ${#${(kv)repo_status_unstaged[@]}} > 0 )); then
        __ut/center $' \e[4;36m Unstaged Status \e[0;37m ' '-'
        __dump_assoc 7 repo_status_unstaged
    fi
    if (( ${#${(kv)repo_status_staged[@]}} > 0 )); then
        __ut/center $' \e[4;36m Staged Status \e[0;37m ' '-'
        __dump_assoc 7 repo_status_staged
    fi
    if (( ${#git_status[@]} > 0 )); then
        __ut/center $' \e[4;36m Status \e[0;37m ' '-'

        __dump_array 7 "${git_remotes[@]}"
        print -- "Status:"
        print -l -- "${git_status[@]}"
    else
        print -- "No Status"
    fi

    print_value "Remote Branch" ${git_property_map[remote-branch]}
    print_value "Local Branch" ${git_property_map[local-branch]}
    print_value "Nearest Root" ${git_property_map[nearest-root]}
    print_value "Rev" ${git_property_map[git-rev]}
    yes_no      "Has Commits" ${git_property_map[has-commits]}
    yes_no      "Has Remotes" ${git_property_map[has-remotes]}
}
check_temp() { [[ -n "$1" && -d "$1" ]]; }

wrap-fplib-git-details() safe_execute -x -r 0 fplib-git-details

# Create test repositories in /tmp
declare -gr REPO="$(mktemp -d)"
IS_DIRTY=1
declare -gr REPO_ALT="$(mktemp -d)" || { __fail "Failed to create temporary directory" }
if ! check_temp "$REPO" || ! check_temp "$REPO_ALT"; then __fail "Failed to create temporary directory"; fi
{
    create_test_repos
    unit_group "empty-no-remote" "Check empty, but valid, git repostiory properties - no remote" test_sections {
        pushd "$REPO"
        {
            fplib-git-details:locals
            safe_execute -x -r 0 fplib-git-details

            assert/association "git_property_map" is-equal-to    \
                git-rev       'detached'  has-commits   '0'      \
                has-remotes   'no'        local-branch  'master' \
                nearest-root  "$REPO"     remote-branch ''
            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 fplib-git-details
                assert/association "git_property_map" is-equal-to    \
                    git-rev       'detached'  has-commits   '0'      \
                    has-remotes   'no'        local-branch  'master' \
                    nearest-root  "$REPO_ALT"     remote-branch ''
            } always { popd }
        } always { popd }
    }
    unit_group "empty-no-remote-add" "Git repositories with one added file" test_sections {
        pushd "$REPO"
        {
            touch "$REPO/test.txt"
            fplib-git-details:locals
            wrap-fplib-git-details

            assert/association "git_property_map" is-equal-to    \
                git-rev       'detached'  has-commits   '0'  has-remotes   'no'  local-branch  'master'  nearest-root "$REPO"  remote-branch ''
            assert/association "repo_status_staged" is-equal-to \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  ren-len '0'  ren-paths ''
            assert/association "repo_status_unstaged" is-equal-to \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  new-len '1'  new-paths 'test.txt'  ren-len '0'  ren-paths ''

            command git add "$REPO/test.txt"                     || __fail "Couldn't git add test.txt"
            wrap-fplib-git-details
            assert/association "git_property_map" is-equal-to    \
                git-rev       'detached'  has-commits   '0'  has-remotes   'no'  local-branch  'master'  nearest-root "$REPO"  remote-branch ''
            assert/association "repo_status_staged" is-equal-to \
                add-len 1  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  ren-len '0'  ren-paths ''
            assert/association "repo_status_unstaged" is-equal-to \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  new-len '1'  new-paths 'test.txt'  ren-len '0'  ren-paths ''

            command git commit -m 'test commit' > /dev/null 2>&1 || __fail "Couldn't create test commit"
            echo '$#/usr/bin/env zsh' > "$REPO/test.txt"

            safe_execute -x -r 0 fplib-git-details
            # TODO: We're, effectively, ignoring the git-rev value, so it should probably be checked later
            assert/association "git_property_map" is-equal-to \
                git-rev       "${git_property_map[git-rev]}"  has-commits   '1'      \
                has-remotes   'no'                            local-branch  'master' \
                nearest-root  "$REPO"                         remote-branch 'master'

            assert/association "repo_status_unstaged" is-equal-to \
                add-len   '0'        add-paths ''         \
                del-len   '0'        del-paths ''         \
                mod-len   '1'        mod-paths 'test.txt' \
                new-len   '0'        new-paths ''         \
                ren-len   '0'        ren-paths ''

            assert/association "repo_status_unstaged" is-equal-to \
                add-len   '0'        add-paths ''         \
                del-len   '0'        del-paths ''         \
                mod-len   '0'        mod-paths ''         \
                new-len   '1'        new-paths 'test.txt' \
                ren-len   '0'        ren-paths ''

            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 fplib-git-details
                assert/association "git_property_map" is-equal-to    \
                    git-rev       'detached'  has-commits   '0'      \
                    has-remotes   'no'        local-branch  'master' \
                    nearest-root  "$REPO_ALT"     remote-branch ''
            } always { popd }


        } always { popd }
    }
} always { (( IS_DIRTY == 0 )) || cleanup 'success' }

