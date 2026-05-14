import { Ionicons } from '@expo/vector-icons';
import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Theme } from '../theme';
import { CommunityScreen } from '../screens/CommunityScreen';
import { JourneyScreen } from '../screens/JourneyScreen';
import { TripScreen } from '../screens/TripScreen';

export function MainShell() {
  const [tab, setTab] = useState(0);

  return (
    <View style={styles.root}>
      <View style={styles.body}>
        {tab === 0 ? <CommunityScreen /> : null}
        {tab === 1 ? <JourneyScreen /> : null}
        {tab === 2 ? <TripScreen /> : null}
      </View>
      <SafeAreaView edges={['bottom']} style={styles.tabSafe}>
        <View style={styles.tabBar}>
          <TabBtn
            title="社区"
            icon="people-outline"
            iconActive="people"
            selected={tab === 0}
            onPress={() => setTab(0)}
          />
          <TabBtn
            title="新的旅程"
            icon="chatbubbles-outline"
            iconActive="chatbubbles"
            selected={tab === 1}
            onPress={() => setTab(1)}
          />
          <TabBtn
            title="我的"
            icon="briefcase-outline"
            iconActive="briefcase"
            selected={tab === 2}
            onPress={() => setTab(2)}
          />
        </View>
      </SafeAreaView>
    </View>
  );
}

function TabBtn({
  title,
  icon,
  iconActive,
  selected,
  onPress,
}: {
  title: string;
  icon: keyof typeof Ionicons.glyphMap;
  iconActive: keyof typeof Ionicons.glyphMap;
  selected: boolean;
  onPress: () => void;
}) {
  const color = selected ? Theme.brandBlue : Theme.textMuted;
  return (
    <Pressable onPress={onPress} style={styles.tabBtn}>
      <Ionicons name={selected ? iconActive : icon} size={20} color={color} />
      <Text style={[styles.tabText, { color }]}>{title}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fff' },
  body: { flex: 1 },
  tabSafe: {
    backgroundColor: 'rgba(255,255,255,0.82)',
    borderTopWidth: 1,
    borderTopColor: Theme.borderSubtle,
  },
  tabBar: {
    height: Theme.tabBarHeight,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
  },
  tabBtn: { flex: 1, alignItems: 'center', gap: 4 },
  tabText: { fontSize: 12, fontWeight: '500' },
});
