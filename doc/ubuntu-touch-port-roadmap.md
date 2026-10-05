# GasTube Ubuntu Touch 移植路线

日期：2026-10-01  
基线：GasTube `0.9.3+16`、Flutter `3.47.1`

## 结论

GasTube 不应以 Android APK 或 Libertine 桌面应用的方式移植到 Ubuntu Touch。建议复用现有 Flutter Linux/GTK3 目标，产出 arm64 Linux bundle，再用 Clickable 封装为受 AppArmor 约束的 Click 包。

这条路线可行，但“Linux arm64 能启动”不等于“Ubuntu Touch 端口完成”。真正的高风险项依次是：

1. Flutter 3.47.1 的 Linux arm64 构建产物和 Ubuntu Touch ABI；
2. Mir/Wayland 下 `media_kit` 的 OpenGL ES 纹理和 libmpv 播放；
3. Click 沙箱内启动 Java sidecar 与 FFmpeg；
4. 应用退到后台后，libmpv 播放会被 Ubuntu Touch 生命周期管理暂停；
5. Content Hub、URL Dispatcher、通知、软键盘等平台集成。

第一版应定义为“前台播放器”：浏览、搜索、订阅、收藏、历史、前台播放和应用私有目录下载可用。后台播放、系统媒体控制、系统级画中画、Cast 和后台订阅检查不应阻塞首个可测试包。

## 当前代码中可直接复用的部分

- Linux GTK3 runner 已存在，bundle 使用相对 RPATH `$ORIGIN/lib`（`linux/CMakeLists.txt`）。
- Linux arm64 已进入本地构建脚本的架构分支，JRE 与 FFmpeg 的打包脚本也识别 aarch64（`packaging/linux/`、`packaging/java/bundle-runtime.sh`、`packaging/ffmpeg/bundle-ffmpeg.sh`）。
- NewPipe 在非 Android 平台通过长驻 JVM sidecar 工作（`lib/infrastructure/newpipe/newpipe_sidecar.dart`），不需要在 Ubuntu Touch 上移植 Android Kotlin MethodChannel。
- Linux/Windows 的 libmpv 硬件纹理、全屏和播放器生命周期已有实际修复；Ubuntu Touch 可以从这条路径起步，而不是重新写播放器。
- Drift/SQLite、HTTP 后端、SponsorBlock、资料库、配置和多 profile 都是 Dart 或已有 Linux 插件能力。
- 桌面/横屏 UI 已经落地，而不再只是可行性文档：
  - 720 logical px 起使用侧栏；
  - 720/1100 px 对应 2/3 列卡片；
  - 1000 px 起使用 70/30 watch split。
  断点集中在 `lib/core/window_layout.dart`，窄屏仍使用手机布局。这与 Ubuntu Touch 的手机、横屏和 convergence 外接屏场景相容。
- Linux 上亮度手势已经禁用，音量插件找不到 ALSA mixer 时不会再崩溃。
- sidecar 已限制为只保留一个视频的 `StreamInfo`，并清理 NewPipe throttling cache；这对内存受限设备很重要。

## 目标矩阵

### 首要目标：OnePlus 6T / Ubuntu Touch 20.04

现有 Linux 手机测试目标是 OnePlus 6T（arm64）。截至本文日期，UBports 为该设备提供稳定的 Ubuntu Touch 20.04/Focal，而 24.04/Noble 端口尚未可用。因此：

- 首个真机包以 Focal framework 为准；
- 不把升级 6T 到 Noble 作为 GasTube 任务的一部分；
- 设备恢复、Halium 和 Noble 设备移植不属于本路线。

### 次要目标：Ubuntu Touch 24.04-1.x

在一台已正式支持 Noble 的 arm64 设备上建立第二条验证轨道。Focal 与 Noble 应分别构建和测试，不能假设一个二进制包同时兼容两套系统 ABI。新设备和 OpenStore 长期发布以 Noble 为主。

### 开发目标：amd64 桌面模拟

`clickable desktop` 和普通 Linux 桌面只用于快速验证 UI、AppArmor 配置和资源布局，不能替代真机验证以下项目：

- Maliit 软键盘；
- Mir/Wayland GLES 纹理；
- 音频路由、蓝牙与耳机拔出；
- 应用 suspend/resume；
- Content Hub 与 URL Dispatcher；
- 触摸、旋转、安全区和 display cutout。

## 建议目录和边界

新增 `packaging/ubuntu-touch/`，不要把 Click 配置混入 Flatpak 或通用 Linux 包：

```text
packaging/ubuntu-touch/
├── clickable.yaml
├── manifest.json.in
├── gastube.apparmor.in
├── gastube.desktop.in
├── gastube.url-dispatcher
├── gastube-contenthub.json
├── launcher.sh
├── build-bundle.sh
└── README.md
```

平台差异应集中在一个 Dart 能力层，例如 `UbuntuTouchCapabilities`，通过编译时 define 或可靠的运行时标识启用。不要把 Ubuntu Touch 等同于所有 `Platform.isLinux`，否则会破坏 Flatpak、deb/rpm 和普通桌面 Linux。

建议使用：

```text
--dart-define=GASTUBE_UBUNTU_TOUCH=true
```

该标识控制窗口外观、通知、下载导出、链接接入、后台能力和默认画质；播放器底层仍走 Linux/media_kit 分支。

## 分阶段路线

### Phase 0：构建与依赖探针

目标：在改业务代码前回答“能否稳定产出可安装的 arm64 Click”。

工作：

1. 固定 Flutter 3.47.1、Dart、Clickable 和构建容器版本。
2. 在 Ubuntu 20.04 arm64 容器里执行 `flutter build linux --release`。当前 Flutter 不支持从 Linux x64 主机交叉构建 Linux arm64。容器运行在 Apple Silicon 的 Docker 上，使用原生 `linux/arm64`，不使用 qemu。不要在 glibc 高于 2.31 的系统上直接编译，否则 runner 无法在 Focal 测试机上加载。官方 `libflutter_linux_gtk.so`、`gen_snapshot` 和 arm64 Dart SDK 本身只要求到 `GLIBC_2.18`。
3. 记录 Flutter arm64 engine artifact 的下载结果；如果 3.47.1 的官方 artifact 不可用，先冻结到最后一个可复现的 engine artifact，或在 CI 中自建 engine。不能静默改用另一个 Flutter 版本。
4. 分别对 Focal 与 Noble 建立 sysroot/容器实验，检查 `glibc`、GTK3、libstdc++、SQLite 插件和 Flutter engine 的动态依赖。
5. 先构建一个只显示版本和架构的最小 Click，验证安装、启动、旋转、触摸和 suspend/resume。

完成标准：

- `clickable build --arch arm64` 或“arm64 Linux bundle + precompiled Click 封装”可重复运行；
- Clickable review 通过；
- 真机冷启动、恢复前台和退出不崩溃；
- `readelf`/`ldd` 清单中没有来自构建主机的意外绝对路径。

若这一阶段失败，应停止播放器工作，先解决 Flutter engine/ABI，不要用 Libertine 规避。

### Phase 1：Click 壳与基本应用启动

目标：完整 GasTube UI 在真机启动，NewPipe 尚可临时关闭。

工作：

- 使用 Clickable `custom` 或 `precompiled` builder 安装 Flutter bundle；
- manifest 使用 `@CLICK_ARCH@`、`@CLICK_FRAMEWORK@`，AppArmor 使用 `@APPARMOR_POLICY@`；
- 初始策略只申请实际需要的 common groups：`networking`、`audio`、`keep-display-on`；开始做导入/导出时再加 `content_exchange`/`content_exchange_source`；
- launcher 设置 bundle 内的 `LD_LIBRARY_PATH`、JRE、FFmpeg 和 GTK 输入法环境；
- Ubuntu Touch 下不创建桌面式 1280×720 窗口和 header bar，交给 Lomiri 管理全屏应用表面，并允许纵横屏；
- 将 Linux runner 当前的 `G_APPLICATION_NON_UNIQUE` 改为 UT 下单实例激活，否则 URL Dispatcher 可能为每个链接启动一个 GasTube 进程；
- 集成 GTK3 Maliit input module。Ubuntu Touch 的 GTK3 应用不能依靠现有系统环境自动弹出软键盘；
- 对不支持的桌面插件做显式 capability gate，消除启动阶段的 `MissingPluginException`。

完成标准：

- 首页、设置、搜索框和数据库在真机可用；
- 软键盘可输入中文和英文，关闭后焦点正确；
- 纵屏、横屏、锁屏恢复和窗口尺寸变化不丢路由；
- 窄屏保留 bottom navigation，外接宽屏触发已有侧栏和多列布局。

### Phase 2：NewPipe sidecar

目标：在 Click 沙箱内完成首页、搜索、频道和 watch info 提取。

工作：

- bundle `newpipe-spike.jar` 和 arm64 Java 17 runtime；
- 用 `jdeps` + `jlink` 生成最小 runtime，避免直接携带完整 JRE；
- 验证 AppArmor 下子进程执行、stdin/stdout UTF-8、DNS、TLS 证书和进程退出；
- 将 sidecar 路径固定在 Click 安装目录，不依赖当前工作目录或系统 `java`；
- 加入 JVM 内存上限并实测，例如从 `-Xms16m -Xmx160m` 起调；上限必须由测试决定，不能只看桌面 RSS；
- sidecar 异常退出时允许一次受控重启，并向 UI 返回可诊断错误；
- 保留 Piped/Invidious 作为故障回退，但不以公共实例可用性作为发布门槛。

完成标准：

- 连续浏览 30 个首页/搜索/频道页面和打开 20 个不同视频信息，sidecar 无持续线性增长；
- 应用退出后 Java 子进程消失；
- 断网、切 Wi-Fi/蜂窝网络和服务器超时不会卡死 UI；
- 中文标题、评论和相关视频 UTF-8 正常。

### Phase 3：libmpv 前台播放

目标：前台播放成为首个技术里程碑。

工作：

- 将 libmpv 及其非系统依赖打进 Click，不能假设设备 rootfs 安装了 `libmpv-dev` 或兼容 soversion；
- 从 Flatpak 的裁剪配置复用思路，针对 arm64 构建最小 FFmpeg/libass/libmpv；
- 首先使用 PulseAudio 输出；不要直接访问 ALSA 硬件；
- 验证 vendored `media_kit_video` 在 Mir/Wayland 的 Flutter GLES context 上创建和更新纹理；
- 分别测试软件解码和 `hwdec=auto`。桌面 VA-API 成功不能证明 Qualcomm/Adreno 上存在可用硬解路径；
- 初版将 UT 默认画质限制为 720p，1080p 和更高画质在性能探针通过后开放；4K 不作为手机验收项；
- Ubuntu Touch 下禁用桌面“整窗全屏设置”，播放器全屏只改变 Flutter 页面和系统方向/沉浸状态；
- 验证来电、锁屏、耳机拔出、蓝牙切换和应用恢复。

完成标准：

- NewPipe 360p muxed、720p video+audio、直播各连续播放 20 分钟；
- 画面无黑纹理、旋转后不丢画面，切画质不崩溃；
- 音画同步、seek、字幕、SponsorBlock 和原始音轨选择可用；
- 720p 播放 30 分钟不触发 thermal shutdown，内存不超过为目标设备设定的预算；
- 连续打开 20 个不同视频后，记录 Flutter、libmpv 和 Java RSS。现有 libmpv 每 URL 保留内存的问题必须作为发布门槛观察，而不是视为已解决。

### Phase 4：手机交互与 convergence

目标：使现有手机/桌面自适应 UI 真正适配 Lomiri。

工作：

- 对 notch、底部手势区和系统面板使用 `SafeArea`/view padding；
- 确认横屏手机仍保持手机导航，不因 orientation 直接切 rail；
- 检查播放器按钮最小触控尺寸、滚动冲突、双击 seek 和下滑小窗手势；
- 窄屏 watch page 保持单列；外接屏跨 1000 px 时播放器使用稳定 key，不重启播放；
- 为鼠标、触摸板和键盘补最低限度的 focus/hover/快捷键，但不把完整桌面快捷键作为首发条件；
- Shorts 需要单独做性能和手势验收，未通过时可在首个测试包隐藏入口。

完成标准：

- 6T 纵横屏完整走通首页、搜索、watch、评论、频道、设置；
- 外接屏/窗口化环境走通 720/1000/1100 三个断点；
- 跨断点 resize 不重启播放器、不丢评论位置。

### Phase 5：下载、导入导出与链接

目标：遵守 Ubuntu Touch confinement，而不是复用桌面的 `xdg-open` 和任意文件路径。

工作：

- 第一阶段下载到应用私有 writable data 目录；
- 实测 `path_provider`/`persistentAppDirectory` 在 Click confinement 下解析到应用自己的 data/cache 路径，并覆盖旧 Documents 数据迁移的无权限场景；
- bundle arm64 FFmpeg，继续复用现有 stream-copy mux；
- 用 Content Hub 实现“导出到 Videos/Music”“打开完成文件”“备份导入/导出”和分享；
- Ubuntu Touch 下禁用 `xdg-open`、桌面 file picker 和假定公共 Downloads 可写的路径；
- 为 `youtu.be`、`youtube.com/watch`、shorts、playlist 和 channel 注册 URL Dispatcher；
- runner 已将启动参数传入 Dart entrypoint，但当前 `DeepLinkHandler` 没有解析 Ubuntu Touch `%u` 启动参数。新增平台 adapter，同时处理冷启动参数和运行中链接；
- 分享接收和分享发送走 Content Hub，不能依赖 `receive_sharing_intent`/`share_plus` 的 Android/iOS 实现。

完成标准：

- 360p 与 720p 下载、合并、暂停/恢复、失败清理通过；
- 导出的视频可由系统播放器打开；
- GasTube 可从浏览器链接冷启动，也可在运行中接收第二个链接；
- NewPipe ZIP 备份可经 Content Hub 导入和导出。

### Phase 6：后台音频、媒体控制与通知

目标：在系统允许的生命周期模型中提供可靠能力。

现状不能直接复用：

- `audio_service` 当前主要配置 Android notification，Linux 初始化失败只会降级；
- `flutter_local_notifications` 的业务对象只构造 Android/iOS details；
- `SubscriptionNotifier.isSupported` 明确只允许 Android/iOS；
- Ubuntu Touch 会暂停失焦应用，仅申请 `audio` AppArmor group 不能保证任意 libmpv 子线程持续运行。

工作顺序：

1. 先做 MPRIS/系统 sound indicator 元数据与 play/pause/seek。
2. 调研并实现 media-hub bridge；验证屏幕关闭、切应用和锁屏后的单视频音频。
3. 若 media-hub 无法接管现有双 URL（视频+音频）流，后台模式应显式切到单音频 URL，而不是让隐藏视频继续解码。
4. 再实现本地下载完成通知；订阅更新使用 Ubuntu Push helper 或保持“仅回到前台检查”，不能依赖常驻后台轮询。
5. 没有可靠系统生命周期集成前，UI 不宣称支持后台播放。

完成标准：

- 锁屏和切到其他应用 30 分钟不间断播放；
- sound indicator 显示标题/封面并控制播放；
- 耳机拔出暂停；
- 应用被系统暂停或终止时不留下 Java、FFmpeg 或播放器孤儿进程；
- OpenStore 对所申请 policy groups 审核可接受。

### Phase 7：发布工程

工作：

- CI 使用原生 arm64 runner 构建 Flutter Linux bundle；x64 runner 只做 analyze/test 和 amd64 smoke test；
- Focal 与 Noble 使用独立矩阵、独立 Click artifact 和设备测试报告；
- 固定并记录 Flutter engine、JRE、NewPipe Extractor、FFmpeg、libmpv 的版本和校验和；
- 生成第三方许可证清单；
- 运行 `clickable review`，随后在 OpenStore beta channel 发布；
- 收集诊断时默认脱敏 URL token、路径和用户资料；Debug 页面导出日志也走 Content Hub。

发布门槛：

- 至少一台 Focal 6T 和一台受支持 Noble arm64 设备完成核心矩阵；
- 无 P0 崩溃、数据损坏或孤儿进程；
- 30 分钟播放和 20 视频切换内存门槛通过；
- 包可从全新安装升级且 Drift 数据保留；
- OpenStore 页面明确列出首版缺失能力。

## 建议的首版功能边界

### 必须有

- NewPipe 首页、搜索、频道、播放；
- 纵横屏 UI、评论、订阅、收藏、历史；
- 360p/720p、字幕、音轨、SponsorBlock；
- 应用私有目录下载和 Content Hub 导出；
- YouTube URL Dispatcher；
- 断网与 sidecar 错误可恢复。

### 可延后

- Piped/Invidious/Explode 的完整对等验证；
- 1080p60/1440p/4K；
- 后台视频和系统 PiP；
- Cast；
- 后台订阅轮询；
- 下载进度系统通知；
- 桌面式整窗全屏、close-to-tray 和窗口记忆。

## 主要风险与回退

### Flutter Linux arm64 工具链

Flutter 3.47.1 的 arm64 GTK 引擎包存在，且引擎、`gen_snapshot` 和 Dart SDK 的 glibc 需求不超过 2.18。剩下的风险是 runner 的链接环境。构建放在 Ubuntu 20.04 arm64 容器中，让它和 OnePlus 6T 的 glibc 2.31 对齐。若容器路线失败，再回到固定已验证的 engine artifact 或自建 engine。不要在路线中承诺从 Linux x64 交叉编译。

### 视频纹理与硬解

Linux 桌面的 OpenGL ES 修复提供了良好起点，但手机 GPU 驱动、Mir 和硬件解码 API 不同。若硬件纹理失败，软件纹理只能作为诊断模式，不宜作为长期默认；若硬解失败，先降默认画质和帧率。

### 包体与内存

Flutter、libmpv/FFmpeg、JRE 和 jar 会形成较大的 Click。用裁剪构建和 `jlink` 优化，但先以可复现和正确许可证为准。运行时还同时存在 Flutter、libmpv 与 Java 三个主要内存来源，不应以 6T 有 6/8 GiB 内存为理由放松测试；低内存 UT 设备仍需单独门槛。

### Ubuntu Touch 生命周期

这是功能风险，不是普通 bug。直接运行 libmpv 不会自动获得 media-hub 的后台生命周期待遇。首版诚实降级为前台播放，比申请宽泛保留权限或依赖 undocumented exemption 更可维护。

### Focal 与 Noble 分叉

6T 当前只能验证 Focal，而长期生态转向 Noble。公共 Dart 代码保持一份，构建配置和依赖锁定按 framework 分开。只有在两条真机轨道均通过后，才能称为通用 Ubuntu Touch port。

## 第一轮建议任务

按以下顺序开工，前一项失败就不进入下一项：

1. 在目标 6T 上记录 UT framework、架构、可用空间和系统 GTK/libc/GL 信息。
2. 用原生 arm64 环境构建并启动最小 Flutter 3.47.1 Linux 应用。
3. 封装最小 Click，解决 Maliit 和 Lomiri 窗口。
4. 启动完整 GasTube，但临时使用不需要 sidecar 的后端验证 UI/DB/网络。
5. 加入最小 JRE 和 NewPipe sidecar，完成提取压力测试。
6. 加入裁剪 libmpv，先播本地文件，再播单一 HTTPS URL，最后接 NewPipe。
7. 播放门槛通过后，再开始 Content Hub 和 URL Dispatcher。

## 参考

- [Clickable commands](https://clickable-ut.dev/en/stable/commands.html)
- [Ubuntu Touch Click packages](https://docs.ubports.com/en/latest/appdev/platform/click.html)
- [AppArmor policy groups](https://docs.ubports.com/en/latest/appdev/platform/apparmor.html)
- [Content Hub](https://docs.ubports.com/en/latest/appdev/guides/contenthub.html)
- [Content Hub and URL Dispatcher](https://docs.ubports.com/en/latest/appdev/guides/importing-CH-urldispatcher.html)
- [OnePlus 6T Ubuntu Touch release status](https://devices.ubuntu-touch.io/device/fajita/release/focal/)
- [Ubuntu Touch 24.04-1.x publishing guide](https://forums.ubports.com/topic/11333/app-developers-guide-to-publishing-applications-for-ubuntu-touch-24.04-1.x)

