#!/bin/zsh
clear
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
        __fail "Failed to clean repository at '$1' - it didn't exist or its name was possibly unsafe"
    }
    reset-repo "$REPO" && unset REPO
    reset-repo "$REPO_ALT" && unset REPO_ALT
}
create_test_repos() {
    [[ -n "$REPO_ALT" ]] || { typeset -g REPO_ALT='' && REPO_ALT="$(mktemp -d)" || die "Failed to create temporary directory for REPO_ALT" }
    [[ -n "$REPO" ]] || { typeset -g REPO='' && REPO="$(mktemp -d)" || die "Failed to create temporary directory for REPO" }
    [[ -n "$REPO_REMOTE" ]] || { typeset -g REPO_REMOTE='' && REPO_REMOTE="$(mktemp -d)" || die "Failed to create temporary directory for REPO_REMOTE" }
    pushd "$REPO_ALT"
    {
        safe_execute -xr 0 command git init > /dev/null 2>&1
    } always { popd }
    pushd "$REPO"
    {
        safe_execute -xr 0 command git init -q
    } always { popd }
    pushd "$REPO_REMOTE"
    {
        safe_execute -xr 0 command git init -q --bare
    } always { popd }
}
yes_no() {
    print_value "$1" "${${${(M)2:#1}:+yes}:-no}"
}
print_value() {
    print -- "${(r.20.)1}: '$2'"
}
print_values() {
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
add-commit() {
    (( $# == 0 )) || { print -- "serenity-now-$RANDOM" >> "$1" || return 1 }
    git add . && git commit -m '.'
}
check_temp() { [[ -n "$1" && -d "$1" ]]; }
wrap-fplib-git-details() safe_execute -x -r 0 repo-details
wait_key() { print '... stopping ...'; read -k1 -s }
check-repo-props() {
    safe_execute -xr 0 -- fplib-git-details
    assert/association git_property_map is-equal-to git-rev "${git_property_map[git-rev]}" nearest-root "$PWD" has-remotes yes has-commits 1 local-branch "${1:-master}" remote-branch "origin/${1:-master}" ahead-by "${2:-0}" behind-by "${3:-0}"
}
assert/repo-status() {
    safe_execute -xr 0 -- fplib-git-details
    (( $# > 1 )) || __fail "$0: Invalid Usage - Requires an even number of properties"
    local TGT="$1"; shift

    (( $# % 2 == 0 )) || __fail "$0: Invalid Usage - Requires an even number of properties"
    safe_execute -xr 0 -- fplib-git-details
    {
        local -A provided_props=( "$@" ) expected_props=( add-len 0 add-paths '' del-len 0 del-paths '' mod-len 0 mod-paths '' ren-len 0 ren-paths '' )
        [[ "$TGT" == staged ]] || expected_props+=( new-len 0 new-paths '' )
        local __; for __ in "${(k)provided_props[@]}"; do expected_props[$__]="${provided_props[$__]}"; done

        case "$TGT" in
            (staged)    assert/association repo_status_staged   is-equal-to "${(kv)expected_props[@]}"  ;;
            (unstaged)  assert/association repo_status_unstaged is-equal-to "${(kv)expected_props[@]}"  ;;
        esac
    } always { assert/return "$0" 0 }
}
assert/property-map() {
    (( $# % 2 == 0 )) || __fail "$0: Invalid Usage - Requires an even number of properties"
    safe_execute -xr 0 -- fplib-git-details
    {
        local -A provided_props=( "$@" ) expected_props=(
                git-rev      "${git_property_map[git-rev]}"  nearest-root  "$PWD"
                has-remotes  yes                             has-commits   1
                local-branch master                          remote-branch origin/master
                ahead-by     0                               behind-by     0
            )
        local __; for __ in "${(k)provided_props[@]}"; do expected_props[$__]="${provided_props[$__]}"; done
        [[ "${expected_props[has-remotes]}" == "yes" ]] || expected_props[remote-branch]=''
        assert/association git_property_map is-equal-to "${(kv)expected_props[@]}"
    } always { assert/return 'assert/property-map' 0 }
}

assert/clean-status() {
    case "${1:-both}" in
        (unstaged|both)  assert/association repo_status_unstaged is-equal-to add-len 0 add-paths '' del-len 0 del-paths '' mod-len 0 mod-paths '' ren-len 0 ren-paths '' new-len 0 new-paths '' ;|
        (staged|both)    assert/association repo_status_staged is-equal-to add-len 0 add-paths '' del-len 0 del-paths '' mod-len 0 mod-paths '' ren-len 0 ren-paths '' ;;
    esac
}

# Create test repositories in /tmp
declare -g REPO{_ALT,_REMOTE}='';
REPO_REMOTE="$(mktemp -d)" || { __fail "Failed to create temporary directory" }
IS_DIRTY=1
create_test_repos
if ! check_temp "$REPO" || ! check_temp "$REPO_ALT"; then __fail "Failed to create temporary directory"; fi
{

    unit_group "empty-no-remote" "Check empty, but valid, git repostiory properties - no remote" test_sections {
        pushd "$REPO"
        {
            repo-details:locals
            safe_execute -x -r 0 repo-details

            assert/association "git_property_map" is-equal-to    \
                git-rev       'detached'  has-commits   '0'      \
                has-remotes   'no'        local-branch  'master' \
                nearest-root  "$REPO"     remote-branch ''
            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 repo-details
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
            safe_execute -x -r 0 command git checkout -q -b master
            touch "$REPO/test.txt"
            repo-details:locals
            wrap-fplib-git-details
            assert/association "git_property_map" is-equal-to    \
                git-rev       'detached'  has-commits   '0'  has-remotes   'no'  local-branch  'master'  nearest-root "$REPO"  remote-branch ''

            assert/association "repo_status_staged" is-equal-to \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  ren-len '0'  ren-paths ''
            assert/association "repo_status_unstaged" is-equal-to \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  new-len '1'  new-paths 'test.txt'  ren-len '0'  ren-paths ''

            safe_execute -x -r 0 command git add "$REPO/test.txt"                     || __fail "Couldn't git add test.txt"
            assert/property-map git-rev detached has-commits 0 has-remotes no
            assert/repo-status staged add-len 1 add-paths 'test.txt'
            assert/clean-status unstaged

            safe_execute -xr 0 -- add-commit test.txt
            refresh-git-details
            assert/clean-status staged && assert/clean-status unstaged

            print -- '$#/usr/bin/env zsh' > test.txt

            safe_execute -x -r 0 repo-details
            # TODO: We're, effectively, ignoring the git-rev value, so it should probably be checked later

            assert/association "repo_status_staged" is-equal-to \
                add-len   '0' add-paths ''  \
                del-len   '0' del-paths ''  \
                mod-len   '0' mod-paths ''  \
                ren-len   '0' ren-paths ''

            assert/association "repo_status_unstaged" is-equal-to \
                add-len   '0'        add-paths ''         \
                del-len   '0'        del-paths ''         \
                mod-len   '1'        mod-paths 'test.txt' \
                new-len   '0'        new-paths ''         \
                ren-len   '0'        ren-paths ''

            safe_execute -xr 0 command git remote add origin "$REPO_REMOTE" > /dev/null 2>&1
            safe_execute -xr 0 command git push -q origin master
            safe_execute -xr 0 command git branch --set-upstream-to=origin/master master

            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 repo-details
                assert/association "git_property_map" is-equal-to    \
                    git-rev       'detached'  has-commits   '0'      \
                    has-remotes   'no'        local-branch  'master' \
                    nearest-root  "$REPO_ALT"     remote-branch ''
                safe_execute -x -r 0 -- command git checkout --no-progress -qfB master
                safe_execute -x -r 0 -- fplib-git-details
                assert/association "git_property_map" is-equal-to            \
                    git-rev       'detached'          has-commits   '0'      \
                    has-remotes   'no'                local-branch  'master' \
                    nearest-root  "$REPO_ALT"         remote-branch ''       \
                    ahead-by      0                   behind-by     0

                assert/association "repo_status_unstaged" is-equal-to \
                    add-len   '0'        add-paths ''   \
                    del-len   '0'        del-paths ''   \
                    mod-len   '0'        mod-paths ''   \
                    new-len   '0'        new-paths ''   \
                    ren-len   '0'        ren-paths ''

                safe_execute -xr 0 -- command git remote add origin "$REPO_REMOTE" > /dev/null 2>&1
                safe_execute -xr 0 -- command git checkout -q -b master;
                safe_execute -xr 0 -- command git pull -q origin master
                safe_execute -xr 0 -- command git branch --set-upstream-to=origin/master master

                safe_execute -x -r 0 command git fetch -q
                safe_execute -x -r 0 fplib-git-details
                assert/association "git_property_map" is-equal-to \
                    git-rev       "${git_property_map[git-rev]}" has-commits   1              \
                    has-remotes   yes                            local-branch  master         \
                    nearest-root  "$REPO_ALT"                    remote-branch origin/master  \
                    ahead-by      0                              behind-by     0

                assert/association "repo_status_unstaged" is-equal-to \
                    add-len   '0'        add-paths ''   \
                    del-len   '0'        del-paths ''   \
                    mod-len   '0'        mod-paths ''   \
                    new-len   '0'        new-paths ''   \
                    ren-len   '0'        ren-paths ''

                safe_execute -xr 0 -- add-commit boo.txt
                safe_execute -xr 0 -- fplib-git-details

                assert/association "git_property_map" is-equal-to \
                    git-rev       "${git_property_map[git-rev]}" has-commits   1              \
                    has-remotes   yes                            local-branch  master         \
                    nearest-root  "$REPO_ALT"                    remote-branch origin/master  \
                    ahead-by      1                              behind-by     0

                #read -k1 -s
            } always { popd }

            echo 'blah' > bar.txt
            safe_execute -xr 0 -- command git add .
            safe_execute -xr 0 -- command git commit -m 'bar.txt'
            safe_execute -xr 0 -- command git push -q

            pushd "$REPO_ALT"
            {
                safe_execute -xr 0 -- command git fetch -q
                safe_execute -x -r 0 -- fplib-git-details
                assert/association "git_property_map" is-equal-to \
                    git-rev       "${git_property_map[git-rev]}" has-commits   1              \
                    has-remotes   yes                            local-branch  master         \
                    nearest-root  "$REPO_ALT"                    remote-branch origin/master  \
                    ahead-by      1                              behind-by     1

                safe_execute -xr 0 -- command git pull -q
                safe_execute -xr 0 -- fplib-git-details

                assert/association "git_property_map" is-equal-to git-rev "${git_property_map[git-rev]}" nearest-root "$PWD" has-remotes yes has-commits 1 \
                    local-branch master     remote-branch origin/master     ahead-by 2 behind-by 0

                safe_execute -xr 0 -- command git push -q
            } always { popd }
        } always { popd }
    }

    unit_group "empty-no-remote-add" "Git repositories with one added file" test_sections {
        pushd "$REPO"
        {
            touch "$REPO/test.txt"
            repo-details:locals
            wrap-fplib-git-details
            assert/association "git_property_map" is-equal-to     \
                git-rev       'detached'  has-commits   '0'  has-remotes   'no'  local-branch  'master'  nearest-root "$REPO"  remote-branch ''

            assert/association "repo_status_staged" is-equal-to   \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  ren-len '0'  ren-paths ''
            assert/association "repo_status_unstaged" is-equal-to \
                add-len '0'  add-paths ''  del-len '0'  del-paths ''  mod-len '0'  mod-paths ''  new-len '1'  new-paths 'test.txt'  ren-len '0'  ren-paths ''

            \git add "$REPO/test.txt"                     || __fail "Couldn't git add test.txt"
            safe_execute -xr 0 -- command git fetch -q -a
            safe_execute -xr 0 -- fplib-git-details
            assert/association "git_property_map" is-equal-to git-rev "${git_property_map[git-rev]}" nearest-root "$PWD" has-remotes yes has-commits 1 \
                local-branch master     remote-branch origin/master     ahead-by 0 behind-by 2
            echo 'blah' > baz.txt
            safe_execute -xr 0 -- add-commit
            safe_execute -xr 0 -- fplib-git-details
            assert/association "git_property_map" is-equal-to git-rev "${git_property_map[git-rev]}" nearest-root "$PWD" has-remotes yes has-commits 1 \
                local-branch master     remote-branch origin/master     ahead-by 1 behind-by 2

            wrap-fplib-git-details
            assert/association "repo_status_staged" is-equal-to \
                add-len   '1'        add-paths 'test.txt'       \
                del-len   '0'        del-paths ''               \
                mod-len   '0'        mod-paths ''               \
                ren-len   '0'        ren-paths ''

            assert/association "repo_status_unstaged" is-equal-to \
                add-len   '0' add-paths ''                        \
                del-len   '0' del-paths ''                        \
                mod-len   '0' mod-paths ''                        \
                new-len   '0' new-paths ''                        \
                ren-len   '0' ren-paths ''

            \git commit -m 'test commit' > /dev/null 2>&1 || __fail "Couldn't create test commit"

            echo '$#/usr/bin/env zsh' > "$REPO/test.txt"

            safe_execute -x -r 0 repo-details
            # TODO: We're, effectively, ignoring the git-rev value, so it should probably be checked later
            assert/association "git_property_map" is-equal-to \
                git-rev       "${git_property_map[git-rev]}"  has-commits   '1'      \
                has-remotes   'no'                            local-branch  'master' \
                nearest-root  "$REPO"                         remote-branch 'master'

            assert/association "repo_status_staged" is-equal-to \
                add-len   '0' add-paths ''  \
                del-len   '0' del-paths ''  \
                mod-len   '0' mod-paths ''  \
                ren-len   '0' ren-paths ''

            assert/association "repo_status_unstaged" is-equal-to \
                add-len   '0'        add-paths ''         \
                del-len   '0'        del-paths ''         \
                mod-len   '1'        mod-paths 'test.txt' \
                new-len   '0'        new-paths ''         \
                ren-len   '0'        ren-paths ''

            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 repo-details
                assert/association "git_property_map" is-equal-to    \
                    git-rev       'detached'  has-commits   '0'      \
                    has-remotes   'no'        local-branch  'master' \
                    nearest-root  "$REPO_ALT"     remote-branch ''
            } always { popd }
        } always { popd }
    }
} always { (( IS_DIRTY == 0 )) && print -- 'clean ' || cleanup 'success' }

