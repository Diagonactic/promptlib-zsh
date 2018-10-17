#!/usr/bin/env zsh
#source /home/acousticiris/.zplugin/plugins/zdharma---zui/zui.plugin.zsh
zmodload zsh/parameter zsh/terminfo
setopt localoptions extendedglob shortloops
ticode() 2>/dev/null echoti "$1"

# Initialize Globals Used by Library
typeset -ah target_keycombinations=(
	{dim-{italic,underline,italic-underline,italic-underline-reverse},bold-{italic,underline,italic-underline,italic-underline-reverse},underline-{italic,{reverse,italic-reverse}}}
)

print -l -- "${target_keycombinations[@]}"
typeset -Ag fg=( ) bg=( ) attr=(
	bold 			"$(ticode bold)"
	dim				"$(ticode dim)"
	italic			"$(ticode sitm)"
	reverse			"$(ticode rev)"
	standout        "$(ticode smso)"
	underline		"$(ticode smul)"
	blink 			"$(ticode blink)"
) exit_attr=(
	underline 		"$(ticode rmul)"
	italic			"$(ticode ritm)"
	standout        "$(ticode rmso)"
) cmds=(
	'reset'			"$(ticode sgr0)"
	'clear'			"$(ticode clear)"
	'clear-to-bol'  "$(ticode el1)"
	'clear-to-eol'  "$(ticode el)"
	'clear-to-eos'  "$(ticode ed)"
) supports=(
	'truecolor'     "$(ticode Tc)"
)
target_keycombinations+=( "${(k)attr[@]}" )

# Get base attributes that are unsupported by this terminal session
typeset -agU unsupported_attrs=( )
() {
	while (( $# > 0 )); do [[ -n "${attr[$1]}" ]] || unsupported_attrs+=( "$1" ); shift; done
} "${(k)attr[@]}"

() {
	while (( $# > 0 )); do
		local KEY="$1"
		() {
			while (( $# > 0 )); do
				attr[$KEY]+="${attr[$1]}"
				if (( ${unsupported_attrs[(i)$1]} <= ${#${unsupported_attrs[@]}} )); then
					unsupported_attrs+=( "$KEY" )
				fi
				shift
			done

		} ${(oi@s<->)KEY}
		shift
	done
} "${target_keycombinations[@]}"

# Add the 'reset' capability
attr+=( 'reset' "$(ticode sgr0)" )

typeset -agU supported_end_attrs=( ) all_attrs=( "${(oik)attr[@]}" )
typeset -agU supported_attrs=( ${${all_attrs[@]:|unsupported_attrs}[@]} )

function concmds/{clear{,-to-{bol,eol,eos}},reset} {
	print -n -- "${cmds[${0##*/}]}"
}
function consupports/truecolor {
	case "${0##*/}" in
		(truecolor) [[ "${supports[${0##*/}]}" == yes ]]
	esac
}

concmds/clear

() {
    local -A cname_map=(
        black     		0
        red       		1
        green     		2
        yellow    		3
        orange    		3
        blue      		4
        purple    		5
        magenta   		5
        cyan      		6
        white     		7
        gray      		7
		dark-gray 		8
		light-red 		9
		light-green 	10
		light-yellow 	11
		light-blue   	12
		light-purple	13
		light-magenta	13
		light-cyan		14
		light-white		15
		bright-white    15
    )
    local ATTROFF="$(echoti sgr0)" BOLD="$(echoti bold)"
    typeset -Ag fg=( ) bg=( )
    typeset -a name_keys=( "${(koi)cname_map[@]}" )
    typeset {{F,B}G,{ATTR,KEY,KEYV,CKEY}}=''
    integer i=0
    for (( i=0; i<16; i++ )); do
        FG="$(echoti setaf $i)"
        BG="$(echoti setab $i)"
        fg+=( $i "$FG" )
        bg+=( $i "$BG" )
    done

    for KEY in ${(oin)name_keys[@]}; do
		KEYV="${cname_map[$KEY]}"
		FG="${fg[$KEYV]}"
		fg+=( "$KEY" "$FG" )
    done
}

eti() {
	echoti "${@:2}"
	print -n -- "${${1}:-(j< >)@}"
}
rstpr() {
	print -n "${1:-}"$'\e[0m\e[0;37m'
}

for i in {1..16}; do
	eti "$i:" sgr0
	eti "sgr0-$i " setaf $i
	eti "sgr 1-$i" bold
	rstpr
	print
done
print -- 'https://matthewdippel.blogspot.com ------'

() {
	prt() {
		(( ${unsupported_attrs[(i)$2]} >= ${#unsupported_attrs[@]} )) || return 0
		local -a sp=( "${(s<->@)2}" )
		if (( ${#sp} == 1 )); then
			print -n -- "${attr[reset]} - ${fg[$1]}${attr[$2]}${2}${attr[reset]}"
		else
			print -n -- "${attr[reset]} - ${fg[$1]}${attr[$2]}${(j<->)${sp[1]}-${sp:2[@]%%(alic|ink|derline)}}${attr[reset]}"
		fi
	}
	typeset -i MAX_WIDTH=${#${(O@)${(k)fg[@]}//?/X}[1]}
	local KEY=''
	while (( $# > 0 )); do
		rstpr
		if [[ "$1" == (*-black|*-0) ]]; then print -n $'\e[0m\e[0;37m'"($1)"; fi
		print -n -- "${fg[$1]}${(r<13>)1}";
		local ITM=''
		for ITM in "${target_keycombinations[@]}"; do
			prt "$1" "$ITM"
		done
		print
		shift
	done
} "${(iok)fg[@]}"

print -- "Terminal Attributes: ${(j< >)supported_attrs[@]}"
consupports/truecolor && print -- "True Color" || print -- "Not True Color"
exit 0
