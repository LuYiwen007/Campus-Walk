const { withPodfile } = require('@expo/config-plugins');

/**
 * 在 Podfile 顶部声明 CocoaPods trunk（CDN），避免未配置 spec 源时找不到高德 AMap*。
 * 国内若 CDN 回源 GitHub 超时，请在本文件或 ios/Podfile 中改用清华镜像（见 Podfile 注释）。
 */
const SOURCE_LINE = "source 'https://cdn.cocoapods.org/'";

module.exports = function withPodfileCocoaPodsSource(config) {
  return withPodfile(config, (mod) => {
    const contents = mod.modResults.contents;
    if (
      contents.includes('cdn.cocoapods.org') ||
      contents.includes('mirrors.tuna.tsinghua.edu.cn/git/CocoaPods/Specs')
    ) {
      return mod;
    }
    mod.modResults.contents = `${SOURCE_LINE}\n\n${contents}`;
    return mod;
  });
};
