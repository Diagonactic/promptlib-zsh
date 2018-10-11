#!/usr/bin/env zsh
#source /home/acousticiris/.zplugin/plugins/zdharma---zui/zui.plugin.zsh

zmodload zsh/parameter
setopt localoptions extendedglob shortloops
__ut/center() {
    if (( $# == 1 )); then 2='='; fi
    local -i LLEN=$(( ( COLUMNS + ${#1} ) / 2 )) RLEN=$(( ( COLUMNS - ${#1} ) / 2 ))
    local RV="${(l.$LLEN..╳.)1}${(r.$RLEN..╳.)}"
    IFS="$2" print -- "${RV//╳/$2}"
}

json-value-switch-{integer,float,scalar,array}() {
    local {OPT,OPTARG}=''; local -i OPTIND=0;
	declare -g is_set=0
	if [[ "${0##*-}" == "array" ]]; then local -ga array_value=( ); fi
	while getopts "V:" OPT; do
		is_set=1
		case "${0##*-}" in
			(integer) 	declare -gir JSON_INTEGER_VALUE="$OPTARG" ;;
			(float)   	declare -gfr JSON_FLOAT_VALUE="$OPTARG"   ;;
			(scalar)  	declare -gr  JSON_SCLAR_VALUE="$OPTARG"   ;;
			(array)   	array_value+=( "$OPTARG" )                ;;
		esac
	done

	case "${0##*-}" in
		(integer) 	(( is_set == 1 )) || unset JSON_INTEGER_VALUE 							    ;;
		(float)   	(( is_set == 1 )) || unset JSON_FLOAT_VALUE   							    ;;
		(scalar)  	(( is_set == 1 )) || unset JSON_SCLAR_VALUE   							    ;;
		(array)   	(( is_set == 0 )) || declare -gar json_array_value=( "${array_value[@]}" )  ;;
	esac
    (( OPTIND > 1 )) && shift $(( OPTIND - 1 ))
    declare -ga argv_result=( "$@" )
}
declare ITEM{,C,P}=''
for ITEM in {integer,float,scalar,array}; do
	ITEMC="${(U)ITEM}"
	ITEMP=''
	case "$ITEM" in
		(integer) ITEMP="-i "
		;|
		(float)   ITEMP="-f "
		;|
		(integer|float|scalar) ITEMP+="JSON_${ITEMC}_VALUE="
		;|
		(integer|float) ITEMP+='0' ;;
		(scalar) ITEMP+="''" ;;
		(array)   ITEMP="-a json_array_value=( )" ;;
	esac
	alias "json:value:switch:$ITEM"="local is_set=0; local $ITEMP; json-value-switch-$ITEM "$@"; argv=( \"\$argv_result\" )"
done
unset ITEM ITEMC ITEMP
function die() {
	print -- "ERROR: $1"
	exit 1
}

function json-scalar() {
	(( $# > 2 )) || { print -n '""'; return 0 }
	json-quoted "$JSON_SCALAR_VALUE"
}
function json-scalar{,-lines}() {
	json:value:switch:scalar
	(( $# == 2 )) || die "$0: Expected at least 2 parameters - indent and json-name"
	json-varname $1 "$2"
	(( ${+JSON_SCALAR_VALUE} == 1 )) || {
		print -n -- 'null'; return 0
	}
	if [[ "${0##*-}" == "scalar" ]]; then
		json-quoted "$JSON_SCALAR_VALUE"; return $?
	fi
	local lines=( "${(f@)${JSON_SCALAR_VALUE:-}}" )
	json-array $(( $1 + 1 )) lines "${lines[@]}"
}
function json-array{,-lines} {
	(( $# >= 2 )) || die "$0: Expected at least 2 parameters - indent and json-name"
	json-varname $1 "$2"
	(( $# > 2 )) || { print -n '[]'; return 0 }
	shift 2
	(( $# > 3 )) || { print -n '['; json-quoted "$3"; print -n ']'; return 0 }
	__indent $1 '['

	if [[ "${0##*-}" == "lines" ]]; then
		json-scalar-lines $(( $1 + 1 )) "$2" "$3"
	else
		json-scalar $(( $1 + 1 )) "$2" "$3"
	fi
}
function json-association{,-lines} {
	(( $# > 2 && $# < 4 )) || die "$0: Expected at least parameters - indent and json-name (optional name of association to print values of)"
	json-varname $1 "$2"
	(( $# > 2 )) || { print -n 'null'; return 1 }
	local -A src=( "${(kv@P)3}" )
	(( ${#src} > 0 )) || { print -n '{}'; return 1 }
	print '{'
	__indent $1
	local -a keys="${(Oi@)${(k)src[@]}}"
	local KEY=''
	for KEY in "${keys[@]}"; do
		if [[ "${0##*-}" == "lines" ]]; then
			json-scalar-lines $(( $1 + 1 )) "$KEY" "$src[$KEY]"
		else
			json-scalar $(( $1 + 1 )) "$KEY" "$src[$KEY]"
		fi
	done
}
__indent() print -n "${(r<$(( $1 * 2 ))>)}${2-}"
json-{quoted,varname}() {
	if [[ "${0##*-}" == quoted ]]; then print -rn -- '"'"${1//\"/\\\"}"'"'
	else __indent $1; json-quoted "$2"; print -n ': '; fi
}

function print-it() {
	#set -x
	function print-as-{con,piped,json} {

		if [[ "$VAR_TYPE" == (array|association) ]]; then
			local -i MAX_WID=$(( ${#${(O@)keys//?/X}[1]} + 1 ))
			(( MAX_WID % 2 == 0 )) && integer -r HLF_WID=$(( MAX_WID / 2 )) || {
				(( MAX_WID >= $COLUMNS )) && integer -r HLF_WID=$(( MAX_WID / 2 + 1 )) || integer -r HLF_WID=$(( MAX_WID / 2 - 1 ))
			}
		fi
		local KEY=
		case "${0##*-}" in
			(con|piped) __ut/center " ${(C)VAR_TYPE}: $VAR_NAME "
			;|
			(con)	if [[ "$VAR_TYPE" == (array|association) ]]; then
						for KEY in ${keys[@]}; do
							print -n -- $'    \e[0;37m'"$VAR_NAME"$'\e[1;90m[\e[97m'"${(l<$MAX_WID>)${(l.$HLF_WID.r.$HLF_WID.)KEY}}"$'\e[90m]\e[0;37m=\e[1;97m'
							() {
								print -r -- "${1}"$'\e[0;37m'; shift
								(( $# > 1 )) || return 0
								while (( $# > 0 )); do
									print -r -- "$PAD"$'\e[0m\e[37m=\e[1;97m'"$1"$'\e[0m\e[37m'
									shift
								done
								print -- $'\e[0m\e[37m'
							} "${(f)${src[$KEY]}}"
						done
					else
						print "    $VAR_NAME=$src"
					fi
			;;
			(piped) if [[ "$VAR_TYPE" == (array|association) ]]; then
						for KEY in ${keys[@]}; do
							print -n -- "    ${VAR_NAME}[${(l<$MAX_WID>)${(l.$HLF_WID.r.$HLF_WID.)KEY}}]="
							() {
								print -r -- "$1"
								(( $# > 1 )) || return 0
								while (( $# > 0 )); do
									print -r -- "$PAD$1"
									shift
								done
								print
							} "${(f)${src[$KEY]}}"
						done
					else
						print "    $VAR_NAME=$src"
					fi
			;;
			(json)  function json_{scalar,integer,float,array} {  # TODO: Absolutely no sanitization is done; do it before wiring it up
						js-scalar() {
							local -a lines=( "${(f@)1}" )
							(( $# > 1 )) || { json-quoted "$1"; return 0 }
							print '{'
							json_array "$(( indent + 2 ))" lines "${lines[@]}"
							print -n "$PAD_SH}"
						}
						js-{integer,float}() { print -rn "${1:-null \/\/ number}"; }
						js-array() {
							print "["
							() {
								print -r -- "$PAD_SH\"$1\""
								(( $# > 1 )) || return 0
								while (( $# > 0 )); do
									print -rn -- "$PAD"$',\n"'"${(V)1}\""
									shift
								done
								print
							} "${(f)1}"
							print "$PAD]"
						}

						integer -r indent=$(( $1 * 2 ))
						local   -r PAD="${(r<$indent>)}" PAD_SH="${(r<$(( indent - 2))>)}" JSON_NAME="$2"
						local   -r ZSH_TYPE="${0##*_}"
						shift 2

						print -n "$PAD_SH"; js-scalar "$JSON_NAME"
						print -n "$PAD_SH\"$JSON_NAME\": "
						"js-${0##*_}" "$@"
					}
					case "$VAR_TYPE" in
						(array) argv=( "${src[@]}" )
						;|
						(integer|float|scalar|array) "json_$VAR_TYPE" 1 "$VAR_NAME" "$@"
						;;
						(association)
							print -n -- "  "; impl-scalar "$VAR_NAME"; print -n ': {'
							for KEY in ${keys[@]}; do
								json_scalar 4 "$KEY" "${src[$KEY]}"
							done
							print -- "  }"
						;;
					esac
		esac
	}
	#set -x
	local -r VAR_TYPE="$1" VAR_NAME="$2"
	local -i width=0

	case "$1" in
		array)
			typeset -ar src=( "${(@P)2}" )
			[[ -n "$src" ]] && (( ${#${src[@]}} > 0 )) || return 0
			local -a keys=( {1..${#${src[@]}}} )

		;|
		association)
			typeset -Ar src=( "${(kv@P)2}" )
			[[ -n "$src" ]] && (( ${#${(kv)src[@]}} > 0 )) || return 0
			local -a keys=( {${(oi@)${(k)src[@]}}} )
		;|
		array|association)
			local KEY='';  local -i KEY_WID=0
			local PAD="${(r<$(( MAX_WID + HLF_WID + 7 ))>)}"
			print-as-con

			;;
		scalar|integer|float)
			print $'    \e[1;95m\e[97m'"$2"$'\e[90m=\e[4;36m'"$3"$'\e[0m\e[37m'
	esac
}

function collect-trace() {
	print -- "$LINENO"

	print -- ",, ${funcsourcetrace[1]}"
	print -- ".. $(( ${funcsourcetrace[1]##*:} + $LINENO )) .."
	print -l -- "${funcsourcetrace[@]}"
}

function a() {
	function b() {
		local -A scalar_parameter_value_map=(  )
		local KEY=''
		for KEY in ${(k)parameters[@]}; do
			if [[ "${parameters[$KEY]}" == 'scalar'* ]]; then
				scalar_parameter_value_map[$KEY]="${parameters[$KEY]} : '${(P)KEY}'"
			elif [[ "${parameters[$KEY]}" == 'integer'* ]]; then
				scalar_parameter_value_map[$KEY]="${parameters[$KEY]} : ${(P)KEY}"
			else
				scalar_parameter_value_map[$KEY]="${parameters[$KEY]}"
			fi
		done
		print-it association scalar_parameter_value_map
		print-it array funcsourcetrace
		print-it array funcfiletrace
		print-it association termcap  | less
		print-it association terminfo | less
		print "${${(%):-%x}:A:h}"
		#print -P %x
		# print -l -- "${funcsourcetrace[@]}"
		#source ~/.zplugin/plugins/zdharma---zbrowse/zbrowse

		#print-it association functions
		#print-it association aliases
		#declare
	}
	b
}
a

