import { Ionicons } from '@expo/vector-icons';
import React, { useMemo } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Theme } from '../../theme';
import type { TripRecord } from './tripsCatalog';

type Props = {
  year: number;
  month: number;
  onChangeMonth: (y: number, m: number) => void;
  selectedDay: number | null;
  onSelectDay: (day: number | null) => void;
  trips: TripRecord[];
};

const WEEK_LABELS = ['日', '一', '二', '三', '四', '五', '六'];

function startOfDayMs(ts: number): number {
  const x = new Date(ts);
  return new Date(x.getFullYear(), x.getMonth(), x.getDate()).getTime();
}

export function TripCalendar({ year, month, onChangeMonth, selectedDay, onSelectDay, trips }: Props) {
  const { firstWeekday, daysInMonth, occupied } = useMemo(() => {
    const first = new Date(year, month - 1, 1);
    const last = new Date(year, month, 0);
    const dim = last.getDate();
    const fw = first.getDay();
    const occ = new Set<number>();
    for (let day = 1; day <= dim; day++) {
      const dayStart = startOfDayMs(new Date(year, month - 1, day).getTime());
      for (const t of trips) {
        const s = startOfDayMs(t.startMs);
        const e = startOfDayMs(t.endMs);
        if (dayStart >= s && dayStart <= e) {
          occ.add(day);
          break;
        }
      }
    }
    return { firstWeekday: fw, daysInMonth: dim, occupied: occ };
  }, [year, month, trips]);

  const rows = useMemo(() => {
    const cells: (number | null)[] = [];
    for (let i = 0; i < firstWeekday; i++) cells.push(null);
    for (let d = 1; d <= daysInMonth; d++) cells.push(d);
    const r: (number | null)[][] = [];
    for (let i = 0; i < cells.length; i += 7) {
      const chunk = cells.slice(i, i + 7);
      while (chunk.length < 7) chunk.push(null);
      r.push(chunk);
    }
    return r;
  }, [firstWeekday, daysInMonth]);

  const title = `${year}年${month}月`;
  return (
    <View style={styles.wrap}>
      <Text style={styles.sectionTitle}>日历视图</Text>
      <View style={styles.navRow}>
        <Pressable hitSlop={8} onPress={() => onChangeMonth(month === 1 ? year - 1 : year, month === 1 ? 12 : month - 1)} style={styles.navBtn}>
          <Ionicons name="chevron-back" size={22} color={Theme.textSecondary} />
        </Pressable>
        <Text style={styles.monthTitle}>{title}</Text>
        <Pressable hitSlop={8} onPress={() => onChangeMonth(month === 12 ? year + 1 : year, month === 12 ? 1 : month + 1)} style={styles.navBtn}>
          <Ionicons name="chevron-forward" size={22} color={Theme.textSecondary} />
        </Pressable>
      </View>
      <View style={styles.weekRow}>
        {WEEK_LABELS.map((w) => (
          <Text key={w} style={styles.weekCell}>
            {w}
          </Text>
        ))}
      </View>
      {rows.map((row, ri) => (
        <View key={ri} style={styles.gridRow}>
          {row.map((cell, ci) => {
            if (cell == null) return <View key={`e-${ri}-${ci}`} style={styles.dayCell} />;
            const hasTrip = occupied.has(cell);
            const sel = selectedDay === cell;
            return (
              <Pressable
                key={cell}
                onPress={() => onSelectDay(sel ? null : cell)}
                style={[styles.dayCell, hasTrip && styles.dayHasTrip, sel && styles.daySelected]}
              >
                <Text style={[styles.dayNum, sel && styles.dayNumSel]}>{cell}</Text>
                {hasTrip ? <View style={styles.dot} /> : <View style={styles.dotPh} />}
              </Pressable>
            );
          })}
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: { marginBottom: 8 },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#474C52',
    marginBottom: 16,
  },
  navRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  navBtn: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  monthTitle: { fontSize: 16, fontWeight: '600', color: Theme.textPrimary },
  weekRow: { flexDirection: 'row', marginBottom: 6 },
  weekCell: {
    flex: 1,
    textAlign: 'center',
    fontSize: 12,
    color: Theme.textMuted,
    paddingVertical: 4,
  },
  gridRow: { flexDirection: 'row', alignItems: 'stretch' },
  dayCell: {
    flex: 1,
    minHeight: 44,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 8,
    paddingTop: 4,
    marginVertical: 2,
  },
  dayHasTrip: { backgroundColor: 'rgba(59,130,246,0.08)' },
  daySelected: { backgroundColor: Theme.brandBlueMutedBg, borderWidth: 1, borderColor: Theme.brandBlue },
  dayNum: { fontSize: 15, fontWeight: '500', color: Theme.textPrimary },
  dayNumSel: { color: Theme.brandBlue, fontWeight: '700' },
  dot: { width: 4, height: 4, borderRadius: 2, backgroundColor: Theme.brandBlue, marginTop: 4 },
  dotPh: { height: 8, marginTop: 4 },
});
