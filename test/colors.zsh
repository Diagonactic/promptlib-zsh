#!/usr/bin/env zsh
#source /home/acousticiris/.zplugin/plugins/zdharma---zui/zui.plugin.zsh

zmodload zsh/parameter zsh/terminfo
setopt localoptions extendedglob shortloops
ticode() 2>/dev/null echoti "$1"

# Initialize Globals Used by Library
typeset -Ag fg=( ) bg=( ) attr=(
	blink 			"$(ticode blink)"
	bold 			"$(ticode bold)"
	dim				"$(ticode dim)"
	italic			"$(ticode sitm)"
	underline		"$(ticode smul)"
) end_attr=(
	underline 	"$(ticode rmul)"
)
typeset -agU end_attr_supported=( ) attr_supported=( ) attr_combinations=( ) attr_combinations_supported=( )

init() {
	global-attr() {

		combined-has-key() {
			key-matches() {
				local -a has_key_pt=( "${(oi@s<->)1}" )
				for KEYPART in "${key_pt[@]}"; do
					(( ${has_key_pt[(i)$KEYPART]} <= ${#has_key_pt[@]} )) || return 1
				done
			}
			local -a key_pt=( "${(oi@s<->)1}" ) has_key_pt=( )
			local KEY='' KEYPART=''
			local -a ac=( "${attr_combinations[@]}" )
			for KEY in ${attr_combinations[@]}; do

				if key-matches
				for KEYPART in "${key_pt[@]}"; do
					if ; then return 1; fi
				done
			done
			return 1
		}
		combine-attrs() {
			contains-keys() {
				local KEY="$1"; shift; local -a key_components=( "${(oi@s<->)KEY}" )
				while (( $# > 0 )); do
					(( ${#key_components[(i)$1]} <= ${#key_componets[@]} )) || return 1
					shift
				done
			}
			local KEY=''; integer CT=0;
			for KEY in ${${(k)attr[@]}:#$1}; do
				CT="${#attr_combinations[@]}"
				components=(  )
				new_components=( "${(oi@s<->)1}" )
				if (( ${attr_combinations[(i)$1-$KEY]} <= $CT || ${attr_combinations[(i)$KEY-$1]} <= ${#attr_combinations[@]} )) || contains-keys "$KEY" "${(oi@s<->)KEY}"; then
					continue
				fi
				attr_combinations+=( "$1-$KEY" )
			done
		}
		local KEY='' XKEY=''
		for KEY in ${(k)attr[@]}; do
			[[ -n "$attr[$KEY]" ]] || continue;
			supported_attrs+=( "$KEY" )
		done
		supported_attrs=( "${(oi)supported_attrs[@]}" )
		set -x
		for KEY in "${(k)attr[@]}"; do
			for XKEY in "${(@)${(k)attr[@]}:#$KEY}"; do
				if combined-has-key "$KEY-$XKEY"; then continue; fi
				attr_combinations+=( "$KEY-$XKEY" )

				# CT="${#attr_combinations[@]}"
				# TEST="$XKEY-$KEY"
				# if (( ${attr_combinations[(i)$TEST]} <= $CT )); then continue; fi
				# TEST="$KEY-$XKEY"
				# if (( ${attr_combinations[(i)$TEST]} <= $CT )); then continue; fi
				# attr_combinations+=( "$KEY-$XKEY" )
			done
		done
		set +x
		# attr_combinations=( "${(oi)attr_combinations[@]}" )
		# for KEY in "${attr_combinations[@]}"; do
		# 	combine-attrs "$KEY"
		# done
		# attr_combinations=( "${(oi)attr_combinations[@]}" )
		print -l -- "${attr_combinations[@]}"
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
			dim-$i 				"$ATTROFF${attr[dim]}$FG"		\
            normal-$i   		"$ATTROFF$FG" 					\
			italic-$i			"$ATTROFF${attr[italic]}$FG"    \
			bold-$i     		"$ATTROFF$BOLD$FG" 				\
			underline-$i 		"$ATTROFF${attr[underline]}$FG" \
			bold-underline-$i 	"$ATTROFF$BOLD${attr[underline]}$FG"
        )
        bg+=( \
            $i          "$BG"         \
        )
    done

    for KEY in ${(oin)name_keys[@]}; do
		KEYV="${cname_map[$KEY]}"
		FG="${fg[$KEYV]}"
		fg+=( "$KEY" "$FG" )
		for ATTR in ${(@)${(k@)attr[@]}:#end-*}; do
			fg+=( "$ATTR-$KEY" "$ATTROFF${attr[$ATTR]}$FG" )
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
print -- "Attribute Combinations: ${(j< >)${(io@)attr_combinations[@]}}"
print -- "Terminal Colors: ${(j< >)${(io@)supported_colors[@]}}"

exit 0
