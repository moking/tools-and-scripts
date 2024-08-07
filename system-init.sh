#! /bin/bash
#
tools_dir=~/cxl/tools-and-scripts/
cxl_tool_dir=~/cxl/cxl-test-tool/

sudo apt-get install b4 mutt cscope 

echo ln -s $tools_dir/patch-pull/pull-patch-series.py /usr/local/bin/pull-patch
sudo ln -s $tools_dir/patch-pull/pull-patch-series.py /usr/local/bin/pull-patch
echo ln -s $tools_dir/mutt-patch.py /usr/local/bin/mutt-patch
sudo ln -s $tools_dir/mutt-patch.py /usr/local/bin/mutt-patch
echo ln -s $cxl_tool_dir/cxl-tool.sh /usr/local/bin/cxl-tool
sudo ln -s $cxl_tool_dir/cxl-tool.sh /usr/local/bin/cxl-tool

echo Install fish and chsh
sudo apt-get install fish
chsh -s /usr/bin/fish
