#!/usr/bin/env zsh

source ${0:A:h}/modules.zsh

for module in ${MODULES}
do
  if [[ -f "${0:A:h}/modules/${module}.zsh" ]]
  then
    echo "${0:A:h}/modules/${module}.zsh"
    source "${0:A:h}/modules/${module}.zsh"
  else
    echo "module: '${module}' not found"
  fi
done

echo
echo "  ==> git"
echo -ne "plib_is_git -> " && plib_is_git
echo
echo -ne "plib_git_branch -> " && plib_git_branch
echo
echo -ne "plib_git_rev -> " && plib_git_rev
echo
echo -ne "plib_git_dirty -> " && plib_git_dirty
echo
echo -ne "plib_git_left_right -> " && plib_git_left_right
echo
echo -ne "plib_git_commit_since -> " && plib_git_commit_since
echo
echo
echo "  ==> mercurial"
echo -ne "plib_is_hg -> " && plib_is_hg
echo
echo -ne "plib_hg_branch -> " && plib_hg_branch
echo
echo -ne "plib_hg_rev -> " && plib_hg_rev
echo
echo
echo "  ==> subversion"
echo -ne "plib_is_svn -> " && plib_is_svn
echo
echo -ne "plib_svn_rev -> " && plib_svn_rev
echo
echo
echo "  ==> ssh"
echo -ne "plib_ssh_st -> " && plib_ssh_st
echo
echo -ne "plib_ssh_client_ip -> " && plib_ssh_client_ip
echo
echo -ne "plib_ssh_client_port -> " && plib_ssh_client_port
echo
echo
echo "  ==> python"
echo -ne "plib_venv -> " && plib_venv
echo
echo
echo "  ==> background_job"
echo -ne "plib_bg_count -> " && plib_bg_count
echo
echo
echo "  ==> disk"
echo -ne "plib_disk_name -> " && plib_disk_name
echo
echo -ne "plib_disk_size -> " && plib_disk_size
echo
echo -ne "plib_disk_avail -> " && plib_disk_avail
echo
echo -ne "plib_disk_used -> " && plib_disk_used
echo
echo -ne "plib_disk_cap -> " && plib_disk_cap
echo
echo
echo "  ==> time"
echo -ne "plib_time -> " && plib_time
echo
echo -ne "plib_date -> " && plib_date
echo
echo -ne "plib_day -> " && plib_day
echo
