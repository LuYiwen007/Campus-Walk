# Campus-Walk

The UESTC and UofG joint school WeCreate Project.

拉取仓库后请安装各子项目依赖（见下文「React 客户端」与后端文档）。

高德地图相关排坑可参考：[《高德API接入的坑》](https://www.yuque.com/zibei-sydly/oucpsf/qqxcityns1o3p496?singleDoc#)

---

## React 客户端（Expo / React Native）

移动端应用在 **`Campus-Walk_React/CityWalk0.03/mobile/`**，使用 **Expo** 与 **TypeScript**，与 Spring Boot 后端通过 REST 通信。

### 环境要求

- **Node.js**（建议 LTS）
- **npm** 或 **yarn**
- 开发 iOS：macOS + Xcode；开发 Android：Android Studio / 模拟器

### 安装与启动

```bash
cd Campus-Walk_React/CityWalk0.03/mobile
npm install
```

启动开发服务器（随后按终端提示用 Expo Go 扫码，或按 `i` / `a` 打开模拟器）：

```bash
npm start
# 或
npx expo start
```

常用脚本（在 `mobile` 目录下）：

| 命令 | 说明 |
|------|------|
| `npm start` | 启动 Expo（Metro） |
| `npm run ios` | 在 iOS 模拟器运行 |
| `npm run android` | 在 Android 模拟器运行 |
| `npm run web` | 在浏览器中运行（Web 能力取决于依赖支持） |

### 后端地址配置

客户端从 `src/config.ts` 读取 **`API_BASE_URL`**：

- **未设置环境变量时**：iOS 默认 `http://127.0.0.1:8081`，Android 模拟器默认 `http://10.0.2.2:8081`（指向本机后端，端口与仓库内 Spring Boot 默认一致）。
- **真机调试**：本机 IP 无法被 `127.0.0.1` 访问，需设置 Expo 公共环境变量，例如：

```bash
export EXPO_PUBLIC_API_BASE_URL=http://你的电脑局域网IP:8081
npx expo start
```

或在启动前写入 `.env`（若项目已接入 `expo-env` 等加载方式时同样使用变量名 **`EXPO_PUBLIC_API_BASE_URL`**）。

请先启动后端服务，再在客户端里使用聊天、地图选路、开始步行导航等流程。

### 功能说明（简要）

- **聊天**：`JourneyScreen` 中与对话接口交互；助手返回路线批次后，消息内会展示可选路线。
- **地图**：点击某条路线或「回到地图」进入全屏高德地图；底部选路面板与「开始步行导航」、导航 HUD 与返回逻辑不变。底图依赖 **`expo-gaode-map`**，需配置 `AMAP_IOS_KEY` / `AMAP_ANDROID_KEY` 并预构建原生工程；详见 **`Campus-Walk_React/CityWalk0.03/mobile/README.md`**。
- **会话**：「新的旅程」会优先恢复 `AsyncStorage` 中保存的 `conversationId` 与历史消息；顶栏 **「新对话」** 会清空存储并创建新会话。

更多接口与 DTO 定义见 `mobile/src/api/`。
