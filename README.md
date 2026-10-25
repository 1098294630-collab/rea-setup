# REA 一键安装

[REA](https://morluto.github.io/rea/zh-CN/)（`rea-agents`）是给编程助手用的逆向工程工具包。这个仓库只做一件事：把安装步骤收成一条命令，顺手把你最可能踩的 Node 版本坑填掉。

不是官方仓库。上游在 [morluto/rea](https://github.com/morluto/rea)。

## Windows

先把下面地址里的 `USER` 换成这个仓库所属的用户名。

```powershell
irm https://raw.githubusercontent.com/USER/rea-setup/main/install.ps1 | iex
```

国内网络加镜像参数：

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/USER/rea-setup/main/install.ps1))) -Mirror npmmirror
```

脚本做的事：

1. 查 `node`，版本够就直接用，不够就下 Node 24.22.1 解压到 `%LOCALAPPDATA%\Programs\node-v24.22.1`，不碰系统 Node
2. `npm install -g rea-agents`
3. `rea doctor` 自检
4. 跑 `rea setup` 让你选要接入的编程助手

## macOS / Linux

```sh
curl -fsSL https://raw.githubusercontent.com/USER/rea-setup/main/install.sh | sh
```

没有 Node 或版本太旧时用 fnm 装 Node 24，然后装 REA 并进入 setup。

## 只想手动装

```sh
node -v                                             # 22.23.4+ / 24.22.1+ / 26.12.1+
npm install --global rea-agents
rea setup
```

## Node 版本要求

| 大版本 | 最低 |
|---|---|
| 22 | 22.23.4 |
| 24 | 24.22.1 |
| 26 | 26.12.1 |

低于这个数，`rea setup` 会直接拒绝执行并打印 remediation。这是最容易卡住的一步。

## 常见问题

**PowerShell 报「禁止运行脚本」**
把 `npx` 换成 `npx.cmd`，`npm` 换成 `npm.cmd`。这是 npm 全局 shim 的签名策略，跟 REA 无关。

**`rea setup` 装 skill 时报 EPERM**
某些受限环境里 node 子进程写不了 `%USERPROFILE%`。手动把包里的 `skills/reverse-engineer-anything` 整个目录复制到 `%USERPROFILE%\.agents\skills\` 即可，然后 `rea doctor` 应显示 `state: aligned`。

**原生反编译用不了**
需要自带 Ghidra / IDA / JADX / Kuna 之一，REA 不会替你装：

```powershell
$env:GHIDRA_INSTALL_DIR = "C:/tools/ghidra_12.1.4_PUBLIC"
$env:JAVA_HOME = "C:/tools/jdk-21"
```

静态 JavaScript、ASAR、PE/.NET、SQLite、固件、被动 Web 抓取都不需要引擎。

## 链接

- 官网（中文）：https://morluto.github.io/rea/zh-CN/
- 安装指南（中文）：https://morluto.github.io/rea/zh-CN/get-started/
- 源码：https://github.com/morluto/rea
- npm：https://www.npmjs.com/package/rea-agents
- Node.js：https://nodejs.org/zh-cn/download
- 示例包：https://rea.tools/examples/notes-example.zip

MIT。REA 本身按上游许可分发。
