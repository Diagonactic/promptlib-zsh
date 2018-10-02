#!/usr/bin/env zsh

fplib-disk() {
  declare -g DF; DF=( "${${${(Af)$(df -h ${1:-$PWD})}[@]}[2]}" ) || return 1
  local -a parts=( ${${(s: :)DF}[@]} )
  declare -g DISK_NAME="${parts[1]}" DISK_SIZE="${parts[2]}" DISK_USED="${parts[3]}" DISK_AVAIL="${parts[4]}" DISK_CAP="${parts[5]}"
}

plib_disk_name()  { echo -ne "`df -h . | tail -1 | awk '{print $1}'`"; }
plib_disk_size()  { echo -ne "`df -h . | tail -1 | awk '{print $2}'`"; }
plib_disk_used()  { echo -ne "`df -h . | tail -1 | awk '{print $3}'`"; }
plib_disk_avail() { echo -ne "`df -h . | tail -1 | awk '{print $4}'`"; }
plib_disk_cap()   { echo -ne "`df -h . | tail -1 | awk '{print $5}'`"; }