#!/usr/bin/env bash
#
# gentags.sh - 使用 cscope 和 ctags 为源码目录生成索引文件
#
# 生成的文件:
#   cscope.files                          参与索引的源文件列表
#   cscope.out cscope.in.out cscope.po.out cscope 数据库 (含倒排索引)
#   tags                                  ctags 标签文件
#
# 如果源码目录是 Linux 内核树, 只索引指定架构 (默认根据本机推断) 的
# arch/ 子目录, 并跳过 Documentation、tools、samples、scripts 等目录。

set -euo pipefail

SRC_DIR=.
ARCH_SEL=${ARCH:-}
DO_CSCOPE=1
DO_CTAGS=1
DO_CLEAN=0
EXCLUDES=()

CSCOPE_OUTPUTS=(cscope.files cscope.out cscope.in.out cscope.po.out
		cscope.out.in cscope.out.po)
CTAGS_OUTPUTS=(tags)

usage() {
	cat <<EOF
用法: $(basename "$0") [选项]

选项:
  -d DIR    源码根目录 (默认: 当前目录)
  -a ARCH   内核树时索引的架构, 如 x86、arm64、riscv
            (默认: 环境变量 \$ARCH, 否则根据 uname -m 推断)
  -x DIR    额外排除的目录 (相对源码根目录), 可重复使用
  -c        只生成 cscope 索引
  -t        只生成 ctags 索引
  -C        删除已生成的索引文件后退出
  -h        显示本帮助

示例:
  $(basename "$0")                     # 在当前目录生成 cscope + ctags 索引
  $(basename "$0") -d ~/linux -a arm64 # 为内核树生成 arm64 架构的索引
  $(basename "$0") -x drivers/gpu -t   # 排除 drivers/gpu, 只生成 tags
EOF
}

die() {
	echo "错误: $*" >&2
	exit 1
}

info() {
	echo ">>> $*"
}

host_arch() {
	case "$(uname -m)" in
	x86_64 | i?86)	echo x86 ;;
	aarch64*)	echo arm64 ;;
	arm*)		echo arm ;;
	riscv*)		echo riscv ;;
	ppc* | powerpc*) echo powerpc ;;
	s390*)		echo s390 ;;
	loongarch*)	echo loongarch ;;
	mips*)		echo mips ;;
	*)		uname -m ;;
	esac
}

is_kernel_tree() {
	[[ -f Kbuild && -f MAINTAINERS && -d arch && -d kernel ]]
}

gen_file_list() {
	local prune=(-path ./.git -o -path ./.svn -o -path ./.hg)
	local d

	if is_kernel_tree; then
		[[ -n "$ARCH_SEL" ]] || ARCH_SEL=$(host_arch)
		[[ -d "arch/$ARCH_SEL" ]] || die "内核树中不存在 arch/$ARCH_SEL"
		info "检测到 Linux 内核树, 索引架构: $ARCH_SEL"

		for d in arch/*/; do
			d=${d%/}
			[[ "$d" == "arch/$ARCH_SEL" ]] || prune+=(-o -path "./$d")
		done
		prune+=(-o -path ./Documentation -o -path ./tools
			-o -path ./samples -o -path ./scripts -o -path ./usr)
	fi

	for d in "${EXCLUDES[@]}"; do
		d=${d#./}
		d=${d%/}
		prune+=(-o -path "./$d")
	done

	find . \( "${prune[@]}" \) -prune -o -type f \
		\( -name '*.[chsS]' -o -name '*.cc' -o -name '*.cpp' \
		   -o -name '*.cxx' -o -name '*.hh' -o -name '*.hpp' \
		   -o -name '*.hxx' -o -name '*.[ly]' \) -print |
		sed 's|^\./||' | LC_ALL=C sort > cscope.files

	[[ -s cscope.files ]] || die "没有找到任何源文件"
	info "源文件数量: $(wc -l < cscope.files)"
}

gen_cscope() {
	local opts=(-b -q)

	command -v cscope >/dev/null || die "未安装 cscope"
	# -k: 内核模式, 不索引 /usr/include 下的系统头文件
	is_kernel_tree && opts+=(-k)

	info "生成 cscope 索引..."
	rm -f "${CSCOPE_OUTPUTS[@]:1}"
	cscope "${opts[@]}" -i cscope.files
}

gen_ctags() {
	local ver opts

	command -v ctags >/dev/null || die "未安装 ctags"
	ver=$(ctags --version 2>&1 || true)

	opts=(--c-kinds=+px --c++-kinds=+px --fields=+iaS -L cscope.files -f tags)
	if [[ "$ver" == *"Universal Ctags"* ]]; then
		opts+=(--extras=+q)
	elif [[ "$ver" == *"Exuberant Ctags"* ]]; then
		opts+=(--extra=+q)
	else
		die "需要 Universal Ctags 或 Exuberant Ctags"
	fi

	# 忽略内核中常见的修饰宏, 避免 ctags 把它们误当成标识符
	if is_kernel_tree; then
		opts+=(-I "__initdata,__exitdata,__initconst,__ro_after_init"
		       -I "__read_mostly,__aligned+,__packed,__used,__maybe_unused"
		       -I "__must_check,__acquires+,__releases+,__must_hold+"
		       -I "____cacheline_aligned,____cacheline_aligned_in_smp"
		       -I "__cacheline_aligned,__cacheline_aligned_in_smp"
		       -I "EXPORT_SYMBOL+,EXPORT_SYMBOL_GPL+"
		       -I "EXPORT_SYMBOL_NS+,EXPORT_SYMBOL_NS_GPL+")
	fi

	info "生成 ctags 索引..."
	rm -f tags
	ctags "${opts[@]}"
}

clean() {
	info "删除索引文件"
	rm -f "${CSCOPE_OUTPUTS[@]}" "${CTAGS_OUTPUTS[@]}"
}

while getopts "d:a:x:ctCh" opt; do
	case "$opt" in
	d) SRC_DIR=$OPTARG ;;
	a) ARCH_SEL=$OPTARG ;;
	x) EXCLUDES+=("$OPTARG") ;;
	c) DO_CTAGS=0 ;;
	t) DO_CSCOPE=0 ;;
	C) DO_CLEAN=1 ;;
	h) usage; exit 0 ;;
	*) usage >&2; exit 1 ;;
	esac
done

[[ $DO_CSCOPE -eq 1 || $DO_CTAGS -eq 1 ]] || die "-c 与 -t 不能同时使用"
cd "$SRC_DIR" || die "无法进入目录: $SRC_DIR"

if [[ $DO_CLEAN -eq 1 ]]; then
	clean
	exit 0
fi

start=$SECONDS
gen_file_list
[[ $DO_CSCOPE -eq 1 ]] && gen_cscope
[[ $DO_CTAGS -eq 1 ]] && gen_ctags

info "完成, 用时 $((SECONDS - start)) 秒, 输出目录: $(pwd)"
for f in "${CSCOPE_OUTPUTS[@]}" "${CTAGS_OUTPUTS[@]}"; do
	[[ -f "$f" ]] && ls -lh -- "$f"
done
exit 0
