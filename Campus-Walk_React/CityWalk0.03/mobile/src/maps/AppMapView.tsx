import React, { useMemo } from 'react';
import type { StyleProp, ViewStyle } from 'react-native';
import { MapView as GaodeMapView, type CameraPosition, type MapViewProps } from 'expo-gaode-map';

/**
 * 与 `react-native-maps` 的 `Region` 对齐的简化入参，便于现有屏幕少改代码。
 */
export type MapRegion = {
  latitude: number;
  longitude: number;
  latitudeDelta: number;
  longitudeDelta: number;
};

export type AppMapViewProps = {
  style?: StyleProp<ViewStyle>;
  /** 初始视野（由本组件转换为高德 `initialCameraPosition`） */
  initialRegion: MapRegion;
  showsUserLocation?: boolean;
  scrollEnabled?: boolean;
  rotateEnabled?: boolean;
  pitchEnabled?: boolean;
  zoomEnabled?: boolean;
};

/** 将 latitudeDelta 近似映射为高德 zoom（3–20） */
export function regionToInitialCamera(region: MapRegion): CameraPosition {
  const latDelta = Math.max(1e-6, region.latitudeDelta);
  const zoom = Math.round(15 - Math.log2(latDelta * 45));
  return {
    target: { latitude: region.latitude, longitude: region.longitude },
    zoom: Math.max(3, Math.min(19, zoom)),
  };
}

/**
 * 应用内统一地图：**高德**（`expo-gaode-map` / 原生 AMap SDK）。
 *
 * 需在 `app.config.js` 中配置 `expo-gaode-map` 插件并设置 `AMAP_IOS_KEY` / `AMAP_ANDROID_KEY` 后执行 `npx expo prebuild` 与原生运行；仅 Expo Go 无法加载自定义原生模块。
 */
export function AppMapView({
  style,
  initialRegion,
  showsUserLocation,
  scrollEnabled = true,
  rotateEnabled = true,
  pitchEnabled = true,
  zoomEnabled = true,
}: AppMapViewProps) {
  const initialCameraPosition = useMemo(() => regionToInitialCamera(initialRegion), [initialRegion]);

  const gaodeProps: MapViewProps = {
    style,
    initialCameraPosition,
    myLocationEnabled: showsUserLocation ?? false,
    scrollGesturesEnabled: scrollEnabled,
    rotateGesturesEnabled: rotateEnabled,
    tiltGesturesEnabled: pitchEnabled,
    zoomGesturesEnabled: zoomEnabled,
    /** iOS：国外自动切苹果地图；国内步行场景固定高德 */
    worldMapSwitchEnabled: false,
  };

  return <GaodeMapView {...gaodeProps} />;
}
