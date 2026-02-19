import { Ionicons } from '@expo/vector-icons';
import React from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Badge from '../components/common/Badge';
import Card from '../components/common/Card';
import { useApp } from '../store/AppContext';
import { Notice } from '../types';
import {
  formatDate,
  formatRelativeTime,
  getEventCategoryColor,
  getEventCategoryLabel,
  getNoticeCategoryColor,
  getNoticeCategoryLabel,
} from '../utils/helpers';
import { BorderRadius, Colors, FontSize, Shadow, Spacing } from '../utils/theme';

export default function HomeScreen({ navigation }: any) {
  const { state, dispatch } = useApp();
  const insets = useSafeAreaInsets();

  const today = new Date();
  const unreadNotices = state.notices.filter((n) => !n.isRead);
  const pendingCirculars = state.circulars.filter((c) => c.status === 'active');
  const openFees = state.fees.filter((f) => f.status === 'open');
  const unpaidCount = openFees.reduce((sum, f) => {
    return sum + f.payments.filter((p) => !p.paid).length;
  }, 0);

  const upcomingEvents = state.events
    .filter((e) => new Date(e.startDate) >= today)
    .sort((a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime())
    .slice(0, 3);

  const handleMarkRead = (notice: Notice) => {
    dispatch({ type: 'MARK_NOTICE_READ', payload: notice.id });
  };

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={{ paddingBottom: insets.bottom + Spacing.xl }}
      showsVerticalScrollIndicator={false}
    >
      {/* ヘッダー */}
      <View style={[styles.header, { paddingTop: insets.top + Spacing.md }]}>
        <View>
          <Text style={styles.headerTitle}>
            {state.settings.organizationName}
          </Text>
          <Text style={styles.headerSubtitle}>
            {state.settings.blockName}
            {state.settings.leaderName ? ` 班長: ${state.settings.leaderName}` : ''}
          </Text>
        </View>
        <TouchableOpacity
          style={styles.settingsButton}
          onPress={() => navigation.navigate('Settings')}
        >
          <Ionicons name="settings-outline" size={24} color={Colors.surface} />
        </TouchableOpacity>
      </View>

      <View style={styles.content}>
        {/* サマリーカード */}
        <View style={styles.summaryRow}>
          <TouchableOpacity
            style={[styles.summaryCard, { backgroundColor: Colors.primary }]}
            onPress={() => navigation.navigate('Residents')}
          >
            <Ionicons name="people" size={28} color={Colors.surface} />
            <Text style={styles.summaryNumber}>{state.residents.length}</Text>
            <Text style={styles.summaryLabel}>世帯</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.summaryCard, { backgroundColor: Colors.secondary }]}
            onPress={() => navigation.navigate('Circular')}
          >
            <Ionicons name="document-text" size={28} color={Colors.surface} />
            <Text style={styles.summaryNumber}>{pendingCirculars.length}</Text>
            <Text style={styles.summaryLabel}>回覧中</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.summaryCard, { backgroundColor: unpaidCount > 0 ? Colors.error : Colors.success }]}
            onPress={() => navigation.navigate('Fees')}
          >
            <Ionicons name="cash" size={28} color={Colors.surface} />
            <Text style={styles.summaryNumber}>{unpaidCount}</Text>
            <Text style={styles.summaryLabel}>未収金</Text>
          </TouchableOpacity>
        </View>

        {/* お知らせ */}
        {unreadNotices.length > 0 && (
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>お知らせ ({unreadNotices.length}件)</Text>
            {unreadNotices.map((notice) => (
              <Card
                key={notice.id}
                style={styles.noticeCard}
                onPress={() => handleMarkRead(notice)}
              >
                <View style={styles.noticeHeader}>
                  <Badge
                    label={getNoticeCategoryLabel(notice.category)}
                    color={getNoticeCategoryColor(notice.category)}
                    size="sm"
                  />
                  <Text style={styles.noticeTime}>
                    {formatRelativeTime(notice.createdAt)}
                  </Text>
                </View>
                <Text style={styles.noticeTitle}>{notice.title}</Text>
                <Text style={styles.noticeContent} numberOfLines={2}>
                  {notice.content}
                </Text>
              </Card>
            ))}
          </View>
        )}

        {/* 直近の行事 */}
        <View style={styles.section}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>直近の行事</Text>
            <TouchableOpacity onPress={() => navigation.navigate('Events')}>
              <Text style={styles.sectionMore}>すべて見る</Text>
            </TouchableOpacity>
          </View>
          {upcomingEvents.length === 0 ? (
            <Card style={styles.emptyCard}>
              <Text style={styles.emptyText}>予定されている行事はありません</Text>
            </Card>
          ) : (
            upcomingEvents.map((event) => (
              <Card key={event.id} style={styles.eventCard}>
                <View
                  style={[
                    styles.eventCategoryDot,
                    { backgroundColor: getEventCategoryColor(event.category) },
                  ]}
                />
                <View style={styles.eventInfo}>
                  <Text style={styles.eventTitle}>{event.title}</Text>
                  <View style={styles.eventMeta}>
                    <Ionicons
                      name="calendar-outline"
                      size={13}
                      color={Colors.textSecondary}
                    />
                    <Text style={styles.eventDate}>
                      {formatDate(event.startDate, 'monthDay')}
                    </Text>
                    {event.location && (
                      <>
                        <Ionicons
                          name="location-outline"
                          size={13}
                          color={Colors.textSecondary}
                          style={{ marginLeft: Spacing.sm }}
                        />
                        <Text style={styles.eventDate}>{event.location}</Text>
                      </>
                    )}
                  </View>
                </View>
                <Badge
                  label={getEventCategoryLabel(event.category)}
                  color={getEventCategoryColor(event.category)}
                  size="sm"
                />
              </Card>
            ))
          )}
        </View>

        {/* クイックアクセス */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>クイックアクセス</Text>
          <View style={styles.quickGrid}>
            {[
              { icon: 'person-add', label: '住民追加', screen: 'Residents', color: Colors.primary },
              { icon: 'document-text', label: '回覧作成', screen: 'Circular', color: Colors.secondary },
              { icon: 'cash', label: '集金管理', screen: 'Fees', color: Colors.warning },
              { icon: 'calendar', label: '行事登録', screen: 'Events', color: Colors.info },
            ].map((item) => (
              <TouchableOpacity
                key={item.label}
                style={[styles.quickItem, { borderColor: item.color + '40' }]}
                onPress={() => navigation.navigate(item.screen)}
                activeOpacity={0.7}
              >
                <View style={[styles.quickIcon, { backgroundColor: item.color + '15' }]}>
                  <Ionicons name={item.icon as any} size={24} color={item.color} />
                </View>
                <Text style={[styles.quickLabel, { color: item.color }]}>{item.label}</Text>
              </TouchableOpacity>
            ))}
          </View>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: Colors.background,
  },
  header: {
    backgroundColor: Colors.primary,
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.lg,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  headerTitle: {
    fontSize: FontSize.xl,
    fontWeight: '700',
    color: Colors.surface,
    marginBottom: 2,
  },
  headerSubtitle: {
    fontSize: FontSize.md,
    color: Colors.surface + 'CC',
  },
  settingsButton: {
    padding: Spacing.xs,
  },
  content: {
    padding: Spacing.md,
    marginTop: -Spacing.md,
  },
  summaryRow: {
    flexDirection: 'row',
    gap: Spacing.sm,
    marginBottom: Spacing.lg,
    marginTop: Spacing.sm,
  },
  summaryCard: {
    flex: 1,
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
    alignItems: 'center',
    ...Shadow.md,
  },
  summaryNumber: {
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.surface,
    marginTop: Spacing.xs,
  },
  summaryLabel: {
    fontSize: FontSize.xs,
    color: Colors.surface + 'CC',
    marginTop: 2,
  },
  section: {
    marginBottom: Spacing.lg,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  sectionTitle: {
    fontSize: FontSize.md,
    fontWeight: '700',
    color: Colors.text,
    marginBottom: Spacing.sm,
  },
  sectionMore: {
    fontSize: FontSize.sm,
    color: Colors.primary,
    fontWeight: '600',
  },
  noticeCard: {
    marginBottom: Spacing.sm,
    borderLeftWidth: 3,
    borderLeftColor: Colors.error,
  },
  noticeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  noticeTime: {
    fontSize: FontSize.xs,
    color: Colors.textSecondary,
  },
  noticeTitle: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: Spacing.xs,
  },
  noticeContent: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    lineHeight: 18,
  },
  eventCard: {
    marginBottom: Spacing.sm,
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
  },
  eventCategoryDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    flexShrink: 0,
  },
  eventInfo: {
    flex: 1,
  },
  eventTitle: {
    fontSize: FontSize.md,
    fontWeight: '600',
    color: Colors.text,
    marginBottom: 2,
  },
  eventMeta: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  eventDate: {
    fontSize: FontSize.xs,
    color: Colors.textSecondary,
  },
  emptyCard: {
    alignItems: 'center',
    paddingVertical: Spacing.lg,
  },
  emptyText: {
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
  },
  quickGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
  },
  quickItem: {
    width: '47%',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
    alignItems: 'center',
    borderWidth: 1,
    ...Shadow.sm,
  },
  quickIcon: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: Spacing.xs,
  },
  quickLabel: {
    fontSize: FontSize.sm,
    fontWeight: '600',
  },
});
