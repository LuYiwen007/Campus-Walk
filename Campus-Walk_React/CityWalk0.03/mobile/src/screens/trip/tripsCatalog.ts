/** 与 iOS `TripView.swift` 中 `allTrips` 对齐 */

export type TripRecord = {
  id: string;
  title: string;
  datesLabel: string;
  locationsLabel: string;
  startMs: number;
  endMs: number;
  participantCount: number;
  detailId: string | null;
  coverImageURL: string | null;
};

function d(y: number, m: number, day: number): number {
  return new Date(y, m - 1, day, 12, 0, 0, 0).getTime();
}

export const TRIPS_CATALOG: TripRecord[] = [
  {
    id: 'jp',
    title: '日本历史8天行程',
    datesLabel: '8天7晚',
    locationsLabel: '30个地点',
    startMs: d(2026, 5, 6),
    endMs: d(2026, 5, 13),
    participantCount: 1,
    detailId: null,
    coverImageURL: null,
  },
  {
    id: '1',
    title: '苏州园林 3日游',
    datesLabel: '5月1日 - 5月3日, 2026',
    locationsLabel: '9个地点',
    startMs: d(2026, 5, 1),
    endMs: d(2026, 5, 3),
    participantCount: 3,
    detailId: '1',
    coverImageURL: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=200&fit=crop',
  },
  {
    id: '2',
    title: '杭州西湖 2日游',
    datesLabel: '4月15日 - 4月16日, 2026',
    locationsLabel: '8个地点',
    startMs: d(2026, 4, 15),
    endMs: d(2026, 4, 16),
    participantCount: 2,
    detailId: '2',
    coverImageURL: 'https://images.unsplash.com/photo-1545893835-abaa50cbe628?w=400&h=200&fit=crop',
  },
  {
    id: '3',
    title: '北京故宫 1日游',
    datesLabel: '5月7日, 2026',
    locationsLabel: '6个地点',
    startMs: d(2026, 5, 7),
    endMs: d(2026, 5, 7),
    participantCount: 1,
    detailId: '3',
    coverImageURL: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=200&fit=crop',
  },
  {
    id: '4',
    title: '上海外滩 2日游',
    datesLabel: '5月20日 - 5月21日, 2026',
    locationsLabel: '10个地点',
    startMs: d(2026, 5, 20),
    endMs: d(2026, 5, 21),
    participantCount: 4,
    detailId: '4',
    coverImageURL: 'https://images.unsplash.com/photo-1537981576259-a1a7d4d06a5f?w=400&h=200&fit=crop',
  },
];
