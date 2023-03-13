#! /bin/bash
subject="$*"
echo
echo "TODO: Find commit with subject: $subject"
echo
echo "*********************"
if [ -z "$subject" ]; then
	echo "No subject given, exit"
	exit
fi

git log | grep -m 1 "$subject" -B 4 -A 2 | tee /tmp/tee-commit.log

echo "*********************"
echo 
 cat /tmp/tee-commit.log | grep "Author" -B 1 |head -1 | awk '{print $2}'

