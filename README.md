# OSCam (patched fork)

## About this fork

本仓库的源码上游为 [OSCam 官方仓库](https://git.streamboard.tv/common/oscam)
（git.streamboard.tv GitLab），在源码树上应用了第三方补丁集：

- **补丁来源**：[HiSilicon-Development/oscam-patch](https://github.com/HiSilicon-Development/oscam-patch)
  （含 Hi3798 系列 SCI 读卡器驱动 `ifd_sci.c`、国产 CA 支持等修改）

在上游 + 补丁的基础上，本仓库额外移植了国产 CA 卡系统读卡支持
（移植自 [nx111/oscam](https://github.com/nx111/oscam)）：

- **Tongfang**（同方）：`reader-tongfang.c`，`cas_version` 可配置
- **StreamGuard**（数码视讯）：`reader-streamguard.c`
- **Jet / DVN**：`reader-jet.c`（含 `cscrypt/jet_twofish`、`cscrypt/jet_dh`）

启用方式：`./config.sh --enable READER_TONGFANG READER_STREAMGUARD READER_JET`。

构建产物由 GitHub Actions 自动编译发布（Linux x64 / arm64 全静态链接），
每次成功构建都会发布/更新当天日期的 `build-YYYYMMDD` Release。

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
