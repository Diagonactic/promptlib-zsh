#!/bin/zsh
declare -g SCRIPT_PATH="${${(%):-%x}:A}"
declare -g PROJECT_DIR="${SCRIPT_PATH:h:h:h}"
declare -g SCRIPT_DIR="${SCRIPT_PATH:h}"
clear

source ../test.zsh
source "../../modules/git.zsh"

declare -g REPO{,_ALT,_REMOTE{,_ALT}}='';

# Create test repositories
pushdie() { pushd "$1" 2>/dev/null || __fail "Failed to change directory to $1" }

reset_test_repos() {
    reset-repo() {
        [[ -n "$1" ]] || return 1

        if [[ -n "$1" && -d "$1" && "$1" == /tmp* ]]; then
            rm -rf "$1/*" "$1/.*" || __fail "Falied to clear repository at: '$1'"
            __info "Test repository $1 was reset/removed"
            return 0
        fi
        __fail "Failed to clean repository at '$1' - it didn't exist or its name was possibly unsafe"
    }
    if [[ -z "$REPO" && -z "$REPO_ALT" && -z "$REPO_REMOTE" ]]; then return 0; fi
    __info "Resetting remote repositories"
    for REPONM in REPO{,_ALT,_REMOTE{,_ALT}}; do reset-repo "${(P)REPONM}" && typeset -g "$REPONM"=''; done
 }

init-repository() {
    [[ -d "$1" ]] || __fail "Function $0: The first parameter must be the path to the git repository"
    local TARGET_PATH="$1"; shift
    safe_execute -xr 0 -p "$TARGET_PATH" -- \git init -q "$@"
}

create_test_repos() {
    __info "Creating test repositories"
    reset_test_repos
    make-temp-repo() {
        2="${(P)1}"
        if [[ -n "$2" ]]; then
            __fail "Unexpected repository configured for $1 - $2"
        fi
        2="$(mktemp -d)" || __fail "Failed to create temporary directory for $1"
        local -a cmd=( init-repository "$2" ); [[ "$1" != *'_REMOTE' ]] || cmd+=( '--bare' )
        {
            "${cmd[@]}"
        } always { (( TRY_BLOCK_ERROR == 0 )) || reset_test_repos }
        declare -g "$1"="$2"
        __info "Created $1 repository at $2"
    }
    local REPONM=''
    {
        IS_DIRTY=1
        for REPONM in REPO{,_ALT,_REMOTE{,_ALT}}; do make-temp-repo "$REPONM"; done
    } always { (( TRY_BLOCK_ERROR == 0 )) || reset_test_repos }
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
wrap-repo-details() safe_execute -x -r 0 repo-details
wait_key() { print '... stopping ...'; read -k1 -s }
check-repo-props() {
    safe_execute -xr 0 -- repo-details
    assert/association git_property_map is-equal-to git-rev "${git_property_map[git-rev]}" nearest-root "$PWD" has-remotes yes has-commits 1 local-branch "${1:-master}" remote-branch "origin/${1:-master}" ahead-by "${2:-0}" behind-by "${3:-0}"
}
assert/repo-status() {
    safe_execute -xr 0 -- repo-details
    (( $# > 1 )) || __fail "$0: Invalid Usage - Requires an even number of properties"
    local TGT="$1"; shift

    (( $# % 2 == 0 )) || __fail "$0: Invalid Usage - Requires an even number of properties"
    safe_execute -xr 0 -- repo-details
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
    safe_execute -xr 0 -- repo-details
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
        (unstaged)  assert/association repo_status_unstaged "$@" new-len 0 new-paths '' ;;
        (staged)    assert/association repo_status_staged   is-equal-to add-len 0 add-paths '' del-len 0 del-paths '' mod-len 0 mod-paths '' ren-len 0 ren-paths '' ;;
        (both)      assert/clean-status staged && assert/clean-status unstaged ;;
        (*)         __fail "Unknown repo type: ${1:-both}"
    esac
}
wait4it() {
    print "Waiting for input: "
    print "REPO              : $REPO\nREPO_ALT          : $REPO_ALT\nREPO_REMOTE       : $REPO_REMOTE\nCurrent Directory : $PWD"
    read -k1 -s
}
set-remote() {
    pushd "${1:-$REPO}"
    {
        safe_execute -xr 0 -- \git remote add origin "${3:-$REPO_REMOTE}" > /dev/null 2>&1
        safe_execute -xr 0 -- \git push -q --set-upstream origin "${2:-master}"
        safe_execute -xr 0 -- \git branch --set-upstream-to=origin/"${2:-master}" "${2:-master}"
    } always { popd }
}
# Create test repositories in /tmp

IS_DIRTY=1
alias clean-conditional='(( IS_DIRTY == 0 )) && print -- "clean " || cleanup "success"'

unit_group "submodules" "Repo with remote and submodules"  test_sections {
    create_test_repos
    {
        # Stand up root repo
        pushd "$REPO"
        {
            repo-details:locals
            safe_execute -xr 0 -- \git checkout -q -b develop
            echo "foo" > "root-module.txt"
            safe_execute -xr 0 -- \git add .
            safe_execute -xr 0 -- \git commit -m 'Create root repository with single root-module.txt file'
            set-remote "$REPO" develop
            safe_execute -xr 0 -- repo-details
            assert/clean-status staged
            assert/clean-status unstaged
            assert/property-map local-branch develop remote-branch origin/develop
            safe_execute -xr 0 -- git push -q --set-upstream origin develop
        } always { popd }
        pushd "$REPO_ALT"
        {
            repo-details:locals
            safe_execute -xr 0 -- \git checkout -q -b develop
            echo "bar" > "sub-module.txt"
            safe_execute -xr 0 -- \git add .
            safe_execute -xr 0 -- \git commit -m 'Create submodule repository with single sub-module.txt file'
            set-remote "$REPO_ALT" develop "$REPO_REMOTE_ALT"
            safe_execute -xr 0 -- repo-details
            assert/clean-status staged
            assert/clean-status unstaged
            assert/property-map local-branch develop has-remotes yes remote-branch origin/develop
            safe_execute -xr 0 -- git push -q --set-upstream origin develop
        } always { popd }

        pushd "$REPO"
        {
            repo-details:locals
            safe_execute -xr 0 -- repo-details
            safe_execute -xr 0 -- \git submodule add -q -b develop "$REPO_REMOTE_ALT"
            safe_execute -xr 0 -- \git add .gitmodules
            safe_execute -xr 0 -- \git commit -m 'Add .gitmodules'
            safe_execute -xr 0 -- \git push -q --set-upstream origin develop
            safe_execute -xr 0 -- \git submodule update -q --init --recursive --remote
        } always { popd }
    } always { reset_test_repos }
}

unit_group "empty-no-remote" "Check empty, but valid, git repostiory properties - no remote" test_sections {
    create_test_repos
    {
        pushdie "$REPO"
        {
            repo-details:locals
            assert/property-map git-rev detached has-commits 0 has-remotes no
            assert/clean-status staged
            assert/clean-status unstaged
            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 repo-details
                assert/property-map git-rev detached has-commits 0 has-remotes no
            } always { popd }
        } always { popd }
    } always { reset_test_repos }
}
unit_group "empty-no-remote-add" "Git repo, one added file through to commit" test_sections {
    create_test_repos
    {
        pushdie "$REPO"
        {
            safe_execute -x -r 0 \git checkout -q -b master
            touch "$REPO/test.txt"
            repo-details:locals
            assert/property-map git-rev detached has-commits 0 has-remotes no
            assert/clean-status staged
            assert/repo-status unstaged new-len 1 new-paths test.txt

            safe_execute -xr 0 -- \git add .
            assert/property-map git-rev detached has-commits 0 has-remotes no
            assert/clean-status unstaged
            assert/repo-status staged add-len 1 add-paths test.txt

            safe_execute -xr 0 -- \git commit -m '.'
            assert/property-map has-remotes no
            assert/clean-status
            print -- '$#/usr/bin/env zsh' > test.txt
            assert/property-map has-remotes no
            assert/clean-status staged && assert/repo-status unstaged mod-len 1 mod-paths 'test.txt'

            safe_execute -xr 0 -- \git remote add origin "$REPO_REMOTE" > /dev/null 2>&1
            safe_execute -xr 0 -- \git push -q origin master
            safe_execute -xr 0 -- \git branch --set-upstream-to=origin/master master
            safe_execute -xr 0 -- \git commit -a -m .
            assert/property-map has-remotes yes ahead-by 1
            assert/clean-status
        } always { popd }
    } always { reset_test_repos }
}

unit_group "empty-no-remote-add" "Git repositories with one added file" test_sections {
    create_test_repos
    {
        pushd "$REPO"
        {
            touch "$REPO/test.txt"
            repo-details:locals
            wrap-repo-details
            assert/property-map git-rev detached has-remotes no has-commits 0
            assert/clean-status staged
            assert/repo-status unstaged new-paths test.txt new-len 1

            safe_execute -xr 0 -- \git add "$REPO/test.txt"
            assert/repo-status staged add-paths test.txt add-len 1
            safe_execute -xr 0 -- \git fetch -q -a
            safe_execute -xr 0 -- repo-details
            assert/property-map has-commits 0 git-rev detached has-remotes no

            echo 'blah' > baz.txt
            safe_execute -xr 0 -- \git add baz.txt
            assert/repo-status staged add-paths 'baz.txt:test.txt' add-len 2
            safe_execute -xr 0 -- \git commit -m 'baz.txt'
            assert/property-map has-commits 1 has-remotes no
            safe_execute -xr 0 -- repo-details

            assert/property-map has-remotes no

            wrap-repo-details
            assert/clean-status

            assert/association "repo_status_unstaged" is-equal-to \
                add-len   '0' add-paths ''                        \
                del-len   '0' del-paths ''                        \
                mod-len   '0' mod-paths ''                        \
                new-len   '0' new-paths ''                        \
                ren-len   '0' ren-paths ''


            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 repo-details
                assert/property-map has-remotes no has-commits 0
                assert/clean-status both
            } always { popd }
        } always { popd }
    } always { reset_test_repos }
}

unit_group "remote-ahead-behind" "Two repositories, various ahead/behind"  test_sections {
    create_test_repos
    {
        pushdie "$REPO"
        {
            safe_execute -x -r 0 \git checkout -q -b master
            touch test.txt
            repo-details:locals

            print -- '$#/usr/bin/env zsh' > test.txt
            safe_execute -xr 0 -- \git remote add origin "$REPO_REMOTE"
            safe_execute -xr 0 -- \git add .
            safe_execute -xr 0 -- \git commit -m 'Two repositories, various ahead/behind - first commit'
            safe_execute -xr 0 -- \git push -q --set-upstream origin master
            safe_execute -xr 0 -- \git branch -q --set-upstream-to=origin/master master

            pushd "$REPO_ALT"
            {
                safe_execute -x -r 0 repo-details
                assert/property-map git-rev detached has-remotes no has-commits 0
                safe_execute -x -r 0 -- \git checkout --no-progress -qfB master
                assert/property-map git-rev detached has-commits 0 has-remotes no
                assert/clean-status

                safe_execute -xr 0 -- \git remote add origin "$REPO_REMOTE" > /dev/null 2>&1
                safe_execute -xr 0 -- \git checkout -q -b master;
                safe_execute -xr 0 -- \git pull -q origin master
                safe_execute -xr 0 -- \git branch --set-upstream-to=origin/master master
                safe_execute -xr 0 \git fetch -q
                safe_execute -xr 0 repo-details

                assert/property-map ahead-by 0 behind-by 0
                assert/clean-status

                safe_execute -xr 0 -- add-commit boo.txt
                safe_execute -xr 0 -- repo-details
                assert/property-map ahead-by 1
            } always { popd }

            echo 'blah' > bar.txt
            safe_execute -xr 0 -- \git add .
            safe_execute -xr 0 -- \git commit -m 'bar.txt'
            safe_execute -xr 0 -- \git push -q

            pushd "$REPO_ALT"
            {
                safe_execute -xr 0 -- \git fetch -q
                safe_execute -xr 0 -- repo-details
                assert/property-map ahead-by 1 behind-by 1

                safe_execute -xr 0 -- \git pull -q
                safe_execute -xr 0 -- repo-details
                assert/property-map ahead-by 2 behind-by 0

                safe_execute -xr 0 -- \git push -q
            } always { popd }
        } always { popd }
    } always { reset_test_repos }
}
