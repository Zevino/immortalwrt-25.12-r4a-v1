# ImmortalWrt 25.12 · 小米路由器 4A 千兆版 V1 构建项目

> 目标设备：**小米路由器 4A 千兆版 V1（R4A V1 / 5G 射频 MT7612）**
> 源码分支：`openwrt-25.12`
> 目标平台：`ramips/mt7621`
> 设备标识：`xiaomi_mi-router-4a-gigabit`

这是一个"配置 + 脚本 + CI"的最小构建项目：不把 1 GB 的 ImmortalWrt 源码放进仓库，只保留设备配置、构建脚本和 GitHub Actions 工作流。首次构建时脚本会自动拉取源码。

---

## 一、先确认你的机型

| 机型 | 平台 | 设备标识 | 射频 | 能否用本项目 |
| --- | --- | --- | --- | --- |
| 4A 千兆版 **V1 / MT7612** | `ramips/mt7621` | `xiaomi_mi-router-4a-gigabit` | MT7603EN + MT7612EN | ✅ 本项目 |
| 4A 千兆版 **V2 / MT7613** | `ramips/mt7621` | `xiaomi_mi-router-4a-gigabit-v2` | MT7603EN + MT7613EN | ❌ 换设备标识 |
| 4A **百兆版** | `ramips/mt7628` | `xiaomi_mi-router-4a-100m` | MT7628 | ❌ 平台都不同 |

判断方法：

- 已经在跑 OpenWrt 的，执行 `cat /tmp/sysinfo/board_name`：
  - `xiaomi,mi-router-4a-gigabit` → 用本项目；
  - `xiaomi,mi-router-4a-gigabit-v2` → 改用 V2 配置。
- 看 `lspci` / `dmesg`：
  - 5G 是 **MT7612/MT7662**（PCI `14c3:7662`）→ 用本项目；
  - 5G 是 **MT7613/MT7663**（mt7615e 驱动）→ 用 V2 配置。
- 看机身标签/包装型号，千兆版通常标 **R4A Gigabit**；原厂固件名是 `miwifi_r4a_*.bin`。

> **重要：不要只凭机身写的“V1/V2”判断。**
> 小米的硬件批次命名和 OpenWrt 的设备标识并不总是一一对应。教程里那台机器机身是“V2 硬件”，但 5G 实测是 **MT7612**，所以它用的仍然是 `xiaomi_mi-router-4a-gigabit`（非 `-v2`）这个设备标识。
>
> **判断标准只有一条：5G 射频是 MT7612 还是 MT7613。** 刷错设备树/驱动的典型现象是启动后没有 5G，或者直接起不来。

---

## 二、项目结构

```text
immortalwrt-25.12-r4a-v1/
├─ README.md                       # 本文件
├─ Makefile                        # 常用命令包装
├─ .gitignore
├─ configs/
│  └─ r4a-v1.config                # 设备 + LuCI + 中文的种子配置
├─ scripts/
│  ├─ build.sh                     # 主构建脚本（Linux / WSL2）
│  ├─ install-deps.sh              # Ubuntu/Debian 依赖安装
│  └─ collect.sh                   # 收集固件与校验文件
├─ docker/
│  └─ Dockerfile                   # 可选：容器化构建环境
├─ docs/
│  └─ FLASH.md                     # 刷机与首启检查清单
└─ .github/
   └─ workflows/
      └─ build.yml                 # GitHub Actions 云端构建
```

源码、下载缓存和产物都被 `.gitignore` 忽略，不会污染仓库。

---

## 三、快速开始

### 方式 A：GitHub Actions（推荐，无需本地 Linux）

适合 Windows 用户，构建在 GitHub 的 Ubuntu 机器上完成。

1. 把本目录作为一个 Git 仓库推到 GitHub（仓库根目录就是本目录）：

   ```bash
   cd immortalwrt-25.12-r4a-v1
   git init -b main
   git add .
   git commit -m "ImmortalWrt 25.12 build for Xiaomi R4A V1"

   # 方式一：用 GitHub CLI 直接建仓库并推送
   gh repo create r4a-v1-immortalwrt --private --source . --push

   # 方式二：先在网页上建空仓库，再手动推送
   git remote add origin https://github.com/<你的用户名>/<仓库名>.git
   git push -u origin main
   ```

2. 打开仓库的 **Actions → Build ImmortalWrt 25.12 (R4A V1) → Run workflow**。
3. 等 2–4 小时（首次更久），在运行页面的 **Artifacts** 下载 `immortalwrt-25.12-r4a-v1-<运行编号>`。
4. 解压后得到 `*-sysupgrade.bin`、`sha256sums`、`*.manifest`、`config.buildinfo`。

工作流支持三个可选输入：

| 输入 | 默认值 | 说明 |
| --- | --- | --- |
| `branch` | `openwrt-25.12` | ImmortalWrt 分支 |
| `config` | `configs/r4a-v1.config` | 使用的配置文件 |
| `extra_packages` | 空 | 追加包名，空格分隔，如 `luci-app-zerotier zerotier` |

> GitHub 免费账户的 Actions 有额度限制；构建一次大约消耗 2–4 小时×核数的分钟数。公开仓库一般够用。

### 方式 B：WSL2 / Ubuntu 本地构建

要求：**Linux 文件系统**、4 核以上、8 GB 内存更稳、至少 25 GB 空闲磁盘。

```bash
# 1. 安装 WSL2（Windows PowerShell，管理员）
wsl --install -d Ubuntu-24.04

# 2. 进入 Ubuntu 后安装依赖
cd ~
git clone <你的仓库地址> immortalwrt-25.12-r4a-v1
cd immortalwrt-25.12-r4a-v1
chmod +x scripts/*.sh
./scripts/install-deps.sh

# 3. 一键构建
./scripts/build.sh
```

> **不要把项目放在 `/mnt/c/...` 下构建。** Windows 挂载盘大小写不敏感、IO 慢，OpenWrt 构建容易报奇怪错误。请放在 WSL 的 `~/` 下。

分阶段执行：

```bash
./scripts/build.sh prepare      # 拉源码、更新 feeds、生成 .config
./scripts/build.sh menuconfig   # 可选：图形化增删软件包
./scripts/build.sh download     # 预下载源码包
./scripts/build.sh build        # 编译
./scripts/build.sh collect      # 收集产物到 out/
./scripts/build.sh all          # 全流程（默认）
```

### 方式 C：Docker

```bash
docker build -t immortalwrt-builder:25.12 docker/

docker run --rm -it \
  -v "$PWD:/work" \
  -w /work \
  immortalwrt-builder:25.12 \
  bash scripts/build.sh all
```

Windows 上建议在 WSL2 里执行上面的命令，并把项目放在 WSL 文件系统，避免把源码树放在 `/mnt/c`。

---

## 四、配置说明

### 1. 种子配置做了什么

`configs/r4a-v1.config` 只做四件事：

```text
选定 ramips/mt7621 + xiaomi_mi-router-4a-gigabit
启用 squashfs 固件
装上 LuCI、防火墙、包管理器
装上中文语言包和少量排障工具（curl / htop / nano）
```

其余选项交给 `make defconfig` 按官方默认值补齐。这样升级分支时不容易因为某个符号消失而整份配置失效。

### 2. 追加软件包

临时追加（推荐，不修改仓库文件）：

```bash
EXTRA_PACKAGES="luci-app-zerotier zerotier" ./scripts/build.sh
```

或者在 GitHub Actions 的 `extra_packages` 输入里填同样的内容。

脚本会把它们转成 `CONFIG_PACKAGE_<包名>=y`，再执行 `make defconfig`。如果包不存在或依赖冲突，`defconfig` 会给出提示。

### 3. 用 menuconfig 精细调整

```bash
./scripts/build.sh prepare
./scripts/build.sh menuconfig
```

保存退出后，把最终配置导出，方便下次复现：

```bash
cd source
./scripts/diffconfig.sh > ../configs/r4a-v1.applied.config
```

`diffconfig.sh` 只输出与默认值不同的项，比直接复制 `.config` 干净得多。

### 4. 16 MB Flash 的硬约束

R4A 的固件分区上限是 **14848 KB**（`IMAGE_SIZE := 14848k`）。超了会在打包阶段报 `check-size` 错误。控制体积的建议：

- 不要装 `luci-app-*` 全家桶，尤其是代理、Docker、Python 类；
- 优先用 `-nodeps` 的精简包，或自己编译裁剪；
- 用 `make menuconfig` 关掉不需要的协议、调试工具；
- 真要装很多插件，考虑外挂 U 盘做 overlay，而不是硬塞进 16 MB。

---

## 五、构建产物

构建完成后，`out/` 下会有：

| 文件 | 用途 |
| --- | --- |
| `*xiaomi_mi-router-4a-gigabit*squashfs-sysupgrade.bin` | 刷机主文件（breed / 系统内升级都用它） |
| `sha256sums` | 所有产物的校验值 |
| `*.manifest` | 固件内软件包清单 |
| `config.buildinfo` | 本次构建的完整配置，排障/复现用 |
| `config.applied` | `diffconfig` 导出的非默认配置 |

刷机前先校验：

```bash
sha256sum -c sha256sums --ignore-missing
```

Windows 下可用 7-Zip 计算 SHA-256，和 `sha256sums` 里的值比对。

---

## 六、刷机流程（breed）

> 完整背景和原理见同目录《小米路由器 4A 千兆版刷 OpenWrt 完整教程》，这里只给最短路径。

### 前置条件

1. 已经装好 **breed**，能进 `http://192.168.1.1`；
2. 已有整片 Flash 备份（`all_backup.bin`，16 MB）和原厂 `Factory.bin`；
3. 电脑用**网线**直连路由器 LAN 口；
4. 刷机过程中**不断电、不拔线**。

### 步骤

1. 断开路由器 WAN 口，只保留电脑到 LAN 口；
2. 按住复位键上电，或重启时快速点按复位键，进入 breed；
3. 浏览器打开 `http://192.168.1.1` → **固件更新**；
4. 选择 `*-sysupgrade.bin`；
5. 首次从原厂/其他固件过来，建议**不保留配置**（避免旧配置把网络带偏）；
6. 点击刷写，等待 2–5 分钟，指示灯稳定后访问 `http://192.168.1.1`。

### 首启检查

```sh
cat /tmp/sysinfo/board_name          # 应为 xiaomi,mi-router-4a-gigabit
cat /proc/mtd                         # 确认分区表
dmesg | grep -iE 'eeprom|mt76'        # 不应有 EEPROM data check failed
iwinfo                                # 看 2.4G/5G 是否都出现、发射功率是否正常
df -h /overlay                        # 看可写空间
```

如果 5G 只有 **3 dBm**、MAC 每次重启都变，说明 `factory` 校准区不对，按教程第 11.3 节回写原厂 `Factory.bin`。

### 默认登录

ImmortalWrt 官方默认：

- 地址：`http://192.168.1.1` 或 `http://immortalwrt.lan`
- 用户：`root`
- 密码：**空**（首次登录后立即设置）

第三方构建可能改成 `root/root` 或 `root/password`，以实际固件为准。

---

## 七、常见问题

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 打包报 `check-size` 超限 | 软件包装太多 | 减少包，或改外挂 overlay |
| `make defconfig` 警告某符号不存在 | 分支改了包名/选项 | 用 `menuconfig` 重新选，或删掉该行 |
| 下载失败 | 网络/镜像问题 | 重跑 `make download -j1 V=s`，或配代理 |
| 编译报 `ccache` 相关错误 | 没装 ccache 但开了 `CONFIG_CCACHE` | 安装 ccache 或关掉该选项 |
| 刷完没有 5G | 刷了 V2 固件 / factory 校准损坏 | 核对设备标识；回写 Factory.bin |
| 刷完无限重启 | 固件与硬件不匹配 | 回 breed 重刷 V1 固件 |
| 断电后不进系统 | breed autoboot 地址不对 | 设 `autoboot.command = boot flash 0x180000` |
| 默认密码不对 | 第三方构建改了默认值 | 查固件发布说明，或 breed 重刷 |

---

## 八、版本与可复现性

- 分支 `openwrt-25.12` 会持续更新，构建结果不是逐字节可复现的；
- 需要固定版本时，在 `scripts/build.sh` 里设置 `SOURCE_COMMIT=<commit>`，或在 CI 中把分支改成 tag/commit；
- 每次构建都会把 `config.buildinfo` 和 `config.applied` 收进产物，建议和固件一起归档。

---

## 九、参考

- ImmortalWrt 源码：https://github.com/immortalwrt/immortalwrt/tree/openwrt-25.12
- 设备支持列表：https://openwrt.org/toh/xiaomi/xiaomi_mi_router_4a_gigabit_edition
- 固件选择器：https://firmware-selector.immortalwrt.org/
- 同目录教程：`../小米路由器4A千兆版刷OpenWrt完整教程.md`
- 刷机清单：`docs/FLASH.md`

---

> **免责声明**：刷机有变砖风险。请先完成整片 Flash 与 factory 分区备份，再动手；因操作不当造成的损失由操作者自行承担。
