# CityWalk Mobile（Expo / React Native）

## 地图说明（高德）

- 全屏地图与「我的」统计弹窗中的底图均通过 **`AppMapView`**（`src/maps/AppMapView.tsx`）使用 **`expo-gaode-map`**，底层为高德 **原生 SDK**（与 iOS `MAMapView` 同体系）。
- **Expo Go 不包含本模块**：需 **Development Build** 或 `expo prebuild` 后的本地工程（`npx expo run:ios` / `run:android`）。
- **API Key**：在 [高德开放平台](https://lbs.amap.com/) 分别为 iOS / Android 创建 Key，构建前设置环境变量：
  - `AMAP_IOS_KEY`
  - `AMAP_ANDROID_KEY`  
  由 **`app.config.js`**（与 `app.json` 同级）注入 `expo-gaode-map` 的 Config Plugin。未设置时占位符为 `YOUR_AMAP_IOS_KEY` / `YOUR_AMAP_ANDROID_KEY`，请务必替换后再 `npx expo prebuild --clean`。
- **隐私合规**：`App.tsx` 在启动时调用了 `ExpoGaodeMapModule.setPrivacyConfig`（开发便利写法）。上架前请改为：**用户阅读并同意隐私政策后再调用**，版本号与文案需与高德要求一致（参见 [expo-gaode-map 文档](https://tomwq.github.io/expo-gaode-map/)）。
- **步行导航 / 路线与 iOS Swift 完全对齐**：可在本包基础上继续接 **`expo-gaode-map-navigation`**（与 `expo-gaode-map` **二选一**，勿同时安装）；或继续由后端 + 自有 HUD 驱动。

## 会话持久化

「新的旅程」Tab 启动时会：

1. 尝试读取 `AsyncStorage` 中的 `campus_walk_journey_conversation_id`；
2. 若存在且 `GET /conversations/{id}/messages` 成功，则恢复该会话与历史消息；
3. 否则创建新会话并写入存储。

聊天顶栏 **「新对话」** 会清空存储、创建新会话并清空当前消息列表。

环境变量与启动命令见仓库根目录 `README.md`。
