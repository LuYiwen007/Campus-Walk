import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import { Theme } from '../../theme';
import type { JourneyDetailPayload } from './journeyDetailStore';

type Props = {
  visible: boolean;
  journey: JourneyDetailPayload | null;
  onClose: () => void;
};

export function JourneyDetailModal({ visible, journey, onClose }: Props) {
  const insets = useSafeAreaInsets();
  const topPad = Math.max(insets.top, 12) + 28;

  return (
    <Modal
      visible={Boolean(visible && journey)}
      animationType="slide"
      presentationStyle="fullScreen"
      onRequestClose={onClose}
    >
      {journey ? (
        <ScrollView showsVerticalScrollIndicator={false} bounces>
          <View style={styles.heroWrap}>
            <Image source={{ uri: journey.coverImage }} style={styles.heroImg} contentFit="cover" />
            <View style={styles.heroDarkBottom} />
            <Pressable style={[styles.backBtn, { top: topPad }]} onPress={onClose} hitSlop={12}>
              <Ionicons name="chevron-back" size={22} color="#474C52" />
            </Pressable>
            <View style={styles.heroText}>
              <Text style={styles.heroTitle}>{journey.title}</Text>
              <View style={styles.heroMeta}>
                <Ionicons name="calendar-outline" size={14} color="rgba(255,255,255,0.95)" />
                <Text style={styles.heroMetaTxt}>{journey.dates}</Text>
                <Ionicons name="location-outline" size={14} color="rgba(255,255,255,0.95)" style={{ marginLeft: 12 }} />
                <Text style={styles.heroMetaTxt} numberOfLines={1}>
                  {journey.location}
                </Text>
              </View>
            </View>
          </View>

          <View style={styles.body}>
            <Text style={styles.secLabel}>参与者 ({journey.participants.length})</Text>
            <View style={styles.partRow}>
              {journey.participants.map((p) => (
                <View key={p.name} style={styles.partItem}>
                  <View style={styles.partAvatar}>
                    <Text style={styles.partAvText}>{p.name.slice(0, 1)}</Text>
                  </View>
                  <Text style={styles.partName}>{p.name}</Text>
                </View>
              ))}
            </View>

            <Text style={[styles.secLabel, { marginTop: 24 }]}>行程简介</Text>
            <Text style={styles.desc}>{journey.description}</Text>

            <Text style={[styles.secLabel, { marginTop: 24 }]}>日程</Text>
            {journey.itinerary.map((day) => (
              <View key={day.day} style={styles.dayBlock}>
                <Text style={styles.dayHead}>
                  {day.day} · {day.date}
                </Text>
                {day.activities.map((a) => (
                  <View key={`${a.time}-${a.title}`} style={styles.actRow}>
                    <Text style={styles.actTime}>{a.time}</Text>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.actTitle}>{a.title}</Text>
                      <Text style={styles.actLoc}>{a.location}</Text>
                    </View>
                  </View>
                ))}
              </View>
            ))}

            <Text style={[styles.secLabel, { marginTop: 24 }]}>相册</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.photoScroll}>
              {journey.photos.map((ph) => (
                <View key={ph.url} style={styles.photoCard}>
                  <Image source={{ uri: ph.url }} style={styles.photoImg} contentFit="cover" />
                  <Text style={styles.photoLikes}>♥ {ph.likes}</Text>
                </View>
              ))}
            </ScrollView>

            <Text style={[styles.secLabel, { marginTop: 24 }]}>笔记</Text>
            {journey.notes.map((n) => (
              <View key={n.title} style={styles.noteCard}>
                <Text style={styles.noteTitle}>{n.title}</Text>
                <Text style={styles.noteBody}>{n.content}</Text>
                <Text style={styles.noteTime}>{n.time}</Text>
              </View>
            ))}
            <View style={{ height: 48 }} />
          </View>
        </ScrollView>
      ) : null}
    </Modal>
  );
}

const styles = StyleSheet.create({
  heroWrap: { height: 288, width: '100%' },
  heroImg: { ...StyleSheet.absoluteFillObject },
  heroDarkBottom: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: 140,
    backgroundColor: 'rgba(0,0,0,0.45)',
  },
  backBtn: {
    position: 'absolute',
    left: 16,
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: 'rgba(255,255,255,0.85)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: Theme.cardStroke,
  },
  heroText: {
    position: 'absolute',
    left: 24,
    right: 24,
    bottom: 24,
  },
  heroTitle: { fontSize: 22, fontWeight: '600', color: '#fff' },
  heroMeta: { flexDirection: 'row', alignItems: 'center', marginTop: 12, flexWrap: 'wrap' },
  heroMetaTxt: { fontSize: 12, color: 'rgba(255,255,255,0.95)', marginLeft: 4 },
  body: { paddingHorizontal: 24, paddingVertical: 32 },
  secLabel: { fontSize: 13, color: Theme.sectionTitle, marginBottom: 12 },
  partRow: { flexDirection: 'row', flexWrap: 'wrap' },
  partItem: { alignItems: 'center', marginRight: 16, marginBottom: 8 },
  partAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: Theme.brandBlue,
    alignItems: 'center',
    justifyContent: 'center',
  },
  partAvText: { fontSize: 15, fontWeight: '600', color: '#fff' },
  partName: { marginTop: 8, fontSize: 12, color: Theme.textSecondary },
  desc: { fontSize: 15, color: Theme.textPrimary, lineHeight: 22 },
  dayBlock: { marginBottom: 20 },
  dayHead: { fontSize: 15, fontWeight: '600', color: Theme.textPrimary, marginBottom: 10 },
  actRow: { flexDirection: 'row', marginBottom: 12 },
  actTime: { width: 48, fontSize: 13, color: Theme.textMuted, marginRight: 12 },
  actTitle: { fontSize: 14, fontWeight: '500', color: Theme.textPrimary },
  actLoc: { fontSize: 13, color: Theme.textMuted, marginTop: 2 },
  photoScroll: { flexDirection: 'row', paddingVertical: 4 },
  photoCard: {
    width: 160,
    marginRight: 12,
    borderRadius: Theme.cornerCard,
    overflow: 'hidden',
    backgroundColor: Theme.surfaceGray50,
  },
  photoImg: { width: 160, height: 120 },
  photoLikes: { padding: 8, fontSize: 12, color: Theme.textSecondary },
  noteCard: {
    padding: 14,
    borderRadius: Theme.cornerCard,
    backgroundColor: Theme.surfaceGray50,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: Theme.cardStroke,
  },
  noteTitle: { fontSize: 15, fontWeight: '600', color: Theme.textPrimary },
  noteBody: { marginTop: 6, fontSize: 14, color: Theme.textSecondary, lineHeight: 20 },
  noteTime: { marginTop: 8, fontSize: 12, color: Theme.textMuted },
});
