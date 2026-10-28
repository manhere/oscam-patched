# OSCam (patched fork)

## About this fork

本仓库的源码上游为 [OSCam 官方仓库](https://git.streamboard.tv/common/oscam)
（git.streamboard.tv GitLab），在源码树上应用了第三方补丁集：

- **上游对齐点**：`39e78a4688b30abaab62b5c9e13672b4e34bfca0`
  （master，2026-09-29，对应 CS_VERSION 2.26.09-11968）

- **补丁来源**：[HiSilicon-Development/oscam-patch](https://github.com/HiSilicon-Development/oscam-patch)
  （含 Hi3798 系列 SCI 读卡器驱动 `ifd_sci.c`、国产 CA 支持等修改）

在上游 + 补丁的基础上，本仓库额外移植了国产 CA 卡系统读卡支持
（移植自 [nx111/oscam](https://github.com/nx111/oscam)）：

- **Tongfang**（同方）：`reader-tongfang.c`，`cas_version` 可配置
- **StreamGuard**（数码视讯）：`reader-streamguard.c`
- **Jet / DVN**：`reader-jet.c`（含 `cscrypt/jet_twofish`、`cscrypt/jet_dh`）

启用方式：`./config.sh --enable READER_TONGFANG READER_STREAMGUARD READER_JET`。

构建产物由 GitHub Actions 自动编译发布，每次成功构建都会发布/更新当天日期的
`build-YYYYMMDD` Release，只出 **arm64** 一个平台：

- `oscam-linux-arm64`：aarch64，**全静态链接**（无 NEEDED，任意 glibc 可运行）
- `oscam_<ver>_arm64.deb`：同一套程序与默认配置的 Debian 包，安装到
  `/usr/local/bin/oscam`、`/usr/local/etc/oscam.*`、
  `/lib/systemd/system/oscam.service`；四个 `oscam.*` 标记为 conffile，
  升级时保留本地改动。

二进制是全静态的，因此 deb 不带任何 `Depends`（`dpkg -i` 不需要先装运行库）。

deb 由 `packaging/deb/build-deb.sh` 生成，可脱离 CI 本地运行：

```sh
bash packaging/deb/build-deb.sh --arch arm64 --binary build/oscam --output dist
```

安装：`sudo dpkg -i oscam_<ver>_arm64.deb`（postinst 会 `daemon-reload`、
`enable` 并启动服务）。

### 配置文件的覆盖规则

四个 `oscam.*` 都是 conffile，`dpkg` 的行为分两种，直接决定装完之后用的是哪份
配置（以及 WebIf 密码）：

- **升级**（已装过本包）：`dpkg` 比较 md5，**保留你改过的本地文件**，包里的新版
  本会落到 `*.dpkg-dist` 供对比。想强制用包内默认值加 `--force-confnew`，
  想显式保留加 `--force-confold`：
  ```sh
  sudo dpkg --force-confnew -i oscam_<ver>_arm64.deb   # 用包里的配置覆盖
  sudo dpkg --force-confold -i oscam_<ver>_arm64.deb   # 保留现有配置
  ```
- **首次安装**：`/usr/local/etc` 下若已有 `install.sh` 或手工放的配置，`preinst`
  会先原样备份成 `<文件名>.pre-deb`（已存在则不覆盖，保留最早那份），随后
  `dpkg` 才会写入包内配置。备份文件不会被 `purge` 删除，需自行清理。

包内默认的 WebIf 账号是 `oscam` / `oscam`（`/usr/local/etc/oscam.conf` 的
`httpuser` / `httppwd`）。装完发现密码不是它，先确认磁盘上那份配置与包内是否
一致：

```sh
dpkg-query -W -f='${Conffiles}\n' oscam    # 包记录的 md5
md5sum /usr/local/etc/oscam.conf           # 实际文件的 md5
ss -lntp | grep 8888                       # 有没有别的 oscam 占着端口
```

## About upstream OSCam

OSCam: Open Source Conditional Access Module.

- Upstream repository: [git.streamboard.tv/common/oscam](https://git.streamboard.tv/common/oscam)
- Wiki: [https://git.streamboard.tv/common/oscam/-/wikis/home](https://git.streamboard.tv/common/oscam/-/wikis/home)

## Building & Dependencies

For detailed information about building OSCam, cross-compilation for
different CPUs, required and optional dependencies, SSL support, hardware
modules, and platform-specific or distribution-specific notes, please
refer to the OSCam wiki:

- [Wiki Home](https://git.streamboard.tv/common/oscam/-/wikis/home)

## License

OSCam: Open Source CAM

Copyright (C) 2009-2026 OSCam developers

OSCam is based on the Streamboard mp-cardserver 0.9d by dukat and has been
extended and worked on by many more since then.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program. If not, see <https://www.gnu.org/licenses/>.

For the full text of the license, please see the
[COPYING](COPYING)
file in the source tree.
