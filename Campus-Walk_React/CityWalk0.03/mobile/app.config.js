/**
 * 动态配置：在 `app.json` 基础上注入高德 `expo-gaode-map` 插件。
 * 构建前请设置环境变量（或直接在下方写 Key，勿提交真实 Key 到公开仓库）：
 *   AMAP_IOS_KEY、AMAP_ANDROID_KEY
 */
module.exports = ({ config }) => {
  // Expo 传入的 `config` 已是 app.json 中的 `expo` 对象（无外层 `expo` 包裹），不要用 `config.expo`。
  const expo = config && typeof config === 'object' ? config : {};

  const iosKey = process.env.AMAP_IOS_KEY || 'YOUR_AMAP_IOS_KEY';
  const androidKey = process.env.AMAP_ANDROID_KEY || 'YOUR_AMAP_ANDROID_KEY';

  return {
    expo: {
      ...expo,
      plugins: [
        ...(expo.plugins ?? []),
        './plugins/withPodfileCocoaPodsSource.js',
        [
          'expo-gaode-map',
          {
            iosKey,
            androidKey,
            enableLocation: true,
            enableBackgroundLocation: false,
            locationDescription:
              expo?.ios?.infoPlist?.NSLocationWhenInUseUsageDescription ??
              '用于在地图上显示你的位置。',
          },
        ],
      ],
    },
  };
};
