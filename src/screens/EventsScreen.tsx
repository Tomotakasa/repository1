import { Ionicons } from '@expo/vector-icons';
import React, { useState } from 'react';
import {
  Alert,
  FlatList,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Badge from '../components/common/Badge';
import Card from '../components/common/Card';
import { useApp } from '../store/AppContext';
import { Event, EventCategory } from '../types';
import {
  formatDate,
  generateId,
  getEventCategoryColor,
  getEventCategoryLabel,
} from '../utils/helpers';
import { BorderRadius, Colors, FontSize, Shadow, Spacing } from '../utils/theme';

type ModalMode = 'none' | 'add' | 'detail';

const CATEGORIES: EventCategory[] = ['meeting', 'cleanup', 'festival', 'emergency', 'other'];

export default function EventsScreen() {
  const { state, dispatch, saveEvents } = useApp();
  const insets = useSafeAreaInsets();
  const [modalMode, setModalMode] = useState<ModalMode>('none');
  const [selected, setSelected] = useState<Event | null>(null);
  const [form, setForm] = useState({
    title: '',
    description: '',
    startDate: '',
    location: '',
    category: 'meeting' as EventCategory,
    isAllDay: true,
  });
  const [filter, setFilter] = useState<'upcoming' | 'past' | 'all'>('upcoming');

  const now = new Date();

  const filtered = [...state.events]
    .filter((e) => {
      if (filter === 'upcoming') return new Date(e.startDate) >= now;
      if (filter === 'past') return new Date(e.startDate) < now;
      return true;
    })
    .sort((a, b) => {
      if (filter === 'past') {
        return new Date(b.startDate).getTime() - new Date(a.startDate).getTime();
      }
      return new Date(a.startDate).getTime() - new Date(b.startDate).getTime();
    });

  const openAdd = () => {
    const d = new Date();
    d.setDate(d.getDate() + 1);
    setForm({
      title: '',
      description: '',
      startDate: d.toISOString().split('T')[0],
      location: '',
      category: 'meeting',
      isAllDay: true,
    });
    setModalMode('add');
  };

  const handleSave = async () => {
    if (!form.title.trim()) {
      Alert.alert('エラー', 'タイトルを入力してください');
      return;
    }
    const newEvent: Event = {
      id: generateId(),
      title: form.title.trim(),
      description: form.description.trim() || undefined,
      startDate: form.startDate
        ? new Date(form.startDate).toISOString()
        : new Date().toISOString(),
      location: form.location.trim() || undefined,
      category: form.category,
      isAllDay: form.isAllDay,
      createdAt: new Date().toISOString(),
    };
    dispatch({ type: 'ADD_EVENT', payload: newEvent });
    await saveEvents([...state.events, newEvent]);
    setModalMode('none');
  };

  const handleDelete = async (event: Event) => {
    Alert.alert('削除確認', `「${event.title}」を削除しますか？`, [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除',
        style: 'destructive',
        onPress: async () => {
          dispatch({ type: 'DELETE_EVENT', payload: event.id });
          const updated = state.events.filter((e) => e.id !== event.id);
          await saveEvents(updated);
          setModalMode('none');
        },
      },
    ]);
  };

  // 月ごとにグループ化
  const groupByMonth = () => {
    const groups: Record<string, Event[]> = {};
    filtered.forEach((e) => {
      const d = new Date(e.startDate);
      const key = `${d.getFullYear()}年${d.getMonth() + 1}月`;
      if (!groups[key]) groups[key] = [];
      groups[key].push(e);
    });
    return Object.entries(groups).map(([month, events]) => ({ month, events }));
  };

  const groups = groupByMonth();

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>行事予定</Text>
      </View>

      {/* フィルタータブ */}
      <View style={styles.filterRow}>
        {([
          { key: 'upcoming', label: '今後' },
          { key: 'past', label: '過去' },
          { key: 'all', label: 'すべて' },
        ] as const).map((tab) => (
          <TouchableOpacity
            key={tab.key}
            style={[styles.filterTab, filter === tab.key && styles.filterTabActive]}
            onPress={() => setFilter(tab.key)}
          >
            <Text
              style={[
                styles.filterTabText,
                filter === tab.key && styles.filterTabTextActive,
              ]}
            >
              {tab.label}
            </Text>
          </TouchableOpacity>
        ))}
      </View>

      <ScrollView
        contentContainerStyle={{ padding: Spacing.md, paddingBottom: insets.bottom + 80 }}
      >
        {groups.length === 0 ? (
          <View style={styles.emptyContainer}>
            <Ionicons name="calendar-outline" size={48} color={Colors.textLight} />
            <Text style={styles.emptyText}>
              {filter === 'upcoming' ? '今後の行事はありません' : '行事がありません'}
            </Text>
          </View>
        ) : (
          groups.map(({ month, events: groupEvents }) => (
            <View key={month} style={styles.monthGroup}>
              <Text style={styles.monthLabel}>{month}</Text>
              {groupEvents.map((event) => (
                <Card
                  key={event.id}
                  style={styles.eventCard}
                  onPress={() => {
                    setSelected(event);
                    setModalMode('detail');
                  }}
                >
                  <View
                    style={[
                      styles.categoryBar,
                      { backgroundColor: getEventCategoryColor(event.category) },
                    ]}
                  />
                  <View style={styles.eventMain}>
                    <View style={styles.eventHeader}>
                      <Text style={styles.eventTitle}>{event.title}</Text>
                      <Badge
                        label={getEventCategoryLabel(event.category)}
                        color={getEventCategoryColor(event.category)}
                        size="sm"
                      />
                    </View>
                    <View style={styles.eventMeta}>
                      <Ionicons name="calendar-outline" size={13} color={Colors.textSecondary} />
                      <Text style={styles.eventDate}>
                        {formatDate(event.startDate, 'monthDay')}
                        {event.isAllDay ? '（終日）' : ''}
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
                    {event.description && (
                      <Text style={styles.eventDesc} numberOfLines={1}>
                        {event.description}
                      </Text>
                    )}
                  </View>
                </Card>
              ))}
            </View>
          ))
        )}
      </ScrollView>

      <TouchableOpacity
        style={[styles.fab, { bottom: insets.bottom + 80 }]}
        onPress={openAdd}
      >
        <Ionicons name="add" size={28} color={Colors.surface} />
      </TouchableOpacity>

      {/* 詳細モーダル */}
      <Modal visible={modalMode === 'detail'} animationType="slide" presentationStyle="pageSheet">
        {selected && (
          <View style={[styles.modalContainer, { paddingTop: insets.top }]}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setModalMode('none')}>
                <Ionicons name="close" size={24} color={Colors.text} />
              </TouchableOpacity>
              <Text style={styles.modalTitle} numberOfLines={1}>{selected.title}</Text>
              <TouchableOpacity onPress={() => handleDelete(selected)}>
                <Ionicons name="trash-outline" size={22} color={Colors.error} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.detailContent}>
              <View
                style={[
                  styles.categoryHeader,
                  { backgroundColor: getEventCategoryColor(selected.category) },
                ]}
              >
                <Ionicons name="calendar" size={32} color={Colors.surface} />
                <Text style={styles.categoryTitle}>
                  {getEventCategoryLabel(selected.category)}
                </Text>
              </View>

              <Card style={styles.detailCard}>
                {[
                  { icon: 'text', label: 'タイトル', value: selected.title },
                  {
                    icon: 'calendar',
                    label: '日時',
                    value: formatDate(selected.startDate, 'long') + (selected.isAllDay ? '（終日）' : ''),
                  },
                  { icon: 'location', label: '場所', value: selected.location || '未設定' },
                  { icon: 'document-text', label: '詳細', value: selected.description || '未設定' },
                ].map((item) => (
                  <View key={item.label} style={styles.detailRow}>
                    <Ionicons name={item.icon as any} size={18} color={Colors.primary} />
                    <View>
                      <Text style={styles.detailLabel}>{item.label}</Text>
                      <Text style={styles.detailValue}>{item.value}</Text>
                    </View>
                  </View>
                ))}
              </Card>
            </ScrollView>
          </View>
        )}
      </Modal>

      {/* 追加モーダル */}
      <Modal visible={modalMode === 'add'} animationType="slide" presentationStyle="pageSheet">
        <View style={[styles.modalContainer, { paddingTop: insets.top }]}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setModalMode('none')}>
              <Text style={styles.cancelText}>キャンセル</Text>
            </TouchableOpacity>
            <Text style={styles.modalTitle}>行事登録</Text>
            <TouchableOpacity onPress={handleSave}>
              <Text style={styles.saveText}>登録</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.formContent}>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>タイトル *</Text>
              <TextInput
                style={styles.formInput}
                value={form.title}
                onChangeText={(t) => setForm((p) => ({ ...p, title: t }))}
                placeholder="例：班長定例会議"
                placeholderTextColor={Colors.textLight}
              />
            </View>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>日付（YYYY-MM-DD）*</Text>
              <TextInput
                style={styles.formInput}
                value={form.startDate}
                onChangeText={(t) => setForm((p) => ({ ...p, startDate: t }))}
                placeholder="2024-12-31"
                placeholderTextColor={Colors.textLight}
                keyboardType="numbers-and-punctuation"
              />
            </View>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>場所</Text>
              <TextInput
                style={styles.formInput}
                value={form.location}
                onChangeText={(t) => setForm((p) => ({ ...p, location: t }))}
                placeholder="集会所"
                placeholderTextColor={Colors.textLight}
              />
            </View>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>カテゴリ</Text>
              <View style={styles.categoryGrid}>
                {CATEGORIES.map((cat) => (
                  <TouchableOpacity
                    key={cat}
                    style={[
                      styles.categoryOption,
                      form.category === cat && {
                        backgroundColor: getEventCategoryColor(cat),
                        borderColor: getEventCategoryColor(cat),
                      },
                    ]}
                    onPress={() => setForm((p) => ({ ...p, category: cat }))}
                  >
                    <Text
                      style={[
                        styles.categoryOptionText,
                        form.category === cat && { color: Colors.surface },
                      ]}
                    >
                      {getEventCategoryLabel(cat)}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>詳細</Text>
              <TextInput
                style={[styles.formInput, styles.textArea]}
                value={form.description}
                onChangeText={(t) => setForm((p) => ({ ...p, description: t }))}
                placeholder="行事の詳細を入力"
                placeholderTextColor={Colors.textLight}
                multiline
                numberOfLines={4}
              />
            </View>
          </ScrollView>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: {
    backgroundColor: Colors.primary,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
  },
  headerTitle: { fontSize: FontSize.xl, fontWeight: '700', color: Colors.surface },
  filterRow: {
    flexDirection: 'row',
    backgroundColor: Colors.surface,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
    gap: Spacing.sm,
  },
  filterTab: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.round,
  },
  filterTabActive: { backgroundColor: Colors.primary },
  filterTabText: { fontSize: FontSize.sm, color: Colors.textSecondary, fontWeight: '600' },
  filterTabTextActive: { color: Colors.surface },
  monthGroup: { marginBottom: Spacing.md },
  monthLabel: {
    fontSize: FontSize.sm,
    fontWeight: '700',
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
    paddingLeft: Spacing.xs,
  },
  eventCard: {
    flexDirection: 'row',
    marginBottom: Spacing.sm,
    padding: 0,
    overflow: 'hidden',
  },
  categoryBar: { width: 4 },
  eventMain: { flex: 1, padding: Spacing.md },
  eventHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  eventTitle: { flex: 1, fontSize: FontSize.md, fontWeight: '600', color: Colors.text, marginRight: Spacing.sm },
  eventMeta: { flexDirection: 'row', alignItems: 'center', gap: 4, marginBottom: 4 },
  eventDate: { fontSize: FontSize.xs, color: Colors.textSecondary },
  eventDesc: { fontSize: FontSize.xs, color: Colors.textSecondary, marginTop: 2 },
  emptyContainer: { alignItems: 'center', paddingTop: Spacing.xxl },
  emptyText: { marginTop: Spacing.md, fontSize: FontSize.md, color: Colors.textSecondary },
  fab: {
    position: 'absolute',
    right: Spacing.lg,
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    ...Shadow.lg,
  },
  modalContainer: { flex: 1, backgroundColor: Colors.background },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.md,
    backgroundColor: Colors.surface,
    borderBottomWidth: 1,
    borderBottomColor: Colors.border,
  },
  modalTitle: { flex: 1, textAlign: 'center', fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },
  cancelText: { fontSize: FontSize.md, color: Colors.textSecondary },
  saveText: { fontSize: FontSize.md, color: Colors.primary, fontWeight: '700' },
  detailContent: { flex: 1 },
  categoryHeader: {
    padding: Spacing.xl,
    alignItems: 'center',
    gap: Spacing.sm,
  },
  categoryTitle: { fontSize: FontSize.xl, fontWeight: '700', color: Colors.surface },
  detailCard: { margin: Spacing.md },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.divider,
  },
  detailLabel: { fontSize: FontSize.xs, color: Colors.textSecondary, marginBottom: 2 },
  detailValue: { fontSize: FontSize.md, color: Colors.text },
  formContent: { flex: 1, padding: Spacing.md },
  formField: { marginBottom: Spacing.md },
  formLabel: { fontSize: FontSize.sm, fontWeight: '600', color: Colors.textSecondary, marginBottom: Spacing.xs },
  formInput: {
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    fontSize: FontSize.md,
    color: Colors.text,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  textArea: { height: 100, textAlignVertical: 'top' },
  categoryGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: Spacing.sm },
  categoryOption: {
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.xs,
    borderRadius: BorderRadius.round,
    borderWidth: 1.5,
    borderColor: Colors.border,
  },
  categoryOptionText: { fontSize: FontSize.sm, color: Colors.textSecondary, fontWeight: '600' },
});
