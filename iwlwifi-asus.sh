modprobe -r iwlmvm
modprobe -r iwlwifi
modprobe -r mac80211
modprobe iwlmvm
modprobe iwlwifi
modprobe mac80211
systemctl restart NetworkManager
