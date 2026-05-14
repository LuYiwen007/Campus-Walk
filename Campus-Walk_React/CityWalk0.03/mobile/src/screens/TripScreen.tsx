import { Ionicons } from '@expo/vector-icons';
import React, { useMemo, useState } from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Image } from 'expo-image';
import { Theme } from '../theme';
import { TripCalendar } from './trip/TripCalendar';
import { getJourneyDetailPayload } from './trip/journeyDetailStore';
import { JourneyDetailModal } from './trip/JourneyDetailModal';
import { TripStatsModal } from './trip/TripStatsModal';
import type { TripRecord } from './trip/tripsCatalog';
import { TRIPS_CATALOG } from './trip/tripsCatalog';

function startOfDayMs(ts: number): number {
  const x = new Date(ts);
  return new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
}

function filteredTrips(trips: TripRecord[], year: number, month: number, selectedDay: number | null): TripRecord[] {
  if (selectedDay == null) {
    return [...trips].sort((a, b) => b.startMs - a.startMs);
  }
  const t0 = startOfDayMs(new Date(year, month - 1, selectedDay).getTime());
  return trips
    .filter((trip) => {
      const s = startOfDayMs(trip.startMs);
      const e = startOfDayMs(trip.endMs);
      return t0 >= s && t0 <= e;
    })
    .sort((a, b) => b.startMs - a.startMs);
}

function filterTitle(year: number, month: number, selectedDay: number | null): string {
  if (selectedDay == null) return '所有行程';
  return `${month}月${selectedDay}日的行程`;
}

/** 与 Swift TripView 统计按钮演示数据同量级 */
function statsForTrip(trip: TripRecord): { durationSec: number; distanceKm: number; calories: number } {
  const h = (trip.endMs - trip.startMs) / (3600 * 1000);
  const durationSec = Math.max(3600, Math.min(48 * 3600, h * 3600 * 0.15));
  const distanceKm = Math.max(2, Math.min(80, h * 12 + (trip.id.charCodeAt(0) % 5)));
  const calories = 180 + distanceKm * 42;
  return { durationSec, distanceKm, calories };
}

export function TripScreen() {
  const now = new Date();
  const [calendarYear, setCalendarYear] = useState(now.getFullYear());
  const [calendarMonth, setCalendarMonth] = useState(now.getMonth() + 1);
  const [selectedDay, setSelectedDay] = useState<number | null>(null);
  const [profileOpen, setProfileOpen] = useState(false);
  const [statsOpen, setStatsOpen] = useState(false);
  const [statsTrip, setStatsTrip] = useState<TripRecord | null>(null);
  const [detailId, setDetailId] = useState<string | null>(null);

  const list = useMemo(
    () => filteredTrips(TRIPS_CATALOG, calendarYear, calendarMonth, selectedDay),
    [calendarYear, calendarMonth, selectedDay]
  );

  const detailPayload = detailId ? getJourneyDetailPayload(detailId) ?? null : null;

  const onChangeMonth = (y: number, m: number) => {
    setCalendarYear(y);
    setCalendarMonth(m);
    setSelectedDay(null);
  };

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <Modal visible={profileOpen} transparent animationType="fade" onRequestClose={() => setProfileOpen(false)}>
        <View style={styles.drawerRow}>
          <View style={styles.drawerPanel}>
            <Text style={styles.drawerTitle}>个人资料</Text>
            <Text style={styles.drawerHint}>占位：对齐 iOS UserProfileDrawer，可接登录用户与设置。</Text>
            <Pressable style={styles.drawerClose} onPress={() => setProfileOpen(false)}>
              <Text style={styles.drawerCloseTxt}>关闭</Text>
            </Pressable>
          </View>
          <Pressable style={styles.drawerDim} onPress={() => setProfileOpen(false)} />
        </View>
      </Modal>

      <TripStatsModal
        visible={statsOpen && statsTrip != null}
        onClose={() => {
          setStatsOpen(false);
          setStatsTrip(null);
        }}
        durationSec={statsTrip ? statsForTrip(statsTrip).durationSec : 3600}
        distanceKm={statsTrip ? statsForTrip(statsTrip).distanceKm : 5.2}
        calories={statsTrip ? statsForTrip(statsTrip).calories : 320}
      />

      <JourneyDetailModal
        visible={detailId != null}
        journey={detailPayload ?? null}
        onClose={() => setDetailId(null)}
      />

      <View style={styles.topBar}>
        <Pressable hitSlop={12} onPress={() => setProfileOpen(true)} style={styles.iconBtn}>
          <Ionicons name="menu" size={24} color="#737A85" />
        </Pressable>
        <Text style={styles.topTitle}>我的旅程</Text>
        <View style={{ width: 28 }} />
      </View>
      <View style={styles.sep} />

      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <View style={styles.calPad}>
          <TripCalendar
            year={calendarYear}
            month={calendarMonth}
            onChangeMonth={onChangeMonth}
            selectedDay={selectedDay}
            onSelectDay={setSelectedDay}
            trips={TRIPS_CATALOG}
          />
        </View>

        <View style={styles.listHead}>
          <Text style={styles.listHeadTitle}>{filterTitle(calendarYear, calendarMonth, selectedDay)}</Text>
          {selectedDay != null ? (
            <Pressable hitSlop={8} onPress={() => setSelectedDay(null)}>
              <Text style={styles.listHeadLink}>查看全部</Text>
            </Pressable>
          ) : (
            <View style={{ width: 64 }} />
          )}
        </View>

        {list.length === 0 ? (
          <Text style={styles.empty}>该日期没有行程</Text>
        ) : (
          list.map((trip) => (
            <TripJourneyRow
              key={trip.id}
              trip={trip}
              onOpenStats={() => {
                setStatsTrip(trip);
                setStatsOpen(true);
              }}
              onOpenDetail={() => {
                if (trip.detailId) setDetailId(trip.detailId);
              }}
            />
          ))
        )}
        <View style={{ height: 120 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

function TripJourneyRow({
  trip,
  onOpenStats,
  onOpenDetail,
}: {
  trip: TripRecord;
  onOpenStats: () => void;
  onOpenDetail: () => void;
}) {
  return (
    <View style={styles.rowCard}>
      <View style={styles.rowMain}>
        <Pressable
          disabled={!trip.detailId}
          onPress={onOpenDetail}
          style={({ pressed }) => [
            styles.rowPress,
            { opacity: !trip.detailId ? 1 : pressed ? 0.85 : 1 },
          ]}
        >
          {trip.coverImageURL ? (
            <Image source={{ uri: trip.coverImageURL }} style={styles.thumb} contentFit="cover" />
          ) : (
            <View style={[styles.thumb, styles.thumbPh]}>
              <Ionicons name="image-outline" size={28} color="#C4C8CE" />
            </View>
          )}
          <View style={styles.rowBody}>
            <Text style={styles.rowTitle} numberOfLines={2}>
              {trip.title}
            </Text>
            <Text style={styles.rowMeta}>{trip.datesLabel}</Text>
            <View style={styles.rowFoot}>
              <ParticipantStack count={trip.participantCount} />
            </View>
          </View>
        </Pressable>
        <View style={styles.sideActions}>
          <Pressable hitSlop={8} onPress={onOpenStats} style={styles.actBtn}>
            <Ionicons name="stats-chart" size={16} color={Theme.brandBlue} />
          </Pressable>
          <Pressable hitSlop={8} style={styles.actBtn}>
            <Ionicons name="share-outline" size={16} color={Theme.textMuted} />
          </Pressable>
        </View>
      </View>
    </View>
  );
}

function ParticipantStack({ count }: { count: number }) {
  const shown = Math.min(count, 3);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center' }}>
      {Array.from({ length: shown }).map((_, i) => (
        <View key={i} style={[styles.pDot, i > 0 && styles.pDotOverlap]} />
      ))}
      {count > 3 ? (
        <View style={[styles.pMore, shown > 0 && styles.pDotOverlap]}>
          <Text style={styles.pMoreTxt}>+{count - 3}</Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#fff' },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    paddingVertical: 12,
    backgroundColor: 'rgba(255,255,255,0.92)',
  },
  iconBtn: { width: 28, height: 28, alignItems: 'center', justifyContent: 'center' },
  topTitle: { fontSize: 16, fontWeight: '500', color: '#474C52' },
  sep: { height: 1, backgroundColor: Theme.borderSubtle },
  scroll: { paddingBottom: 24 },
  calPad: { paddingHorizontal: 24, paddingTop: 24 },
  listHead: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 24,
    marginTop: 8,
    marginBottom: 12,
  },
  listHeadTitle: { fontSize: 16, fontWeight: '500', color: '#474C52' },
  listHeadLink: { fontSize: 14, fontWeight: '500', color: Theme.brandBlue },
  empty: { textAlign: 'center', color: Theme.textMuted, paddingVertical: 48, fontSize: 14 },
  rowCard: {
    marginHorizontal: 24,
    marginBottom: 12,
    borderRadius: Theme.cornerCard,
    borderWidth: 1,
    borderColor: Theme.cardStroke,
    backgroundColor: '#fff',
    overflow: 'hidden',
  },
  rowMain: { flexDirection: 'row', alignItems: 'stretch', padding: 16 },
  rowPress: { flex: 1, flexDirection: 'row', minWidth: 0 },
  sideActions: { justifyContent: 'center', paddingLeft: 4 },
  thumb: { width: 80, height: 80, borderRadius: Theme.cornerCard, backgroundColor: Theme.surfaceGray50 },
  thumbPh: { alignItems: 'center', justifyContent: 'center' },
  rowBody: { flex: 1, marginLeft: 16 },
  rowTitle: { fontSize: 14, fontWeight: '500', color: '#1F2024' },
  rowMeta: { marginTop: 6, fontSize: 12, color: Theme.textMuted },
  rowFoot: { flexDirection: 'row', alignItems: 'center', marginTop: 8 },
  actBtn: { width: 32, height: 32, alignItems: 'center', justifyContent: 'center', marginLeft: 4 },
  pDot: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: Theme.brandBlue,
    borderWidth: 1,
    borderColor: '#fff',
  },
  pDotOverlap: { marginLeft: -6 },
  pMore: {
    width: 20,
    height: 20,
    borderRadius: 10,
    backgroundColor: '#E6E8EB',
    borderWidth: 1,
    borderColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  pMoreTxt: { fontSize: 9, fontWeight: '600', color: '#737A85' },
  drawerRow: { flex: 1, flexDirection: 'row' },
  drawerDim: { flex: 1, backgroundColor: 'rgba(0,0,0,0.18)' },
  drawerPanel: {
    width: '72%',
    maxWidth: 320,
    backgroundColor: '#fff',
    paddingTop: 56,
    paddingHorizontal: 20,
    shadowColor: '#000',
    shadowOpacity: 0.12,
    shadowRadius: 8,
    shadowOffset: { width: 2, height: 0 },
    elevation: 6,
  },
  drawerTitle: { fontSize: 20, fontWeight: '700', color: Theme.textPrimary },
  drawerHint: { marginTop: 12, fontSize: 14, color: Theme.textSecondary, lineHeight: 20 },
  drawerClose: { marginTop: 28, alignSelf: 'flex-start', paddingVertical: 10, paddingHorizontal: 16 },
  drawerCloseTxt: { fontSize: 16, fontWeight: '600', color: Theme.brandBlue },
});
