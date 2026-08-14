<div align="center">

# DSH Island

**在 macOS 桌面上，用一个轻量“状态岛”查看所有 DeepSeek Harness 会话。**

[English](README.md)

<img src="docs/assets/dsh-island-desktop.png" width="900" alt="DSH Island 悬浮在隐私安全的合成开发工作区上方">

<sub>所有截图与录屏均使用固定合成会话，不包含个人桌面、路径、账号或真实对话。</sub>

</div>

当多个 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Agent 同时运行时，DSH Island 让你回到编辑器工作，同时持续看到哪些会话正在执行、哪些需要你处理、哪些刚刚完成。它是连接 DSH Web 公共接口的独立原生伴生应用，不会装入 Harness 进程，因此不需要添加 `cordis.yml` 配置；启动 DSH Web 后打开 DSH Island 即可协同工作。它是社区项目，不是 DeepSeek 官方产品。

<div align="center">
  <img src="docs/assets/dsh-island-demo.gif" width="900" alt="隐私安全演示：三个会话运行、一个会话请求处理、状态岛展开显示全部会话">
</div>

## 功能

- 汇总全部非空会话，实时显示“需要处理、失败、运行中、刚完成、空闲、离线”。
- 收起态仅保留全局结论与多会话信号轨；点击后展开完整列表。
- 显示审批、提问、后台任务、父子 Agent、耗时和当前活动。
- 只有 DSH 发布非空 Todo 投影时才显示确定性进度；其他运行不会编造百分比或 ETA。
- 点击会话可打开 DSH Web；配合可选的社区插件 [dsh-deeplink](https://github.com/qyw233/dsh-deeplink) 可精确定位到该会话。
- 支持悬浮窗位置记忆、所有 Space、菜单栏恢复入口、隐私模式和登录启动。

<div align="center">
  <img src="docs/assets/dsh-island-collapsed.png" width="400" alt="DSH Island 收起态">
</div>

## 安装

### 手动安装

1. 从 [最新 Release](https://github.com/ChuanTianML/dsh-island/releases/latest) 下载 `DSH-Island-0.1.0-macOS-universal.zip`。
2. 可同时下载旁边的 `.sha256` 文件，并执行 `shasum -a 256 -c DSH-Island-0.1.0-macOS-universal.zip.sha256` 校验。
3. 解压后将 **DSH Island.app** 移到“应用程序”。
4. 启动 DSH Web，再打开 DSH Island。默认连接 `http://127.0.0.1:3080`。

```sh
npx @deepseek-ai/dsh web

# 已全局安装 dsh 时：
dsh web

# 在 DeepSeek Harness 源码仓库中：
pnpm dsh web
```

0.1 版本使用 ad-hoc 签名，尚未经过 Apple 公证。首次启动时，macOS 可能要求按住 Control 点击应用并选择“打开”。发布包同时支持 Apple 芯片和 Intel Mac，最低系统版本为 macOS 13。

DSH 使用默认回环地址时无需配置。可从状态岛齿轮或菜单栏进入设置：

| 设置 | 用途 |
| --- | --- |
| DSH endpoint | 连接其他本地端口或可信 Host |
| Allow a non-loopback endpoint | 接受任何远程地址前必须显式开启 |
| Privacy mode | 匿名化标题并隐藏 Todo、工具名、错误和连接详情 |
| Launch at login | 注册为 macOS 登录项 |
| Reset island position | 恢复悬浮窗的默认显示器相对位置 |

默认只允许回环地址；非回环地址必须显式开启，并且只能连接你信任的 DSH Host。

### 使用 Coding Agent 安装

Coding Agent 可以完成下载、校验、安装、启动和界面配置。将下面提示词交给目标 Mac 上的 Agent：

```text
请在这台 Mac 上安装 DSH Island v0.1.0，Release 地址：https://github.com/ChuanTianML/dsh-island/releases/tag/v0.1.0。

1. 要求 macOS 13 或更高版本。下载 Universal ZIP 和对应 .sha256 文件，并用 shasum -a 256 -c 校验。
2. 检查 /Applications/DSH Island.app 是否已存在；覆盖已有安装前先询问我。
3. 将通过校验的应用移到 /Applications。不得绕过 Gatekeeper 或修改 macOS 安全设置；如果首次打开需要“Control 点击 → 打开”，把这一步交还给我。
4. 如果 DeepSeek Harness Web 尚未运行，执行 npx @deepseek-ai/dsh web。
5. 打开 DSH Island，通过设置界面保留默认 http://127.0.0.1:3080。开启非回环 endpoint 或修改隐私相关设置前先询问我。
6. 确认状态岛已经连接 DSH，并展示最终配置。不得收集或上传任何真实会话标题、路径、账号信息或个人桌面截图。
```

## 进度语义

DSH 没有为所有 Agent 任务提供统一百分比或 ETA，因此本项目明确区分“运行状态”和“任务进度”：

| 数据来源 | 展示方式 |
| --- | --- |
| `session.list` / `host/session-status` | 权威运行状态 |
| 非空 `todos` 投影 | 已完成数 / 总数与确定性进度轨 |
| 会话事件 | 推理、写作、编辑文件等描述性阶段 |
| 没有 Todo 投影 | 不确定性运行指示，不显示虚假百分比或 ETA |

连接正常时的优先级是“需要处理 → 失败 → 运行中 → 刚完成 → 空闲”；基线请求失败时，全局状态变为离线。

## 隐私与安全

- 首个版本完全只读，不会审批、回答、控制或编辑会话。
- 隐私模式在状态引擎输出前替换标题，并隐藏 Todo 文本、未知工具名、错误和连接细节。
- 工具参数不会进入展示状态。
- 不包含统计分析、遥测、云中继、凭据存储或模型上下文注入。

DSH 本身具备强大的 Agent 执行能力，不要把未经认证的 DSH Host 暴露到不可信网络。

## 开发

需要 macOS 13+，以及 Xcode 16 或兼容的 Swift 6 工具链。

```sh
swift test
swift build -c release -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
./scripts/build-app.sh
```

可在没有 DSH Host 的情况下运行确定性视觉演示：

```sh
swift run dsh-island --demo-working
swift run dsh-island --demo-expanded
```

仓库中的社区展示素材由同一组合成数据生成。运行 `./scripts/render-marketing-assets.sh` 可重新生成社交预览、桌面场景和 GIF 源帧；隐私规则见 [`docs/marketing/README.md`](docs/marketing/README.md)。

详细说明见[产品设计](docs/product-design.md)、[技术架构](docs/architecture.md)和 [0.1 本机验证记录](docs/validation.md)。项目使用 [MIT License](LICENSE)。
