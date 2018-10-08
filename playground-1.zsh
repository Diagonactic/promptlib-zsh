#!/usr/bin/env zsh
source /home/acousticiris/.zplugin/plugins/zdharma---zui/zui.plugin.zsh

zmodload zsh/parameter
setopt extendedglob
__ut/center() {
    if (( $# == 1 )); then 2='='; fi
    local -i LLEN=$(( ( COLUMNS + ${#1} ) / 2 )) RLEN=$(( ( COLUMNS - ${#1} ) / 2 ))
    local RV="${(l.$LLEN..╳.)1}${(r.$RLEN..╳.)}"
    IFS="$2" print -- "${RV//╳/$2}"
}

function print-it() {

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
			local -a keys=( {1..${(k)src[@]}} )
		;|
		array|association)
			local KEY=''
			__ut/center " ${(C)1}: $2 "
			local -a keys=( "${(k)src[@]}" )

    		local -i MAX_WID=${#${(O@)keys//?/X}[1]}
			local -i HLF_WID="$(( MAX_WID / 2 ))"
			local -i KEY_WID=0
			local PAD="${(r<$(( MAX_WID + HLF_WID + 7 ))>)}"

			for KEY in ${keys[@]}; do
				print -n -- $'    \e[0;37m'"$2"$'\e[1;90m[\e[97m'"${(l<$MAX_WID>)${(l.$HLF_WID.r.$HLF_WID.)KEY}}"$'\e[90m]\e[0;37m=\e[1;97m'
				() {
					print -r -- "${1}"$'\e[0;37m'; shift
					(( $# > 1 )) || return 0
					while (( $# > 0 )); do
						print -r -- "$PAD"$'\e[0m\e[37m=\e[1;97m'"$1"$'\e[0m\e[37m'
						shift
					done
				} "${(f)${src[$KEY]}}"
				print -n -- $'\e[0m\e[37m\n'
			done
			;;
		scalar|integer|float)
			print $'    \e[1;95m\e[97m'"$2"$'\e[90m=\e[4;36m'"$3"$'\e[0m\e[37m'
	esac
}

function a() {
	function b() {
		source "${${${(%):-%x}:h}:A}/test/playground-2.zsh"

		#print-it association functions
		#print-it association aliases
		#declare
	}
	b
}
a

