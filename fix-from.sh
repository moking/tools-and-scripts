#! /bin/bash
#
git log -1
echo "Are you sure you want to fix the author? (Y/N)"
read ans
if [ "$ans" == 'Y' ];then
    echo git commit --amend --author="Fan Ni <fan.ni@samsung.com>" --no-edit
    git commit --amend --author="Fan Ni <fan.ni@samsung.com>" --no-edit
else
    echo "Skipped the fix"
fi
