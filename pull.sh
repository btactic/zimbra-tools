#!/bin/bash

echo "If your ssh-key is protected with a password it is recommended you run:";
echo 'ssh-agent bash'
echo 'ssh-add ~/.ssh/id_rsa'
echo "Hit enter, if you want to continue running this script, or CTRL+C  to abort";
read dum;

mkdir ~/Zimbra-Community

cd ~/Zimbra-Community

git clone ssh://github.com/Zimbra-Community/ansible-zimbradev
git clone ssh://github.com/Zimbra-Community/ADPassword
git clone ssh://github.com/Zimbra-Community/printpatch-zimlet
git clone ssh://github.com/Zimbra-Community/com_zimbra_stickynotes
git clone ssh://github.com/Zimbra-Community/adopted
git clone ssh://github.com/Zimbra-Community/ca_uoguelph_ccs_sidebar
git clone ssh://github.com/Zimbra-Community/ca_uoguelph_ccs_archive
git clone ssh://github.com/Zimbra-Community/zimbra.de_dieploegers_groupcal
git clone ssh://github.com/Zimbra-Community/python-zimbra
git clone ssh://github.com/Zimbra-Community/zimbra.de_dieploegers_followup
git clone ssh://github.com/Zimbra-Community/de_dieploegers_admin_vacation
git clone ssh://github.com/Zimbra-Community/de_dieploegers_godate
git clone ssh://github.com/Zimbra-Community/pgp-zimlet-test-reports
git clone ssh://github.com/Zimbra-Community/pgp-zimlet
git clone ssh://github.com/Zimbra-Community/zimbra-tools
git clone ssh://github.com/Zimbra-Community/owncloud-zimlet
git clone ssh://github.com/Zimbra-Community/list-unsubscribe-zimlet
git clone ssh://github.com/Zimbra-Community/zimbra-patches
git clone ssh://github.com/Zimbra-Community/attachmentalert-zimlet
git clone ssh://github.com/Zimbra-Community/sa-alert-zimlet
git clone ssh://github.com/Zimbra-Community/com_zimbra_converse
git clone ssh://github.com/Zimbra-Community/js-zimbra
git clone ssh://github.com/Zimbra-Community/zimlets-foss
git clone ssh://github.com/Zimbra-Community/build
git clone ssh://github.com/Zimbra-Community/zmpublish
git clone ssh://github.com/Zimbra-Community/de_dieploegers_savesend
git clone ssh://github.com/Zimbra-Community/zopenhsm
git clone ssh://github.com/Zimbra-Community/bulkreply-zimlet
git clone ssh://github.com/Zimbra-Community/zimbra-docker
git clone ssh://github.com/Zimbra-Community/com_zimbra_emailtemplates

cd "$(dirname "$0")"
ls | grep -v pull.sh | xargs -I{} git -C {} pull

echo "All done, please check if there are any errors in the terminal. And hit enter key to exit."
read end;