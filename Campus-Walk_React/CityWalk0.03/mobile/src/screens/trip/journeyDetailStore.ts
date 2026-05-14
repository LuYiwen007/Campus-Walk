/** 与 iOS `JourneyDetailView.swift` / `JourneyDetailStore` 静态数据对齐 */

export type JourneyParticipant = { name: string };
export type JourneyActivity = { time: string; title: string; location: string };
export type JourneyDayPlan = { day: string; date: string; activities: JourneyActivity[] };
export type JourneyPhoto = { url: string; likes: number };
export type JourneyNote = { title: string; content: string; time: string };

export type JourneyDetailPayload = {
  title: string;
  dates: string;
  location: string;
  coverImage: string;
  description: string;
  participants: JourneyParticipant[];
  itinerary: JourneyDayPlan[];
  photos: JourneyPhoto[];
  notes: JourneyNote[];
};

const ALL: Record<string, JourneyDetailPayload> = {
  '1': {
    title: '苏州园林 3日游',
    dates: '2026年5月1日 - 5月3日',
    location: '江苏省苏州市',
    coverImage: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&h=400&fit=crop',
    description:
      '探索苏州古典园林的魅力，感受江南水乡的诗意。本次行程将游览拙政园、留园、虎丘等著名景点，品尝地道的苏州美食。',
    participants: [{ name: '张伟' }, { name: '李娜' }, { name: '王强' }],
    itinerary: [
      {
        day: 'Day 1',
        date: '5月1日',
        activities: [
          { time: '09:00', title: '抵达苏州', location: '苏州站' },
          { time: '10:30', title: '游览拙政园', location: '拙政园' },
          { time: '14:00', title: '午餐', location: '得月楼' },
          { time: '15:30', title: '游览苏州博物馆', location: '苏州博物馆' },
          { time: '18:00', title: '晚餐 & 平江路夜游', location: '平江路' },
        ],
      },
      {
        day: 'Day 2',
        date: '5月2日',
        activities: [
          { time: '09:00', title: '游览留园', location: '留园' },
          { time: '12:00', title: '午餐', location: '松鹤楼' },
          { time: '14:00', title: '游览虎丘', location: '虎丘风景区' },
          { time: '17:00', title: '山塘街漫步', location: '山塘街' },
        ],
      },
      {
        day: 'Day 3',
        date: '5月3日',
        activities: [
          { time: '09:00', title: '游览狮子林', location: '狮子林' },
          { time: '11:30', title: '观前街购物', location: '观前街' },
          { time: '14:00', title: '返程', location: '苏州站' },
        ],
      },
    ],
    photos: [
      { url: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=300&fit=crop', likes: 45 },
      { url: 'https://images.unsplash.com/photo-1580837119756-563d608dd119?w=400&h=300&fit=crop', likes: 32 },
      { url: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=400&h=300&fit=crop', likes: 28 },
      { url: 'https://images.unsplash.com/photo-1559628376-f3fe5f782a2e?w=400&h=300&fit=crop', likes: 51 },
    ],
    notes: [
      {
        title: '拙政园游览笔记',
        content: '园林设计精妙，移步换景。建议预留2-3小时游览时间。',
        time: '5月1日 11:30',
      },
      { title: '美食推荐', content: '得月楼的松鼠桂鱼和响油鳝糊值得一试！', time: '5月1日 14:45' },
    ],
  },
  '2': {
    title: '杭州西湖 2日游',
    dates: '2026年4月15日 - 4月16日',
    location: '浙江省杭州市',
    coverImage: 'https://images.unsplash.com/photo-1545893835-abaa50cbe628?w=800&h=400&fit=crop',
    description:
      '漫步西湖，感受杭州的诗情画意。游览雷峰塔、灵隐寺等著名景点，品尝龙井茶和杭州特色美食。',
    participants: [{ name: '陈明' }, { name: '刘芳' }],
    itinerary: [
      {
        day: 'Day 1',
        date: '4月15日',
        activities: [
          { time: '09:00', title: '西湖游船', location: '西湖' },
          { time: '11:00', title: '雷峰塔', location: '雷峰塔' },
          { time: '14:00', title: '午餐', location: '楼外楼' },
          { time: '15:30', title: '灵隐寺', location: '灵隐寺' },
        ],
      },
      {
        day: 'Day 2',
        date: '4月16日',
        activities: [
          { time: '08:00', title: '龙井村品茶', location: '龙井村' },
          { time: '11:00', title: '南宋御街', location: '南宋御街' },
          { time: '14:00', title: '返程', location: '杭州东站' },
        ],
      },
    ],
    photos: [
      { url: 'https://images.unsplash.com/photo-1545893835-abaa50cbe628?w=400&h=300&fit=crop', likes: 67 },
      { url: 'https://images.unsplash.com/photo-1591948582167-cf92194c4454?w=400&h=300&fit=crop', likes: 43 },
    ],
    notes: [{ title: '西湖美景', content: '四月的西湖美不胜收，桃花盛开。', time: '4月15日 10:00' }],
  },
  '3': {
    title: '北京故宫 1日游',
    dates: '2026年5月7日',
    location: '北京市东城区',
    coverImage: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=800&h=400&fit=crop',
    description: '探访紫禁城，感受中华文化的博大精深。游览故宫博物院，欣赏古代建筑艺术的瑰宝。',
    participants: [{ name: '王磊' }],
    itinerary: [
      {
        day: 'Day 1',
        date: '5月7日',
        activities: [
          { time: '08:30', title: '抵达故宫', location: '午门' },
          { time: '09:00', title: '太和殿参观', location: '太和殿' },
          { time: '11:00', title: '珍宝馆', location: '珍宝馆' },
          { time: '13:00', title: '午餐', location: '故宫餐厅' },
          { time: '14:30', title: '御花园', location: '御花园' },
          { time: '16:00', title: '离开故宫', location: '神武门' },
        ],
      },
    ],
    photos: [{ url: 'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=400&h=300&fit=crop', likes: 89 }],
    notes: [{ title: '参观提示', content: '建议提前网上预约门票，避免排队等候。', time: '5月7日 08:00' }],
  },
  '4': {
    title: '上海外滩 2日游',
    dates: '2026年5月20日 - 5月21日',
    location: '上海市黄浦区',
    coverImage: 'https://images.unsplash.com/photo-1537981576259-a1a7d4d06a5f?w=800&h=400&fit=crop',
    description:
      '感受魔都的繁华与魅力，漫步外滩，欣赏浦江两岸的美景，品味上海的独特韵味。',
    participants: [{ name: '赵丽' }, { name: '孙军' }, { name: '周芳' }, { name: '吴强' }],
    itinerary: [
      {
        day: 'Day 1',
        date: '5月20日',
        activities: [
          { time: '10:00', title: '外滩漫步', location: '外滩' },
          { time: '12:00', title: '南京路购物', location: '南京路步行街' },
          { time: '14:00', title: '午餐', location: '老上海菜馆' },
          { time: '16:00', title: '豫园游览', location: '豫园' },
          { time: '19:00', title: '浦东夜景', location: '东方明珠' },
        ],
      },
      {
        day: 'Day 2',
        date: '5月21日',
        activities: [
          { time: '09:00', title: '田子坊', location: '田子坊' },
          { time: '12:00', title: '新天地', location: '新天地' },
          { time: '15:00', title: '返程', location: '上海虹桥站' },
        ],
      },
    ],
    photos: [
      { url: 'https://images.unsplash.com/photo-1537981576259-a1a7d4d06a5f?w=400&h=300&fit=crop', likes: 124 },
      { url: 'https://images.unsplash.com/photo-1548919973-5cef591cdbc9?w=400&h=300&fit=crop', likes: 98 },
    ],
    notes: [{ title: '外滩夜景', content: '晚上的外滩灯火辉煌，非常适合拍照。', time: '5月20日 20:00' }],
  },
};

export function getJourneyDetailPayload(journeyId: string): JourneyDetailPayload | undefined {
  return ALL[journeyId];
}
