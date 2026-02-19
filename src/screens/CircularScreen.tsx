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
import { Circular } from '../types';
import { daysUntil, formatDate, generateId, isOverdue } from '../utils/helpers';
import { BorderRadius, Colors, FontSize, Shadow, Spacing } from '../utils/theme';

type ModalMode = 'none' | 'add' | 'detail';

export default function CircularScreen() {
  const { state, dispatch, saveCirculars } = useApp();
  const insets = useSafeAreaInsets();
  const [modalMode, setModalMode] = useState<ModalMode>('none');
  const [selected, setSelected] = useState<Circular | null>(null);
  const [form, setForm] = useState({ title: '', content: '', dueDate: '' });

  const sorted = [...state.circulars].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  const openDetail = (circular: Circular) => {
    setSelected(circular);
    setModalMode('detail');
  };

  const openAdd = () => {
    const due = new Date();
    due.setDate(due.getDate() + 7);
    setForm({
      title: '',
      content: '',
      dueDate: due.toISOString().split('T')[0],
    });
    setModalMode('add');
  };

  const handleSave = async () => {
    if (!form.title.trim()) {
      Alert.alert('エラー', 'タイトルを入力してください');
      return;
    }
    const now = new Date().toISOString();
    const newCircular: Circular = {
      id: generateId(),
      title: form.title.trim(),
      content: form.content.trim(),
      createdAt: now,
      dueDate: form.dueDate ? new Date(form.dueDate).toISOString() : now,
      status: 'active',
      residents: state.residents
        .sort((a, b) => a.householdNumber - b.householdNumber)
        .map((r) => ({
          residentId: r.id,
          residentName: r.name,
          passed: false,
        })),
    };
    dispatch({ type: 'ADD_CIRCULAR', payload: newCircular });
    await saveCirculars([...state.circulars, newCircular]);
    setModalMode('none');
  };

  const handleTogglePassed = async (circular: Circular, residentId: string) => {
    const updated: Circular = {
      ...circular,
      residents: circular.residents.map((r) =>
        r.residentId === residentId
          ? {
              ...r,
              passed: !r.passed,
              passedAt: !r.passed ? new Date().toISOString() : undefined,
            }
          : r
      ),
    };

    // すべて回覧済みなら完了に
    const allPassed = updated.residents.every((r) => r.passed);
    if (allPassed) updated.status = 'completed';

    dispatch({ type: 'UPDATE_CIRCULAR', payload: updated });
    const updatedList = state.circulars.map((c) => (c.id === updated.id ? updated : c));
    await saveCirculars(updatedList);
    setSelected(updated);
  };

  const handleComplete = async (circular: Circular) => {
    Alert.alert('完了確認', 'この回覧を完了にしますか？', [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '完了',
        onPress: async () => {
          const updated = { ...circular, status: 'completed' as const };
          dispatch({ type: 'UPDATE_CIRCULAR', payload: updated });
          const updatedList = state.circulars.map((c) =>
            c.id === updated.id ? updated : c
          );
          await saveCirculars(updatedList);
          setModalMode('none');
        },
      },
    ]);
  };

  const handleDelete = async (circular: Circular) => {
    Alert.alert('削除確認', `「${circular.title}」を削除しますか？`, [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除',
        style: 'destructive',
        onPress: async () => {
          dispatch({ type: 'DELETE_CIRCULAR', payload: circular.id });
          const updated = state.circulars.filter((c) => c.id !== circular.id);
          await saveCirculars(updated);
          setModalMode('none');
        },
      },
    ]);
  };

  const getProgressText = (circular: Circular) => {
    const passed = circular.residents.filter((r) => r.passed).length;
    return `${passed} / ${circular.residents.length}`;
  };

  const getProgressPercent = (circular: Circular) => {
    if (circular.residents.length === 0) return 0;
    return circular.residents.filter((r) => r.passed).length / circular.residents.length;
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>回覧板管理</Text>
      </View>

      <FlatList
        data={sorted}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ padding: Spacing.md, paddingBottom: insets.bottom + 80 }}
        renderItem={({ item }) => {
          const progress = getProgressPercent(item);
          const days = daysUntil(item.dueDate);
          const overdue = isOverdue(item.dueDate) && item.status === 'active';
          return (
            <Card style={styles.circularCard} onPress={() => openDetail(item)}>
              <View style={styles.cardHeader}>
                <View style={styles.titleRow}>
                  <Text style={styles.circularTitle} numberOfLines={1}>
                    {item.title}
                  </Text>
                  <Badge
                    label={item.status === 'completed' ? '完了' : '回覧中'}
                    color={item.status === 'completed' ? Colors.success : Colors.secondary}
                    size="sm"
                  />
                </View>
                <Text style={styles.circularDate}>
                  作成: {formatDate(item.createdAt)}
                </Text>
              </View>

              {item.status === 'active' && (
                <View style={styles.progressContainer}>
                  <View style={styles.progressBar}>
                    <View
                      style={[styles.progressFill, { width: `${progress * 100}%` }]}
                    />
                  </View>
                  <Text style={styles.progressText}>{getProgressText(item)}回覧済</Text>
                </View>
              )}

              {item.status === 'active' && (
                <View style={styles.dueRow}>
                  <Ionicons
                    name={overdue ? 'warning' : 'time-outline'}
                    size={14}
                    color={overdue ? Colors.error : Colors.textSecondary}
                  />
                  <Text style={[styles.dueText, overdue && { color: Colors.error }]}>
                    {overdue
                      ? `${Math.abs(days)}日超過`
                      : days === 0
                      ? '今日が期限'
                      : `残り${days}日`}
                  </Text>
                </View>
              )}
            </Card>
          );
        }}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="document-text-outline" size={48} color={Colors.textLight} />
            <Text style={styles.emptyText}>回覧板がありません</Text>
          </View>
        }
      />

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
              <Text style={styles.modalTitle} numberOfLines={1}>
                {selected.title}
              </Text>
              <TouchableOpacity onPress={() => handleDelete(selected)}>
                <Ionicons name="trash-outline" size={22} color={Colors.error} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.detailContent}>
              <Card style={styles.infoCard}>
                <Text style={styles.contentText}>{selected.content}</Text>
                <View style={styles.metaRow}>
                  <Ionicons name="calendar" size={14} color={Colors.textSecondary} />
                  <Text style={styles.metaText}>
                    期限: {formatDate(selected.dueDate, 'long')}
                  </Text>
                </View>
              </Card>

              {selected.status === 'active' && (
                <TouchableOpacity
                  style={styles.completeButton}
                  onPress={() => handleComplete(selected)}
                >
                  <Ionicons name="checkmark-circle" size={20} color={Colors.surface} />
                  <Text style={styles.completeButtonText}>回覧を完了にする</Text>
                </TouchableOpacity>
              )}

              <Text style={styles.sectionTitle}>回覧状況</Text>
              {selected.residents.map((rs, index) => (
                <TouchableOpacity
                  key={rs.residentId}
                  style={[
                    styles.residentRow,
                    rs.passed && styles.residentRowPassed,
                  ]}
                  onPress={() =>
                    selected.status === 'active' &&
                    handleTogglePassed(selected, rs.residentId)
                  }
                  activeOpacity={selected.status === 'active' ? 0.7 : 1}
                >
                  <View style={styles.orderBadge}>
                    <Text style={styles.orderText}>{index + 1}</Text>
                  </View>
                  <Text style={[styles.residentName, rs.passed && styles.passedText]}>
                    {rs.residentName}
                  </Text>
                  {rs.passed ? (
                    <View style={styles.passedBadge}>
                      <Ionicons name="checkmark" size={14} color={Colors.surface} />
                      <Text style={styles.passedBadgeText}>済</Text>
                    </View>
                  ) : (
                    <View style={styles.pendingBadge}>
                      <Text style={styles.pendingBadgeText}>未</Text>
                    </View>
                  )}
                </TouchableOpacity>
              ))}
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
            <Text style={styles.modalTitle}>回覧板作成</Text>
            <TouchableOpacity onPress={handleSave}>
              <Text style={styles.saveText}>作成</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.formContent}>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>タイトル *</Text>
              <TextInput
                style={styles.formInput}
                value={form.title}
                onChangeText={(t) => setForm((p) => ({ ...p, title: t }))}
                placeholder="例：○月定例会のお知らせ"
                placeholderTextColor={Colors.textLight}
              />
            </View>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>内容</Text>
              <TextInput
                style={[styles.formInput, styles.textArea]}
                value={form.content}
                onChangeText={(t) => setForm((p) => ({ ...p, content: t }))}
                placeholder="回覧板の内容を入力してください"
                placeholderTextColor={Colors.textLight}
                multiline
                numberOfLines={5}
              />
            </View>
            <View style={styles.formField}>
              <Text style={styles.formLabel}>期限（YYYY-MM-DD）</Text>
              <TextInput
                style={styles.formInput}
                value={form.dueDate}
                onChangeText={(t) => setForm((p) => ({ ...p, dueDate: t }))}
                placeholder="2024-12-31"
                placeholderTextColor={Colors.textLight}
                keyboardType="numbers-and-punctuation"
              />
            </View>

            <Card style={styles.residentsPreview}>
              <Text style={styles.previewTitle}>
                回覧対象: {state.residents.length}世帯
              </Text>
              <Text style={styles.previewSubtitle}>
                {state.residents
                  .sort((a, b) => a.householdNumber - b.householdNumber)
                  .map((r) => r.name)
                  .join(' → ')}
              </Text>
            </Card>
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
  circularCard: { marginBottom: Spacing.sm },
  cardHeader: { marginBottom: Spacing.sm },
  titleRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 },
  circularTitle: { flex: 1, fontSize: FontSize.md, fontWeight: '600', color: Colors.text, marginRight: Spacing.sm },
  circularDate: { fontSize: FontSize.xs, color: Colors.textSecondary },
  progressContainer: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, marginBottom: Spacing.xs },
  progressBar: { flex: 1, height: 6, backgroundColor: Colors.border, borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: Colors.primary, borderRadius: 3 },
  progressText: { fontSize: FontSize.xs, color: Colors.textSecondary, minWidth: 60 },
  dueRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  dueText: { fontSize: FontSize.xs, color: Colors.textSecondary },
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
  detailContent: { flex: 1, padding: Spacing.md },
  infoCard: { marginBottom: Spacing.md },
  contentText: { fontSize: FontSize.md, color: Colors.text, lineHeight: 22, marginBottom: Spacing.sm },
  metaRow: { flexDirection: 'row', alignItems: 'center', gap: Spacing.xs },
  metaText: { fontSize: FontSize.xs, color: Colors.textSecondary },
  completeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.success,
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.md,
    marginBottom: Spacing.md,
  },
  completeButtonText: { fontSize: FontSize.md, fontWeight: '600', color: Colors.surface },
  sectionTitle: { fontSize: FontSize.md, fontWeight: '700', color: Colors.text, marginBottom: Spacing.sm },
  residentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.surface,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.sm,
    marginBottom: Spacing.xs,
    ...Shadow.sm,
  },
  residentRowPassed: { backgroundColor: Colors.success + '10' },
  orderBadge: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: Colors.primary + '20',
    justifyContent: 'center',
    alignItems: 'center',
  },
  orderText: { fontSize: FontSize.xs, fontWeight: '700', color: Colors.primary },
  residentName: { flex: 1, fontSize: FontSize.md, color: Colors.text },
  passedText: { color: Colors.textSecondary, textDecorationLine: 'line-through' },
  passedBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.success,
    borderRadius: BorderRadius.round,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
    gap: 2,
  },
  passedBadgeText: { fontSize: FontSize.xs, color: Colors.surface, fontWeight: '700' },
  pendingBadge: {
    backgroundColor: Colors.warning,
    borderRadius: BorderRadius.round,
    paddingHorizontal: Spacing.sm,
    paddingVertical: 2,
  },
  pendingBadgeText: { fontSize: FontSize.xs, color: Colors.surface, fontWeight: '700' },
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
  textArea: { height: 120, textAlignVertical: 'top' },
  residentsPreview: { marginTop: Spacing.sm },
  previewTitle: { fontSize: FontSize.md, fontWeight: '600', color: Colors.text, marginBottom: Spacing.xs },
  previewSubtitle: { fontSize: FontSize.sm, color: Colors.textSecondary, lineHeight: 20 },
});
