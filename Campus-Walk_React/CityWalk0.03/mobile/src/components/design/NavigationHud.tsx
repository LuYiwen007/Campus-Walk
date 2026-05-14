import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

/** 对齐 `导航ui/src/app/App.tsx` 的色板与层级 */
export const NavHudColors = {
  frameBg: '#2a4a3e',
  mapGradientTop: '#2a5547',
  mapGradientMid: '#2d4a3d',
  mapGradientBottom: '#1f3a2e',
  cardBg: 'rgba(0,0,0,0.9)',
  rowBg: 'rgba(55,65,81,0.5)',
  floatBtn: 'rgba(0,0,0,0.7)',
  bottomBar: 'rgba(0,0,0,0.8)',
  road: '#4a9d7e',
  road2: '#3d7d65',
} as const;

export type NavigationHudProps = {
  nextMeters: number;
  nextActionText: string;
  totalLine: string;
  arrivalText: string;
  onExit: () => void;
  onVoice?: () => void;
  onRecenter?: () => void;
};

export function NavigationHud({
  nextMeters,
  nextActionText,
  totalLine,
  arrivalText,
  onExit,
  onVoice,
  onRecenter,
}: NavigationHudProps) {
  const insets = useSafeAreaInsets();
  const topPad = Math.max(insets.top, 20) + 40;

  return (
    <View style={styles.root} pointerEvents="box-none">
      <View style={[styles.mapBg, { paddingTop: topPad }]} pointerEvents="none">
        <View style={styles.gradTop} />
        <View style={styles.gradMid} />
        <View style={styles.gradBot} />
        <View style={styles.svgMock} />
        <View style={styles.centerNav}>
          <Text style={styles.compassN}>北</Text>
          <View style={styles.navCircle}>
            <Ionicons name="navigate" size={32} color="#fff" />
          </View>
          <Text style={styles.compassS}>南</Text>
          <Text style={styles.compassW}>西</Text>
          <Text style={styles.compassE}>东</Text>
        </View>
      </View>

      <View style={[styles.topCardWrap, { top: topPad }]} pointerEvents="box-none">
        <View style={styles.card}>
          <View style={styles.cardMain}>
            <View style={styles.turnIcon}>
              <Ionicons name="return-down-forward" size={52} color="#fff" />
            </View>
            <View style={styles.cardTextCol}>
              <View style={styles.bigRow}>
                <Text style={styles.bigNum}>{nextMeters}</Text>
                <Text style={styles.bigSuffix}>米后 {nextActionText}</Text>
              </View>
            </View>
          </View>
          <View style={styles.cardFooter}>
            <Text style={styles.footerLeft}>{totalLine}</Text>
            <Text style={styles.footerRight}>{arrivalText}</Text>
          </View>
        </View>
      </View>

      <View style={styles.rightCol} pointerEvents="box-none">
        <Pressable style={styles.roundBtn} onPress={onVoice}>
          <Ionicons name="volume-high" size={20} color="#fff" />
        </Pressable>
        <Pressable style={[styles.roundBtn, styles.roundBtnSpaced]} onPress={onRecenter}>
          <Ionicons name="navigate" size={20} color="#fff" />
        </Pressable>
      </View>

      <View style={[styles.bottomBar, { paddingBottom: Math.max(insets.bottom, 12) }]} pointerEvents="box-none">
        <Pressable style={styles.exitTile} onPress={onExit}>
          <Ionicons name="close" size={24} color="#fff" />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { ...StyleSheet.absoluteFillObject },
  mapBg: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: NavHudColors.frameBg,
  },
  gradTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '38%',
    backgroundColor: NavHudColors.mapGradientTop,
    opacity: 0.95,
  },
  gradMid: {
    position: 'absolute',
    top: '38%',
    left: 0,
    right: 0,
    height: '34%',
    backgroundColor: NavHudColors.mapGradientMid,
    opacity: 0.95,
  },
  gradBot: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '28%',
    backgroundColor: NavHudColors.mapGradientBottom,
    opacity: 0.95,
  },
  svgMock: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0.22,
    borderLeftWidth: 2,
    borderLeftColor: NavHudColors.road,
    marginLeft: '18%',
    transform: [{ rotate: '12deg' }],
  },
  centerNav: {
    position: 'absolute',
    top: '46%',
    left: 0,
    right: 0,
    alignItems: 'center',
    justifyContent: 'center',
  },
  navCircle: {
    width: 64,
    height: 64,
    borderRadius: 32,
    backgroundColor: '#3B82F6',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOpacity: 0.25,
    shadowRadius: 8,
    shadowOffset: { width: 0, height: 3 },
    elevation: 6,
  },
  compassN: { position: 'absolute', top: -28, color: '#fff', fontSize: 12 },
  compassS: { position: 'absolute', bottom: -28, color: '#fff', fontSize: 12 },
  compassW: { position: 'absolute', left: '22%', top: '50%', marginTop: -8, color: '#fff', fontSize: 12 },
  compassE: { position: 'absolute', right: '22%', top: '50%', marginTop: -8, color: '#fff', fontSize: 12 },
  topCardWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    zIndex: 40,
    paddingHorizontal: 12,
  },
  card: {
    borderRadius: 16,
    overflow: 'hidden',
    backgroundColor: NavHudColors.cardBg,
    shadowColor: '#000',
    shadowOpacity: 0.35,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 6 },
    elevation: 10,
  },
  cardMain: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingVertical: 12 },
  turnIcon: { marginRight: 4 },
  cardTextCol: { flex: 1, marginLeft: 8 },
  bigRow: { flexDirection: 'row', alignItems: 'baseline' },
  bigNum: { color: '#fff', fontSize: 52, fontWeight: '700', lineHeight: 56 },
  bigSuffix: { color: 'rgba(255,255,255,0.9)', fontSize: 20, marginLeft: 8 },
  cardFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: NavHudColors.rowBg,
  },
  footerLeft: { color: 'rgba(255,255,255,0.8)', fontSize: 15 },
  footerRight: { color: 'rgba(255,255,255,0.95)', fontSize: 17, fontWeight: '500' },
  rightCol: {
    position: 'absolute',
    top: 280,
    right: 16,
    zIndex: 30,
  },
  roundBtn: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: NavHudColors.floatBtn,
    alignItems: 'center',
    justifyContent: 'center',
  },
  roundBtnSpaced: {
    marginTop: 12,
  },
  bottomBar: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 100,
    backgroundColor: NavHudColors.bottomBar,
    zIndex: 40,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 24,
  },
  exitTile: {
    width: 48,
    height: 48,
    borderRadius: 12,
    backgroundColor: 'rgba(31,41,55,0.9)',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
