import { Image } from 'expo-image';
import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import * as Api from '../api/client';
import type { CommunityPostDTO } from '../api/types';
import { Theme } from '../theme';

function PostDetail({ post, onClose }: { post: CommunityPostDTO; onClose: () => void }) {
  return (
    <Modal visible animationType="slide" presentationStyle="pageSheet" onRequestClose={onClose}>
      <SafeAreaView style={styles.detailRoot}>
        <View style={styles.detailHeader}>
          <Pressable onPress={onClose}>
            <Text style={styles.detailClose}>关闭</Text>
          </Pressable>
        </View>
        <ScrollView contentContainerStyle={{ paddingBottom: 40 }}>
          <Image source={{ uri: post.cover_image_url }} style={styles.detailHero} contentFit="cover" />
          <Text style={styles.detailTitle}>{post.title}</Text>
          <Text style={styles.detailBody}>{post.body}</Text>
        </ScrollView>
      </SafeAreaView>
    </Modal>
  );
}

export function CommunityScreen() {
  const [posts, setPosts] = useState<CommunityPostDTO[]>([]);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [selected, setSelected] = useState<CommunityPostDTO | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const rows = await Api.communityPosts();
      setPosts(rows);
    } catch (e) {
      setErr(e instanceof Error ? e.message : String(e));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <SafeAreaView style={styles.root} edges={['top']}>
      <View style={styles.topBar}>
        <Pressable
          onPress={() => Alert.alert('菜单', '侧栏个人资料与 iOS UserProfileView 一致，RN 版可后续接入完整抽屉。')}
          hitSlop={10}
        >
          <Text style={styles.menuIcon}>≡</Text>
        </Pressable>
        <Text style={styles.topTitle}>社区</Text>
        <View style={{ width: 28 }} />
      </View>
      <View style={styles.divider} />

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator />
          <Text style={styles.muted}>加载中…</Text>
        </View>
      ) : err ? (
        <View style={styles.center}>
          <Text style={styles.muted}>{err}</Text>
        </View>
      ) : (
        <ScrollView contentContainerStyle={styles.listPad}>
          {posts.map((p) => (
            <Pressable key={p.id} onPress={() => setSelected(p)} style={styles.card}>
              <Image source={{ uri: p.cover_image_url }} style={styles.cover} contentFit="cover" />
              <View style={styles.cardBody}>
                <Text style={styles.cardTitle}>{p.title}</Text>
                <View style={styles.cardMeta}>
                  <Text style={styles.author} numberOfLines={1}>
                    {p.author_display_name}
                  </Text>
                  <View style={styles.likes}>
                    <Text style={styles.likeIcon}>♡</Text>
                    <Text style={styles.muted}>{p.likes_count}</Text>
                  </View>
                </View>
              </View>
            </Pressable>
          ))}
          <View style={{ height: 120 }} />
        </ScrollView>
      )}

      {selected ? <PostDetail post={selected} onClose={() => setSelected(null)} /> : null}
    </SafeAreaView>
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
    backgroundColor: 'rgba(255,255,255,0.94)',
  },
  menuIcon: { fontSize: 22, color: '#737A85', lineHeight: 28 },
  topTitle: { fontSize: 16, fontWeight: '500', color: '#474A54' },
  divider: { height: 1, backgroundColor: Theme.borderSubtle },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: 24 },
  muted: { color: Theme.textMuted, marginTop: 8 },
  listPad: { paddingHorizontal: 24, paddingTop: 32, paddingBottom: 32, gap: 32 },
  card: {
    borderRadius: Theme.cornerCard,
    borderWidth: 1,
    borderColor: Theme.cardStroke,
    overflow: 'hidden',
    backgroundColor: '#fff',
  },
  cover: { width: '100%', height: Theme.postImageHeight, backgroundColor: 'rgba(0,0,0,0.06)' },
  cardBody: { padding: 16, gap: 16 },
  cardTitle: { fontSize: 17, fontWeight: '500', color: '#1F2326', lineHeight: 22 },
  cardMeta: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  author: { flex: 1, fontSize: 14, color: Theme.textMuted, marginRight: 12 },
  likes: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  likeIcon: { fontSize: 14, color: Theme.textMuted },
  detailRoot: { flex: 1, backgroundColor: '#fff' },
  detailHeader: { paddingHorizontal: 16, paddingVertical: 8 },
  detailClose: { color: Theme.brandBlue, fontSize: 16 },
  detailHero: { width: '100%', height: 220, backgroundColor: Theme.surfaceGray50 },
  detailTitle: { fontSize: 20, fontWeight: '600', paddingHorizontal: 20, marginTop: 16, color: Theme.textPrimary },
  detailBody: { fontSize: 15, lineHeight: 22, paddingHorizontal: 20, marginTop: 12, color: Theme.textSecondary },
});
