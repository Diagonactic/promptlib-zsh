#!/usr/bin/env zsh
#source /home/acousticiris/.zplugin/plugins/zdharma---zui/zui.plugin.zsh

zmodload zsh/parameter zsh/terminfo
setopt localoptions extendedglob shortloops
ticode() 2>/dev/null echoti "$1"

# Initialize Globals Used by Library
typeset -Ag fg=( ) bg=( ) attr_map=(
	bold 			"$(ticode bold)"
	dim				"$(ticode dim)"
	italic			"$(ticode sitm)"
	underline		"$(ticode smul)"
	blink 			"$(ticode blink)"
) end_attr=(
	underline 	"$(ticode rmul)"
)

# Get base attributes that are unsupported by this terminal session
typeset -agU unsupported_attrs=( )
() {
	while (( $# > 0 )); do [[ -n "${attr_map[$1]}" ]] || unsupported_attrs+=( "$1" ); done
} "${(k)attr_map[@]}"

from-map() {
	while (( $# > 0 )); do
		local KEY="$1"
		() {
			while (( $# > 0 )); do
				attr_map[$KEY]+="${attr_map[$1]}"
				if (( ${unsupported_attrs[(i)$1]} <= ${#${unsupported_attrs[@]}} )); then
					unsupported_attrs+=( "$KEY" )
				fi
				shift
			done

		} ${(oi@s<->)KEY}
		shift
	done
}
#typeset -Ag extended_attr_map=(	"${(kv)attr_map[@]}" )
from-map bold-blink bold-underline bold-italic dim-italic dim-underline dim-blink italic-underline italic-blink
print -l -- "${(kvV)attr_map[@]}"
print
typeset -agU supported_end_attrs=( ) supported_attrs=( ) all_attrs=( "${(oik)extended_attr_map[@]}" )
print -l -- "${(kvV)all_attrs[@]}"
exit 0
array-has-same-keys() {
	local -a src=( "${(@P)1}" ); shift;
	(( ${#src} == $# )) && (( ${#${${src[@]:|argv}[@]}} == 0 ))
}

init() {

	global-attr() {
		already-has-key() {
			(( ${#all_attr_combinations[@]} > 0 || ${all_attr_combinations[(i)$1]} >= ${#all_attr_combinations[@]} )) || return 1
			local SRCKEY="$1"; local -aU src=( ${(oi@s<->)1} ); shift
			() {
				while (( $# >= 1 )); do
					{ [[ "$1" == "$SRCKEY" ]] || array-has-same-keys src ${(uoi@s<->)1} } && return 1 || shift;
				done
			} "${all_attr_combinations[@]}" && return 1 || return 0
		}
		all_attrs=( ${(k)attr_map[@]} ); all_attr_combinations=( ${all_attrs[@]} ); all_base_attrs=( ${all_attrs[@]} )
		local KEY='' XKEY=''
		for KEY in ${all_attrs[@]}; do
			[[ -n "$attr_map[$KEY]" ]] || continue;
			supported_attrs+=( "$KEY" )
		done
		supported_attrs=( "${(oi)supported_attrs[@]}" )
		print "${#${(k@)attr_map[@]}}"
		repeat "${#${(k@)attr_map[@]}}"; do
			for KEY in ${all_attr_combinations[@]}; do
				for XKEY in ${all_base_attrs[@]:#KEY}; do
					already-has-key "$KEY-$XKEY" && continue ||	all_attr_combinations+=( "$KEY-$XKEY" )
				done
			done
		done
		local VAL=''
		set -x
		local -a keys=( ${${all_attr_combinations[@]:|all_attrs}[@]} )
		for KEY in ${keys[@]}; do
			VAL=''
			() { while (( $# > 0 )); do VAL+="${attr_map[$1]}"; shift; done	} ${(@s<->)KEY}
			attr_map[$KEY]="$VAL"
		done
		print "attr_map:"
		print -l -- "${(kvV)attr_map[@]}"
		read -k1 -s
	}
	global-attr
}
init

() {
    local -A cname_map=(
        black   0
        red     1
        green   2
        yellow  3
        orange  3
        blue    4
        purple  5
        magenta 5
        cyan    6
        white   7
        gray    8
    )
    local ATTROFF="$(echoti sgr0)" BOLD="$(echoti bold)"
    typeset -Ag fg=( ) bg=( )
    typeset -a name_keys=( "${(koi)cname_map[@]}" )
    typeset {{F,B}G,{ATTR,KEY,KEYV,CKEY}}=''
    integer i=0
    for (( i=0; i<=8; i++ )); do
        FG="$(echoti setaf $i)"
        BG="$(echoti setab $i)"
        fg+=( \
            $i          		"$FG"         					\
			dim-$i 				"$ATTROFF${attr_map[dim]}$FG"		\
            normal-$i   		"$ATTROFF$FG" 					\
			italic-$i			"$ATTROFF${attr_map[italic]}$FG"    \
			bold-$i     		"$ATTROFF$BOLD$FG" 				\
			underline-$i 		"$ATTROFF${attr_map[underline]}$FG" \
			bold-underline-$i 	"$ATTROFF$BOLD${attr_map[underline]}$FG"
        )
        bg+=( \
            $i          "$BG"         \
        )
    done

    for KEY in ${(oin)name_keys[@]}; do
		KEYV="${cname_map[$KEY]}"
		FG="${fg[$KEYV]}"
		fg+=( "$KEY" "$FG" )
		for ATTR in ${(@)${(k@)attr_map[@]}:#end-*}; do
			fg+=( "$ATTR-$KEY" "$ATTROFF${attr_map[$ATTR]}$FG" )
		done
    done
	typeset -agU supported_basefg_colors=( )
	typeset -agU supported_colors=( )

	for KEY in ${(k)fg[@]}; do
		[[ "$KEY" == [[:digit:]] ]] || continue;
		supported_basefg_colors+=( "$KEY" )
		for CKEY in ${name_keys[@]}; do
			if [[ "$CKEY" != *-* ]]; then supported_basefg_colors+=( "$CKEY" ); fi
		done
	done
	for KEY in ${${supported_attrs[@]}:#end-*}; do
		for CKEY in ${name_keys[@]}; do
			supported_colors+=( "$CKEY" "$KEY-$CKEY" )
		done
	done
	supported_colors+=( "${supported_basefg_colors[@]}")
}

eti() {
	echoti "${@:2}"
	print -n -- "${${1}:-(j< >)@}"
}
rstpr() {
	print -n "${1:-}"$'\e[0m\e[0;37m'
}

for (( i=0; i<16; i++ )); do
	eti "$i:" sgr0
	eti "sgr0-$i " setaf $i
	eti "sgr 1-$i" bold
	rstpr
	print
done
print -- '------------------------------------'

() {
	typeset -i MAX_WIDTH=${#${(O@)${(k)fg[@]}//?/X}[1]}
	local KEY=''
	while (( $# > 0 )); do
		rstpr
		if [[ "$1" == (*-black|*-0) ]]; then print -n $'\e[0m\e[0;37m'"($1)"; fi
		print -- "${fg[$1]}$1"
		shift
	done
} "${(iok)fg[@]}"

print -- "Terminal Attributes: ${(j< >)supported_attrs[@]}"
print -- "Attribute Combinations: ${(j< >)${(io@)all_attr_combinations[@]}}"
print -- "Terminal Colors: ${(j< >)${(io@)supported_colors[@]}}"

exit 0
