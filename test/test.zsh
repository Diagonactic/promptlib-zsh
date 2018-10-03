#!/bin/zsh
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
# test.zsh
# ----------------------------------------------------------------------------------------------------------: Description :
#   A naive helper script to facilitate component testing
# --------------------------------------------------------------------------------------------------------------: License :
# Copyright 2018 Matthew S. Dippel
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# *-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
___test_arg="$1"
__ut/escape_ans() { set +x
    print -r -- "${${1//$'\e'/\\e}//$'\n'/\\n}";
}
__ut/fail_diff_string() {

    local ACTUAL="`__ut/escape_ans "$1"`"
    local EXPECTED="`__ut/escape_ans "$2"`"
    set +x
    peno() print -n -- $'\e[0m\e[1;91m'"$1"
    pgno() print -n -- $'\e[0m\e[1;97m'"$1"
    pe() print -- $'\e[0m\e[1;91m\t\t'"$1""$CLR_RST"
    pg() print -- $'\e[0m\e[1;92m\t\t'"$1""$CLR_RST"

    __print_fail $'Expected string did not match\n'
    (( ${#EXPECTED} != 0 )) || pe $'String was expected to be empty'
    if (( ${#ACTUAL} == 0 )); then
        pe $'String was not expected to be empty'
    else
        (( ${#ACTUAL} != ${#EXPECTED} )) && pe $'Length was '${#ACTUAL}'; expected '${#EXPECTED}$'\n' || pg $'Length was '${#EXPECTED}
    fi

    local -i i=0
    (( ${#ACTUAL} > ${#EXPECTED} )) && local -ir len="${#EXPECTED}" || local -ir len="${#ACTUAL}"
    peno "\t\tActual:   "$'\e[0;37m'"'"
    for i in {0..${#ACTUAL}}; do
        (( i <= ${#EXPECTED} )) && {
            [[ "${ACTUAL:$i:1}" == "${EXPECTED:$i:1}" ]] && pgno "${ACTUAL:$i:1}" || peno "${ACTUAL:$i:1}"
        } || pgno "${ACTUAL:$i:1}"
    done
    print $'\e[0;37m'"'"
    pgno "\t\tExpected: "$'\e[0;37m'"'"

    for i in {0..${#EXPECTED}}; do
        (( i <= ${#ACTUAL} )) && {
            [[ "${ACTUAL:$i:1}" == "${EXPECTED:$i:1}" ]] && pgno "${EXPECTED:$i:1}" || peno "${EXPECTED:$i:1}"
        } || pgno "${EXPECTED:$i:1}"
    done

    print $'\e[0;37m'"'"
    exit 1
}
function __ut/parameter/is_defined,{is_basetype{,_or_unset}/{scalar,array,integer,float,association}} {
    local -ar fn=( "${(@s./.)0}" ); local FN="${${fn[3]}%%_or_unset}"
    [[ -n "$1" ]] || return 126
    case "$FN" in
        (*)             typeset -p "$1" > /dev/null 2>&1 || { [[ "$0" == *_or_unset* ]]; return $?; }
         ;|
        (is_defined)    return 0                                    ;;
        (is_basetype)   [[ "${fn[4]}" == "${${(t)${(P)1}}%%-*}" ]]  ;;
    esac
}

__ut/ans() > /dev/tty { set +x
    __echo() {
        if   [[ "$1" =~ '^([0-9]+;)?[0-9]+$' ]];  then 1=$'\e'"[$1m"
        elif [[ "$1" =~ '^([0-9]+;)?[0-9]+m$' ]]; then 1=$'\e'"[$1";   fi
        print -n -- "$1$2"
    }
    while (( $# > 0 )); do
        (( $# > 1 )) || { print -n -- $'\e[1;37m'"$1"; break; }
        __echo "$1" "$2"
        shift 2
    done

}
__ut/hr() {
    printf -v _hr "%*s" $COLUMNS && print -n -- "\n\e[0;37m${_hr// /━}" && print -- "\r\e[2C\e[1;97m ::: \e[0;90m[ \e[0;37m$1 ] \e[1;97m ::: \n"
}
__ut/die_usage() {
    1="${1-1}"
    [[ "$1" =~ "^[0-9]+$" ]] && { stack_rewind="$1"; shift } || stack_rewind="$1"
    local stack_rewind="${1:-1}"
    local _hr=''; printf -v _hr "%*s" $COLUMNS && print -n -- "\n\e[0;37m${_hr// /━}" && print -- "\r\e[2C\e[1;97m ::: \e[0;90m[ \e[0;37mUsage Error ] \e[1;97m ::: \n"
    print -- "\e[0;31m'${funcstack[stack_rewind]}': \e[1;91mERROR: \e[1;37m$1'"
    printf -v _hr "%*s" $COLUMNS && print -n -- "\n\e[0;37m${_hr// /━}" && print -- "\r\e[2C\e[1;97m ::: \e[0;90m[ \e[0;37mUsage Error ] \e[1;97m ::: \n"
}
__ut/clr() {
    local color="37" attr="$1" message="${3-$2}"
    (( $# > 1 )) || __ut/die_usage "2 parameters required"
    if (( $# > 2 )); then color="$2"; fi
    [[ "$attr" =~ "^[0-9]$" ]] || color=0
    if [[ "$color" =~ "^[0-9][0-9]m$" ]]; then
        color="${color:0:2}"
    else
        if [[ "$color" =~ "^[0-9]+$" ]]; then
            if [[ "$color" =~ "^[0-9]$" ]]; then color="3${color}"; fi
        else
            color="37"
        fi
    fi

    printf "\e[%d;%dm%s\e[0;37m"  "$attr" "$color" "$message"
}
__ul() { [[ $# -lt 1 ]] && { echo "${funcstack[1]} error - needs one parameter" && exit 1 } || __ut/clr 4 $@; }
__b() {
    [[ $# -lt 1 ]] && { ecoh "${funcstack[1]} error - needs one parameter" && exit 1 } || {
        [[ "${#2}" -gt 1 ]] && __ut/clr 1 $@ || __ut/clr 1 "9$2"
    }
}
__successmark() {
    __ut/ans "1;92" "    ✓ " "1;32" "Success" "0;32" " - "
}
__success() {
    __successmark && __ut/ans "1;37" "$1\n"
}
__failmark() {
    __ut/ans "1;91" "    ꕔ " "1;31" "Failure" "0;31" " - "
}
__print_fail() {
    __failmark
    if [[ $# -eq 2 ]]; then
        __ut/ans "1;37" "Expected '" "4;32" "$1" "1;37" "'; got '" "4;31" "$2" "1;37" "'"
    elif [[ $# -eq 3 ]]; then
        __ut/ans "1;37" "Expected value of " "4;32" "$1" "1;37" " to be '" "4;32" "$2" "1;37" "'; got '" "4;31" "$3" "1;37" "'"
    else
        __ut/ans "1;37" "$1"
    fi
    __ut/ans "0;37" $'\n'
}
__fail() {
    __print_fail "$@"
    print
    exit 1
}
__dump_array_value() {
    local clr="$1"
    _b() echo -en "\e[1;9${clr}m$1"
    _u() echo -en "\e[4;9${clr}m$1"
    _n() echo -en "\e[0;3${clr}m$1"
    _b "      $2"; _n "='"; _u "$3"; _n "'\e[0;37m\e[0m\n"
}
__dump_array() {
    local -i color=$1; shift
    local -a ixs; ixs=( {1..$#} )
    printf "      \033[1;9${color}m%s\e[1;3${color}m=\e[4;9${color}m%s\e[0;3${color}m\n" "${ixs[@]:^argv}"
    #while [[ $# -ne 0 ]]; do
    #    __dump_array_value $color $i "$1"
    #    (( i++ )) && shift
    #done
}
__dump_assoc() {
    local -i color=$1; local varname="$2"; shift 2
    local -A assoc=( "${argv[@]}" )

    printf "      \033[1;9${color}m${varname}[%s]\e[1;3${color}m=\e[4;9${color}m%s\e[0;3${color}m\n" "${(kv)assoc[@]}"
}
assert_association_equal() {
    local association_name="$1"; shift
    local -A actual_values; actual_values=( "${(kvP@)association_name[@]}" )
    if (( $# == 0 && ${#${(kv)actual_values[@]}} == 0 )) ; then
        __success "Association '$association_name' was empty";
        return 0
    fi
    __assoc_fail() {
        __ut/ans "0;37" "    Expected Values:\n"
        __dump_assoc 7 $association_name "${(kv)expected_values[@]}"
        __ut/ans "0;31" "    Actual Values:\n"
        __dump_assoc 1 $association_name "${(kv)actual_values[@]}"
        exit 1
    }
    (( $# % 2 == 0 )) || __fail "Expected an even number of values after the association name"
    local -A expected_values; expected_values=( "$@" )
    (( ${#actual_values[@]} == ${#expected_values[@]} )) && {
        __success "$association_name has a length of ${#actual_values[@]}"

    } || {
        __failmark; __ut/ans "1;31" "$refvar" "0;31" " length was " "1;31" "${#actual_values[@]}" "0;31" "; expected " "1;31" "${#expected_values[@]}\n"
        __assoc_fail
    }
    local key=''
    for key in ${(k)expected_values[@]}; do
         (( ${+actual_values[$key]} == 1 )) || {
             __failmark; __ut/ans "1;31" "$association_name" "0;31" " is missing key " "1;31" "${key}\n"
             __assoc_fail
         }
    done
    __dump_assoc 2 "$association_name" "${(kv)actual_values[@]}"
}
function assert/{scalar,integer,float,array,association} {
    setopt localoptions extendedglob
    __test_fail() { __fail "Expected $2 of $1 to be '$3'; got '$4'"; }

    [[ "${0##*/}" == "${${(t)${(P)1}}%%-*}" ]] || {
        if [[ "${${(t)${(P)1}}%%-*}" == "array" && "${0##*/}" == "scalar" ]]; then
            if [[ "${#${(P@)1}}" != 1 ]]; then
                __test_fail "$1" "type" "${0##*/}" "${${(t)${(P)1}}%%-*}"
            fi
        else
            __test_fail "$1" "type" "${0##*/}" "${${(t)${(P)1}}%%-*}"
        fi
    }

    impl_association() {
        is_equal() {
            local ___association_name="$1"
            local -i ___has_failed=0
            shift
            if (( $# == 0 )); then
                (( ${(#@)${(kv)___actual_value[@]}} != 0 )) || { __success "Association '$___association_name' was empty"; return 0 }
                __print_fail "Expected '$___association_name' to be empty"
            elif (( $# == 1 )); then
                local -Ar ___expected_value=( "${(kvP@)1}" )

            elif (( $# > 1  )); then
                (( $# % 2 == 0 )) || __fail "Invalid association provided for 'expected' values"
                local -Ar ___expected_value=( "$@" )
            fi
            local ___MSG
            local -i ___expected_len=$(( ${#${(kv@)___expected_value[@]}} )) ___actual_len=$(( ${#${(kv@)___actual_value[@]}} ))
            if (( $# == 0 && ${#${(kv)___actual_value[@]}} == 0 )) ; then
                __success "Association '$___association_name' was empty";
                return 0
            fi
            shift

            local -a ___expected_keys=( "${(k@)___expected_value[@]}" ) ___actual_keys=( "${(k@)___actual_value[@]}" )

            if (( ___expected_len != ___actual_len )); then
                __print_fail "Length was expected to be $___expected_len but was actually $___actual_len"
                ___has_failed=1
            fi
            local ___KEY
            for ___KEY in ${___expected_keys[@]}; do
                if [[ -n "${___actual_keys[(r)$___KEY]}" ]]; then
                    if [[ "${___actual_value[$___KEY]}" == "${___expected_value[$___KEY]}" ]]; then
                        print -v ___MSG -- "${___MSG}"$'\t\t\e[1;92m['"$___KEY"']='"'${___actual_value[$___KEY]}'$CLR_RST"$'\n'
                    else
                        print -v ___MSG -- "${___MSG}"$'\t\t\e[1;91m['"$___KEY"']='"'${___actual_value[$___KEY]}'$CLR_RST"$' (Expected \e[0;37m'"'${___expected_value[$___KEY]}')"$CLR_RST$'\n'
                        ___has_failed=1
                    fi
                else
                    print $'\t\t\e[1;91m['"$___KEY"'] is missing (Expected \e[0;37m'"'${___expected_value[$___KEY]}')"$CLR_RST
                fi
            done
            for ___KEY in ${(k)___actual_value}; do
                if (( ${+___expected_value[$___KEY]} )); then continue; fi
                print $'\t\t\e[1;91m['"$___KEY"'] is unexpected (Value was \e[0;37m'"'${___actual_value[$___KEY]}')"$CLR_RST
                ___has_failed=1
            done
            if (( ___has_failed )); then
                __print_fail "Association '$___association_name' keys/values do not match:"
                print "$___MSG"
                __ut/clip/association/assertion -s -- "$___association_name"
                print -- $'\n\t\t\e[1;95mAn assertion statement that would pass has been copied to the clipboard\e[0;37m'
                exit 1
                exit 1;
            fi
            __success "Association is equal to expected keys/values"
        }
        local -A ___actual_value=( "${(kvP@)1}" )

        case "$2" in
            (is[-_]equal|is[-_]equal[-_]to) is_equal "$1" "${@:3}" ;;
            (is[-_]empty)                   is_equal "$1"      ;;
        esac
    }
    impl_array() {
        check/value_at_index_is_equal() {
            # 1:index 2:actual 3:expected
            (( $1 <= ${#${(@P)2}} )) || {
                print -v ___MSG -- "${___MSG}"$'\t\t\e[1;91m['"$1] - Unexpected end of $2 at index $1$CLR_RST"$'\n'
                return 1
            }
            (( $1 <= ${#${(@P)3}} )) || {
                print -v ___MSG -- "${___MSG}"$'\t\t\e[1;91m['"$1] - Expected $2 to end at index $1$CLR_RST"$'\n'
                return 1
            }
            if [[ "${${(@P)2}[$1]}" == "${${(@P)3}[$1]}" ]]; then
                print -v ___MSG -- "${___MSG}"$'\t\t\e[1;92m['"$1]='${${(@P)3}[$1]}'$CLR_RST"$'\n'
                return 0
            else
                print -v ___MSG -- "${___MSG}"$'\t\t\e[1;91m['"$___ix]='${${(@P)2}[$1]}'; "$'\e[0;37m'"Expected '${${(@P)3}[$1]}'"$'\n'
                return 1
            fi
        }

        is_equal() {
            local ___MSG=''
            local -a ___expected_value=( "${@:2}" )
            local -i ___expected_len=$(( ${#___expected_value[@]} )) ___actual_len=$(( ${#___actual_value[@]} )) ___ix=0 ___has_failed=0
            if (( ___expected_len == 0 && ___actual_len == 0 )); then
                __success "$1 is empty"
                return 0
            elif (( ___expected_len == 0 && ___actual_len != 0 )); then __fail "Expected $1 to be an empty array; got an array with a length of $___actual_len"
            elif (( ___expected_len != 0 && ___actual_len == 0 )); then __fail "Expected $1 to be an array with values; got an empty array"; fi

            (( $___expected_len == $___actual_len )) || {
                __print_fail "Expected length of $1 to be ${___expected_len}; got ${___actual_len}"
                has_failed=1
            }

            (( ___expected_len > ___actual_len )) && local -ir ___len="${___expected_len}" || local -ir ___len="${___actual_len}"

            for ___ix in {1..${___len}}; do
                check/value_at_index_is_equal $___ix "$1" ___expected_value || ___has_failed=1
            done

            (( ___has_failed  )) && { __print_fail "Expected value was not provided"; print -- "${___MSG}"; exit 1 } || __success "Value of $1 was equal to expected value" || __fail "Values are not equal"
        }
        local -a ___actual_value=( "${(@P)1}" )
        case "$2" in
            (is[-_]equal|is[-_]equal[-_]to) is_equal "$1" "${@:3}" ;;
            (is[-_]empty)                   is_equal "$1" ;;
        esac
    }
    impl_scalar() {
        is_equal() {
            local ___expected_value="$2"
            local -i ___expected_len="${#___expected_value}" ___actual_len="${#___actual_value}" ___ix=0 ___has_failed=0
            if (( ___expected_len == 0 && ___actual_len == 0 )); then
                __success "$1 is empty"
                return 0
            fi
            if [[ "${___expected_value}" == "${___actual_value}" ]]; then
                __success "Value was "$'\e[0;37m'"'"$'\e[1;37m'"${${___expected_value//$'\n'/\\\\n}//\\/\\\\}"$'\e[0;37m'"'"
                return 0
            else
                ( __ut/fail_diff_string "$___actual_value" "$___expected_value" )
                __ut/to_clip -s -- print -r -- "assert/scalar ${(q)1} is-equal-to $'`__ut/escape_ans "${___actual_value}"`'"
                print -- $'\n\t\t\e[1;95mAn assertion statement that would pass has been copied to the clipboard\e[0;37m'
                exit 1
            fi
        }
        local ___actual_value="${(P)1}"
        case "$2" in
            (is[-_]equal|is[-_]equal[-_]to) is_equal "$1" "${@:3}" ;;
            (is[-_]empty)                   is_equal "$1" "";;
            (*) __fail "Invalid assertion: $2"
        esac
    }

    "impl_${0##*/}" "$@"
}

__ut/center() {
    if (( $# == 1 )); then 2=' '; fi
    local -i LLEN=$(( ( COLUMNS + ${#1} ) / 2 ))
    local -i RLEN=$(( ( COLUMNS - ${#1} ) / 2 ))
    print "${(l.$LLEN..=.)1}${(r:$RLEN::=:)}"
}
alias __ut:switches='local {SWITCH_CONFIG,OPT,OPTARG}=""; local -i OPTIND=0; () { SWITCH_CONFIG="$1" }'
alias __ut:to_clip:switches='local -i SILENT=0; local {HEADING,BOT_HEADING}=""; local -a ___ut_new_args=( "$@" ); __ut/to_clip-switch_helper "$@"; argv=( "${___ut_new_args[@]}" )'
alias __ut:to_clip:noisy='() { if (( SILENT )); then return 0; fi; __ut/center "==== $HEADING ===="; "$@"; __ut/center "=== $BOT_HEADING ====" }'
__ut/to_clip-switch_helper() {
    __ut:switches sp:
    SILENT=0; HEADING="Clipping" BOT_HEADING="Text was copied to your clipboard"
    while getopts "${SWITCH_CONFIG}" OPT; do
        case "$OPT" in
            (s) SILENT=1 ;;
            (p) HEADING="$OPTARG" ;;
        esac
    done
    (( OPTIND > 1 )) && shift $(( OPTIND - 1 ))
    ___ut_new_args=( "$@" )
}
__ut/to_clip/scalar() {
    __ut:to_clip:switches
    print -n -- "${(F)@}" | xclip -in -selection clipboard
    __ut:to_clip:noisy print -- "${(F)@}"
}

__ut/to_clip() {
    __ut:to_clip:switches
    "$@" | xclip -in -selection clipboard
    __ut:to_clip:noisy "$@"
}
__ut/clip/association/assertion() {
    __ut:to_clip:switches
    get_stmt() {
        print "assert/association \"$1\" is-equal-to \\"
        shift

        if (( $# % 2 != 0 )); then print -- "Can't create assertion for $1!" > /dev/stderr; return 1; fi
        local -A assoc=( "$@" );
        local -a keys=( "${(q@)${(k@)assoc[@]}}" ) vals=( "${(qqv@)assoc[@]}" ) ordered_keys=( ${(ok@)assoc[@]} )

        local -ir kw="${#${(O@)keys//?/X}[1]}" vw="${#${(O@)vals//?/X}[1]}"
        local -i ct=1
        local pargs=( "-n" -- )
        local {KEY,PAD,ENDC}='';
        for KEY in "${ordered_keys[@]}"; do

            if (( ct % 2 == 0 )); then
                PAD=''; ENDC=$'\\\\\n'
            else
                PAD='            '; ENDC='';
            fi
            if (( ct == ${#keys[@]} )); then ENDC=$'\n'; fi
            set +x
            print ${pargs[@]} "$PAD${(r:$kw:: :)${(q)KEY}} ${(r:$vw:: :)${(qq)assoc[$KEY]}}$ENDC"
            (( ct++ ))
        done
    }
    local -a call_to_clip=( "__ut/to_clip" "-p" "Assertion for Association" -- get_stmt "$1" "${(kv@P)1}" )
    (( SILENT == 0)) || call_to_clip[2]="-sp"
    "${call_to_clip[@]}"
}


# __ut/clip/safe_execute/error ${command_with_parameters_to_run[@]}
# Example: __ut/clip/safe_execute/error test-provided-refvar array optional a foo -a 1
__ut/clip/safe_execute/error() {
    get_stmt() {
        safe_execute -r 1 -- "$@"
        local TXT="$1 ${(j: :)${(qq@)@:2}}"
        print -r -- "safe_execute -r 1 -e \$'`__ut/escape_ans "${std_err[1]}"`' \\"
        print -r -- "            -- $TXT"
    }
    __ut/to_clip -p "Error Assertion" -- get_stmt "$@"
}

assert_equal() {
    set +x
    local refvar="$1"; shift
    local -i i
    if (( $# > 1 )); then
        local org_refvar="$refvar"
        refvar+="[@]"
        local -a expected
        local -a actual
        local -i i=0
        actual=( "${${(P)refvar}}" )
        expected=( "$@" )
        if [[ ${#actual[@]} -eq ${#expected[@]} ]]; then
            __successmark
            __ut/ans "1;32" "$refvar length equals ${#expected[@]}\n"
        else
            __failmark
            __ut/ans "1;37" "$refvar" "0;37" " length was " "1;37" "${#actual[@]}" "0;37" "; expected " "1;37" "${#expected[@]}\n"
            __ut/ans "4;31" "Array '" "4;37" "${refvar}" "' contents:\n"
            __dump_array 1 ${actual[@]}
            __ut/ans "1;31" "Expected it to contain:\n"
            __dump_array 7 ${expected[@]}
            exit 1
        fi
        local -i j=0
        for (( i = 1; i <= ${#expected[@]}; i++ )); do
            [[ "${expected[$i]}" == "${actual[$i]}" ]] && {
                __successmark
                __dump_array_value 2 "${refvar/[@]/$i}" "${expected[$i]}"
            } || {
                __failmark
                __ut/ans "1;31" "$refvar does not contain " '0;31' "'" '4;31' "${expected[$i]}" '0;31' "'" '1;31' " at index $i (actual value at index was '${actual[$i]}')\n"
                __ut/ans "4;31" "Array '" "4;37" "${refvar}" "4;31" "' contents:\n"
                __dump_array 1 ${actual[@]}
                __ut/ans "1;31" "Expected it to contain:\n"
                __dump_array 7 "${expected[@]}"
                exit 1
            }
        done
        return 0
    fi
    local actual_value="${(P)refvar}"
    local expected_value="$1"
    [[ -z "$expected_value" && -z "$actual_value" ]] && { __successmark; __ut/ans "1;32" "$refvar was empty\n"; return 0 }
    [[ -n "$actual_value" && "${(P)refvar}" == "$expected_value" ]] && { __successmark; __ut/ans "1;32" "${refvar}='$expected_value'\n" } || {
        __fail "${refvar}" "$expected_value" "${actual_value}"
    }
}

assert_returncode() {
    set +x
    local calling="$1" && local -i expect="$2" && shift 2
    ( $calling $@ 2>&1 > /dev/null ) > /dev/null
    local result=$?
    if [[ "$result" -eq "$expect" ]]; then
        __success "Result of '\e[4;92m$result\e[0m\e[1;37m' received from \e[4;97m$calling\e[0m\e[1;37m with parameters: "
        __dump_array 2 $@
    else
        __failmark
        __ut/ans "0;31" "Result of \e[4;91m$calling\e[0;31m received from \e[4;97m$calling\e[0;31m with parameters: "
        __dump_array 2 $@
        __ut/ans "1;31" "                ... returned result " "1;37" "$result\n"
        exit 1
    fi
}

assert_returncode_and_equals() {
    set +x
    local calling="$1" expect_result="$3" && local -i expect="$2" && shift 3
    ( $calling $@ 2>&1 > /dev/null ) > /dev/null
    local result=$?
    if [[ "$result" -eq "$expect" ]]; then
        __success "Result of \e[4;92m$result\e[0m\e[1;37m received from \e[4;97m$calling\e[0m\e[1;37m with parameters: "
        __dump_array 2 $@
    else
        __failmark
        __ut/ans "0;31" "Result of \e[4;91m$result\e[0m\e[1;37m received from \e[4;97m$calling\e[0;31m with parameters: "
        __dump_array 2 $@
        exit 1
    fi
    val="`"$calling" $@`"

    if [[ -z "$expect_result" && -z "$val" ]]; then __success "$calling returned expected empty value"
    elif [[ "$expect_result" == "$val" ]]; then __success "$calling \e[0;37m printed '\e[4;32m$val\e[0;37m'"
    else __fail "$calling" "$expect_result" "$val"; fi
}

print_section() {
    set +x
    local _hr=''; printf -v _hr "%*s" $COLUMNS && print -n -- "\n\e[0;37m${_hr// /━}" && print -- "\r\e[2C\e[1;97m ::: \e[0;90m[ \e[0;37mTesting \e[4;97m$1\e[0;90m ] \e[1;97m ::: \n"
}
av=$'function {\n if (( $# != 0 )) && [[ ! "$1" =~ "^[0-9]+$" ]] && [[ "$1" != "${1:-_}" ]]; then return 0; fi () { print_section "${@:2:-1}\e[0;37m" } '
#alias test_section="$av"
alias test_section='function () { function { print_section "${@:1:-1}" }'

assert_nodiff() { set +x
    local first="$1" second="$2" cmd_output_file="$2"
    [[ "$1" =~ '^/tmp' ]] && { first="command output"; cmd_output_file="$2" } || first="$1"
    [[ "$2" =~ '^/tmp' ]] && second="command output" || second="$2"
    diff -q "$1" "$2" > /dev/null && __success "output of $first was identical to $second" || {
       diff --width="$COLUMNS" --color=always -y "$1" "$2"
       __ut/ans "1;91" "Result of command output\n"
       #cat "$cmd_output_file" | awk '/^# v|\^/ { print "\033[1;92m" $0 "\033[0;37m"; next } { print $0 }'
       #[[ "$first" == "command output" ]] && { cat "$1" } || { cat "$2" }
       __fail "output of $first was different than $second"
    }
}

assert_return() {
    local result=$?
    set +x # Don't move this above $? or return code won't be captured
    local -i expected="$2"
    local name="$1"
    (( result == expected )) \
        && __success "Expected result of \e[4;92m$result\e[0m\e[1;37m received from \e[4;97m$name\e[0m\e[1;37m" \
        || __fail "Expected result received from \e[4;97m$name\e[0m\e[1;37m to be '\e[4;37m$expected\e[0m\e[1;37m'; got '\e[1;91m$result\e[0m\e[1;37m'"
}

function safe_execute {
    local {OPT,OPTARG}

    local -a expected_stdout=( ) expected_stderr=( );

    function str/contains { [[ "${1%%${2-}*}" != "$1" ]]; }

    local -i {OPTIND,SKIP_SUBSHELL,NO_CLIP}=0 EXPECTED_RC=-1
    local REFVAR_FROM_CLI='' EXPECTED_REFVAR_VALUE='' RV_TYPE=''
    local -a typeset_refvar_from_cli=( "local" '' '' )

    while getopts xcr:o:e:v: OPT; do
        case "$OPT" in
            (r) EXPECTED_RC="$OPTARG" ;;
            (o) [[ "$OPTARG" == *$'\n'* ]] && expected_stdout=( "${(@f)OPTARG}" ) || expected_stdout=( "$OPTARG" ) ;;
            (e) [[ "$OPTARG" == *$'\n'* ]] && expected_stderr=( "${(@f)OPTARG}" ) || expected_stderr=( "$OPTARG" ) ;;
            (v) EXPECTED_REFVAR_VALUE="$OPTARG" ;;
            (x) SKIP_SUBSHELL=1 ;;
            (c) NO_CLIP=1
        esac
    done
    (( OPTIND > 1 )) && shift $(( OPTIND - 1 ))
    if (( ${argv[(i)-v]} <= ${#argv[@]} )); then
        REFVAR_FROM_CLI="${argv[$(( ${argv[(i)-v]}  + 1))]}"
        typeset_refvar_from_cli[3]="$REFVAR_FROM_CLI"
        typeset -p "$REFVAR_FROM_CLI" > /dev/null 2>&1 || typeset -g "$REFVAR_FROM_CLI"
        RV_TYPE="${${(t)${(P)REFVAR_FROM_CLI}}%%-*}"
        case "$RV_TYPE" in
            (association|array) typeset_refvar_from_cli=( "set" "-gA" "$REFVAR_FROM_CLI" ) ;;
            (integer) typeset_refvar_from_cli[2]="-i" ;;
            (float) typeset_refvar_from_cli[2]="-F" ;;
        esac
    fi
    if [[ -n "$EXPECTED_REFVAR_VALUE" && -z "$REFVAR_FROM_CLI" ]]; then
        __fail "Cannot compare reference value from CLI to '$EXPECTED_REFVAR_VALUE' because -v parameter was not specified when executing"
    fi

    create_temporary_outs() {
        TSTDOUT="`mktemp`" || __ut/die_usage "Failed to create temporary file for stdout"
        if (( SKIP_SUBSHELL == 1 )); then
            TSTDERR="/dev/tty" || __ut/die_usage "Failed to create temporary file for stderr"
        else
            VAROUT="`mktemp`"  || __ut/die_usage "Failed to create temporary file for variable output"
            TSTDERR="`mktemp`" || __ut/die_usage "Failed to create temporary file for stderr"
        fi
    }

    apply_temporary_runtime_vals() {
        while (( $# > 0 )); do
            org_vals+=( "$1" "${(P)1}" ); print -nv $1 -- "${new_vals[$1]}"
            shift
        done
    }
    restore_runtime_vals() { for KEY in ${(k)new_vals[@]}; do print -nv $KEY -- "${org_vals[$KEY]}"; done; }

    local {TSTD{OUT,ERR},VAROUT,ACTUAL_REFVAR_VALUE}=''
    local -i RC=127
    create_temporary_outs
    {
        local -A new_vals=( VERBOSE_OUTPUT '-1' OUTPUT_FILE "$TSTDOUT" OUTPUT_ERR_FILE "$TSTDERR" ) org_vals=( )

        typeset -ag last_executed=( "$@" )
        typeset -ag std_err=( ) std_out=( )
        local -a fn=( "${(@s:/:)0}" )

        local -i IX=0

        apply_temporary_runtime_vals "${(k)new_vals[@]}"
        subshell_var_capture() {
            ${typeset_refvar_from_cli[@]}
            "${last_executed[@]}" > "$TSTDOUT" 2> "$TSTDERR"
            echo "${(F)${(P)REFVAR_FROM_CLI}}" > "$VAROUT"
        }
        {
            if (( SKIP_SUBSHELL )); then
                "${last_executed[@]}" > "$TSTDOUT" 2> "$TSTDERR"; RC=$?
            else
                if [[ -n "$EXPECTED_REFVAR_VALUE" ]]; then
                    ( subshell_var_capture ); RC=$?; ACTUAL_REFVAR_VALUE="$(<$VAROUT)"
                else
                    ( "${last_executed[@]}" > "$TSTDOUT" 2> "$TSTDERR" ); RC=$?
                fi
                std_err=( "${(f@)$(<$TSTDERR)}" )
            fi
            std_out=( "${(f@)$(<$TSTDOUT)}" )

        } always { restore_runtime_vals }
    } always {
        rm "$TSTDOUT"
        if [[ -n "$VAROUT" ]]; then rm "$VAROUT"; fi
        if (( SKIP_SUBSHELL == 0 )); then rm "$TSTDERR"; fi
    }

    (( EXPECTED_RC == -1 )) || { () { return $RC }; assert_return "${(j: :)last_executed[@]}" $EXPECTED_RC }
    [[ -z "$EXPECTED_REFVAR_VALUE" ]] || {
        assert/$RV_TYPE ACTUAL_REFVAR_VALUE is-equal-to "${EXPECTED_REFVAR_VALUE}"
    }
    [[ -z "$expected_stdout" ]] || {
        local STD_OUT="${(j::)std_err[@]}" EXP_STD_OUT="${(j::)expected_stdout[@]}"
        assert/scalar STD_OUT is-equal-to "$EXP_STD_OUT"
    }

    local STD_ERR="${(j::)std_err[@]}" EXP_STD_ERR="${(j::)expected_stderr[@]}"
    if [[ -z "$expected_stderr" ]]; then
        [[ "$NO_CLIP" -eq 1 || "$EXPECTED_RC" -eq "-1" || -z "$STD_ERR" ]] || {
            local -a new_stmt=( "safe_execute" '-r' "$EXPECTED_RC" )
            (( SKIP_SUBSHELL == 0 )) || new_stmt[2]="-xr"
            [[ -z "${expected_std_out}" ]] || new_stmt+=( '-o' "\$${(qq)${(j::)expected_std_out[@]}}" )

            new_stmt+=( '-e' "\$${(qq)$(__ut/escape_ans "$STD_ERR")}" )

            __ut/to_clip -s -- print -rn -- "${new_stmt[1]} ${${(@)new_stmt:1}[@]} "$' \\\n            -- '"${(j: :)${(qq@)last_executed[@]}}"
            print -- "\t\tOutput targetted at stderr was collected - an assertion that includes this output has replaced your clipboard contents" > /dev/tty
            return 0
        }
    else
        assert/scalar STD_ERR is-equal-to "$EXP_STD_ERR"
    fi
    return $RC
}


alias -g test_sections='|| ()'
unit_group() { [[ "${___test_arg:-${1:-}}" == "$1" ]] && print_section "Group: $2"; [[ "${___test_arg:-${1:-}}" != "$1" ]] }

