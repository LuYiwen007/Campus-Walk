import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Dimensions, Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { AppMapView } from '../../maps/AppMapView';
import { Theme } from '../../theme';

type Props = {
  visible: boolean;
  onClose: () => void;
  durationSec: number;
  distanceKm: number;
  calories: number;
};

function formatDuration(sec: number): string {
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  const s = Math.floor(sec % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

const { height: WIN_H } = Dimensions.get('window');

export function TripStatsModal({ visible, onClose, durationSec, distanceKm, calories }: Props) {
  const insets = useSafeAreaInsets();
  const mapH = WIN_H * 0.42;

  return (
    <Modal visible={visible} animationType="slide" presentationStyle="fullScreen" onRequestClose={onClose}>
      <View style={styles.root}>
        <View style={[styles.mapBox, { height: mapH }]}>
          <AppMapView
            style={StyleSheet.absoluteFill}
            scrollEnabled={false}
            rotateEnabled={false}
            pitchEnabled={false}
            zoomEnabled={false}
            initialRegion={{
              latitude: 31.23,
              longitude: 121.47,
              latitudeDelta: 0.08,
              longitudeDelta: 0.08,
            }}
          />
        </View>
        <Pressable style={[styles.closeBtn, { top: Math.max(insets.top, 8) + 8 }]} onPress={onClose}>
          <Ionicons name="chevron-back" size={22} color={Theme.textPrimary} />
        </Pressable>
        <View style={styles.sheet}>
          <Text style={styles.title}>旅程统计</Text>
          <View style={styles.statsRow}>
            <View style={styles.statCol}>
              <Text style={styles.statLabel}>用时</Text>
              <Text style={styles.statVal}>{formatDuration(durationSec)}</Text>
            </View>
            <View style={styles.statCol}>
              <Text style={styles.statLabel}>路程</Text>
              <Text style={styles.statVal}>{distanceKm.toFixed(1)} km</Text>
            </View>
            <View style={styles.statCol}>
              <Text style={styles.statLabel}>卡路里</Text>
              <Text style={styles.statVal}>{Math.round(calories)} kcal</Text>
            </View>
          </View>
          <View style={styles.hrCard}>
            <View style={styles.hrHead}>
              <Ionicons name="heart" size={20} color="#EC4899" />
              <Text style={styles.hrTitle}>运动心率</Text>
            </View>
            <Text style={styles.hrHint}>连接设备后将显示心率</Text>
            <Text style={styles.hrStatus}>暂无数据</Text>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fff' },
  mapBox: { width: '100%', backgroundColor: '#E5E7EB' },
  closeBtn: {
    position: 'absolute',
    left: 16,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(242,242,247,0.95)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2,
  },
  sheet: { flex: 1, paddingHorizontal: 24, paddingTop: 24 },
  title: { fontSize: 22, fontWeight: '700', color: Theme.textPrimary, marginBottom: 24, textAlign: 'center' },
  statsRow: { flexDirection: 'row', justifyContent: 'space-around', marginBottom: 8 },
  statCol: { alignItems: 'center' },
  statLabel: { fontSize: 15, color: Theme.textSecondary, marginBottom: 8 },
  statVal: { fontSize: 18, fontWeight: '600', color: Theme.textPrimary },
  hrCard: {
    marginTop: 20,
    padding: 16,
    borderRadius: 12,
    backgroundColor: Theme.surfaceGray50,
    borderWidth: 1,
    borderColor: Theme.cardStroke,
  },
  hrHead: { flexDirection: 'row', alignItems: 'center' },
  hrTitle: { fontSize: 17, fontWeight: '600', color: Theme.textPrimary, marginLeft: 8 },
  hrHint: { marginTop: 10, fontSize: 14, color: Theme.textSecondary },
  hrStatus: { marginTop: 6, fontSize: 14, color: Theme.textMuted },
});
