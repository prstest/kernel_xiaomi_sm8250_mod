#!/bin/bash

# 定义颜色
YELLOW='\033[1;33m'  # 黄色
RED='\033[1;31m'     # 红色
GREEN='\033[1;32m'   # 绿色
BLUE='\033[1;34m'    # 蓝色
NC='\033[0m'         # 无颜色

# 在这里修改内核和 KernelSU 目录路径
KERNEL_DIR="."  # 请修改为你的内核目录路径
KERNELSU_DIR="./KernelSU-Next"  # 请修改为你的 KernelSU 目录路径
KernelSU_SETUP="https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh"

# 输出开始信息
echo -e "${YELLOW}警告: 此脚本仅为 4.19 内核提供，其他内核版本使用不保证成功${NC}"
echo -e "${GREEN}开始为内核添加 SUSFS ...${NC}"

# 验证路径是否存在
echo -e "${GREEN}检查内核目录是否存在: ${KERNEL_DIR}${NC}"
if [ ! -d "$KERNEL_DIR" ]; then
    echo -e "${RED}错误: 内核目录不存在!${NC}"
    exit 1
fi

echo -e "${GREEN}检查 KernelSU 目录是否存在: ${KERNELSU_DIR}${NC}"
if [ ! -d "$KERNELSU_DIR" ]; then
    echo -e "${RED}错误: KernelSU 目录不存在!${NC}"
    echo -e "${GREEN}正在为内核增加 KernelSU 中...${NC}"
    curl -LSs $KernelSU_SETUP | bash - > /dev/null 2>&1
    echo -e "${GREEN}已为内核增加 KernelSU${NC}"
fi

# 克隆 susfs4ksu 仓库，获取适用于 kernel-4.19 的补丁
echo -e "${GREEN}克隆 susfs4ksu 仓库...${NC}"
git clone https://gitlab.com/simonpunk/susfs4ksu.git --depth=1 --branch=kernel-4.19 > /dev/null 2>&1

# 将所需的补丁和文件复制到内核源代码目录
echo -e "${GREEN}复制补丁文件到内核目录...${NC}"
cp susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch "${KERNELSU_DIR}/"
cp susfs4ksu/kernel_patches/50_add_susfs_in_kernel-4.19.patch "${KERNEL_DIR}/"
cp susfs4ksu/kernel_patches/fs/* "${KERNEL_DIR}/fs/"
cp susfs4ksu/kernel_patches/include/linux/* "${KERNEL_DIR}/include/linux/"

# 进入 KernelSU 目录并应用 KernelSU 补丁
echo -e "${GREEN}进入 KernelSU 目录并应用 KernelSU 补丁...${NC}"
cd "${KERNELSU_DIR}"
patch -p1 < 10_enable_susfs_for_ksu.patch > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}错误: KernelSU 补丁应用失败！请检查 ${KERNELSU_DIR} 目录中的 .rej 文件${NC}"
fi

# 返回内核源代码目录并应用 Kernel 补丁补丁
echo -e "${GREEN}返回内核目录并应用 Kernel 补丁补丁...${NC}"
cd ../
patch -p1 < 50_add_susfs_in_kernel-4.19.patch > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}错误: Kernel 补丁补丁应用失败！请检查 ${KERNEL_DIR} 目录中的 .rej 文件${NC}"
fi

# 检查 .rej 文件并列出失败的文件（输出相对路径）
echo -e "${GREEN}检查补丁失败的文件...${NC}"
rej_files=$(find "${KERNEL_DIR}" -type f -name "*.rej")
if [ -n "$rej_files" ]; then
    echo -e "${RED}发现以下补丁失败的文件：${NC}"
    for file in $rej_files; do
        relative_path=$(realpath --relative-to="${KERNEL_DIR}" "$file")
        echo -e "${BLUE}补丁失败的文件: ${relative_path}${NC}"
    done
    echo -e "${RED}这些文件的内容无法应用补丁，请手动修复。${NC}"
else
    echo -e "${GREEN}所有补丁成功应用，没有发现 .rej 文件。${NC}"
fi

