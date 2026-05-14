import { Platform } from 'react-native';

/**
 * 与 iOS `APIConfiguration.baseURL` 对齐：模拟器连本机；真机请用 EXPO_PUBLIC_API_BASE_URL
 * 指向同一 Spring Boot（默认端口 8081，见仓库 backend application.yml）。
 */
const trimmed = process.env.EXPO_PUBLIC_API_BASE_URL?.replace(/\/$/, '');

export const API_BASE_URL =
  trimmed ??
  (Platform.OS === 'android'
    ? 'http://10.0.2.2:8081'
    : 'http://127.0.0.1:8081');
