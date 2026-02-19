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
import { FeeCollection } from '../types';
import { formatCurrency, formatDate, generateId } from '../utils/helpers';
import { BorderRadius, Colors, FontSize, Shadow, Spacing } from '../utils/theme';

type ModalMode = 'none' | 'add' | 'detail';

export default function FeesScreen() {
  const { state, dispatch, saveFees } = useApp();
  const insets = useSafeAreaInsets();
  const [modalMode, setModalMode] = useState<ModalMode>('none');
  const [selected, setSelected] = useState<FeeCollection | null>(null);
  const [form, setForm] = useState({ title: '', amount: '', dueDate: '' });

  const sorted = [...state.fees].sort(
    (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
  );

  const openDetail = (fee: FeeCollection) => {
    setSelected(fee);
    setModalMode('detail');
  };

  const openAdd = () => {
    const today = new Date();
    const lastDay = new Date(today.getFullYear(), today.getMonth() + 1, 0);
    setForm({
      title: `${today.getFullYear()}年度 町内会費`,
      amount: String(state.settings.annualFee),
      dueDate: lastDay.toISOString().split('T')[0],
    });
    setModalMode('add');
  };

  const handleSave = async () => {
    if (!form.title.trim()) {
      Alert.alert('エラー', 'タイトルを入力してください');
      return;
    }
    const amount = parseInt(form.amount);
    if (isNaN(amount) || amount <= 0) {
      Alert.alert('エラー', '正しい金額を入力してください');
      return;
    }
    const today = new Date();
    const newFee: FeeCollection = {
      id: generateId(),
      title: form.title.trim(),
      amount,
      dueDate: form.dueDate ? new Date(form.dueDate).toISOString() : new Date().toISOString(),
      year: today.getFullYear(),
      month: today.getMonth() + 1,
      status: 'open',
      createdAt: new Date().toISOString(),
      payments: state.residents.map((r) => ({
        residentId: r.id,
        residentName: r.name,
        paid: false,
        amount,
      })),
    };
    dispatch({ type: 'ADD_FEE', payload: newFee });
    await saveFees([...state.fees, newFee]);
    setModalMode('none');
  };

  const handleTogglePaid = async (fee: FeeCollection, residentId: string) => {
    const updated: FeeCollection = {
      ...fee,
      payments: fee.payments.map((p) =>
        p.residentId === residentId
          ? {
              ...p,
              paid: !p.paid,
              paidAt: !p.paid ? new Date().toISOString() : undefined,
            }
          : p
      ),
    };
    dispatch({ type: 'UPDATE_FEE', payload: updated });
    const updatedList = state.fees.map((f) => (f.id === updated.id ? updated : f));
    await saveFees(updatedList);
    setSelected(updated);
  };

  const handleClose = async (fee: FeeCollection) => {
    Alert.alert('締め切り確認', 'この集金を締め切りますか？', [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '締め切る',
        onPress: async () => {
          const updated = { ...fee, status: 'closed' as const };
          dispatch({ type: 'UPDATE_FEE', payload: updated });
          const updatedList = state.fees.map((f) => (f.id === updated.id ? updated : f));
          await saveFees(updatedList);
          setModalMode('none');
        },
      },
    ]);
  };

  const handleDelete = async (fee: FeeCollection) => {
    Alert.alert('削除確認', `「${fee.title}」を削除しますか？`, [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '削除',
        style: 'destructive',
        onPress: async () => {
          dispatch({ type: 'DELETE_FEE', payload: fee.id });
          const updated = state.fees.filter((f) => f.id !== fee.id);
          await saveFees(updated);
          setModalMode('none');
        },
      },
    ]);
  };

  const getPaidCount = (fee: FeeCollection) =>
    fee.payments.filter((p) => p.paid).length;

  const getTotalCollected = (fee: FeeCollection) =>
    fee.payments.filter((p) => p.paid).reduce((s, p) => s + (p.amount || fee.amount), 0);

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>集金管理</Text>
      </View>

      <FlatList
        data={sorted}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ padding: Spacing.md, paddingBottom: insets.bottom + 80 }}
        renderItem={({ item }) => {
          const paidCount = getPaidCount(item);
          const total = item.payments.length;
          const collected = getTotalCollected(item);
          const progress = total > 0 ? paidCount / total : 0;
          return (
            <Card style={styles.feeCard} onPress={() => openDetail(item)}>
              <View style={styles.cardHeader}>
                <Text style={styles.feeTitle}>{item.title}</Text>
                <Badge
                  label={item.status === 'closed' ? '締切済' : '受付中'}
                  color={item.status === 'closed' ? Colors.textSecondary : Colors.success}
                  size="sm"
                />
              </View>

              <View style={styles.amountRow}>
                <Text style={styles.amountLabel}>集金額</Text>
                <Text style={styles.amount}>{formatCurrency(item.amount)}/世帯</Text>
              </View>

              <View style={styles.progressContainer}>
                <View style={styles.progressBar}>
                  <View
                    style={[
                      styles.progressFill,
                      { width: `${progress * 100}%` },
                    ]}
                  />
                </View>
                <Text style={styles.progressText}>
                  {paidCount}/{total}件
                </Text>
              </View>

              <View style={styles.statsRow}>
                <View style={styles.stat}>
                  <Text style={styles.statLabel}>収納済</Text>
                  <Text style={[styles.statValue, { color: Colors.success }]}>
                    {formatCurrency(collected)}
                  </Text>
                </View>
                <View style={styles.stat}>
                  <Text style={styles.statLabel}>未収</Text>
                  <Text style={[styles.statValue, { color: Colors.error }]}>
                    {formatCurrency(item.amount * total - collected)}
                  </Text>
                </View>
                <View style={styles.stat}>
                  <Text style={styles.statLabel}>期限</Text>
                  <Text style={styles.statValue}>
                    {formatDate(item.dueDate, 'monthDay')}
                  </Text>
                </View>
              </View>
            </Card>
          );
        }}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="cash-outline" size={48} color={Colors.textLight} />
            <Text style={styles.emptyText}>集金管理がありません</Text>
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
              <Text style={styles.modalTitle} numberOfLines={1}>{selected.title}</Text>
              <TouchableOpacity onPress={() => handleDelete(selected)}>
                <Ionicons name="trash-outline" size={22} color={Colors.error} />
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.detailContent}>
              {/* 集計カード */}
              <View style={styles.summaryRow}>
                <View style={[styles.summaryCard, { backgroundColor: Colors.success }]}>
                  <Text style={styles.summaryLabel}>収納済</Text>
                  <Text style={styles.summaryValue}>
                    {formatCurrency(getTotalCollected(selected))}
                  </Text>
                  <Text style={styles.summaryCount}>
                    {getPaidCount(selected)}件
                  </Text>
                </View>
                <View style={[styles.summaryCard, { backgroundColor: Colors.error }]}>
                  <Text style={styles.summaryLabel}>未収</Text>
                  <Text style={styles.summaryValue}>
                    {formatCurrency(
                      selected.amount * selected.payments.length - getTotalCollected(selected)
                    )}
                  </Text>
                  <Text style={styles.summaryCount}>
                    {selected.payments.length - getPaidCount(selected)}件
                  </Text>
                </View>
              </View>

              {selected.status === 'open' && (
                <TouchableOpacity
                  style={styles.closeButton}
                  onPress={() => handleClose(selected)}
                >
                  <Ionicons name="lock-closed" size={18} color={Colors.surface} />
                  <Text style={styles.closeButtonText}>集金を締め切る</Text>
                </TouchableOpacity>
              )}

              <Text style={styles.sectionTitle}>支払い状況</Text>
              {selected.payments.map((payment) => (
                <TouchableOpacity
                  key={payment.residentId}
                  style={[
                    styles.paymentRow,
                    payment.paid && styles.paymentRowPaid,
                  ]}
                  onPress={() =>
                    selected.status === 'open' &&
                    handleTogglePaid(selected, payment.residentId)
                  }
                  activeOpacity={selected.status === 'open' ? 0.7 : 1}
                >
                  <Text style={styles.paymentName}>{payment.residentName}</Text>
                  <View style={styles.paymentRight}>
                    {payment.paid && payment.paidAt && (
                      <Text style={styles.paidDate}>
                        {formatDate(payment.paidAt, 'monthDay')}
                      </Text>
                    )}
                    <View
                      style={[
                        styles.statusBadge,
                        { backgroundColor: payment.paid ? Colors.success : Colors.error },
                      ]}
                    >
                      <Text style={styles.statusBadgeText}>
                        {payment.paid ? '済' : '未'}
                      </Text>
                    </View>
                  </View>
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
            <Text style={styles.modalTitle}>集金作成</Text>
            <TouchableOpacity onPress={handleSave}>
              <Text style={styles.saveText}>作成</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.formContent}>
            {[
              { label: 'タイトル *', key: 'title', placeholder: '○年度 町内会費', keyboardType: 'default' },
              { label: '金額（円）*', key: 'amount', placeholder: '3000', keyboardType: 'number-pad' },
              { label: '期限（YYYY-MM-DD）', key: 'dueDate', placeholder: '2024-03-31', keyboardType: 'numbers-and-punctuation' },
            ].map((field) => (
              <View key={field.key} style={styles.formField}>
                <Text style={styles.formLabel}>{field.label}</Text>
                <TextInput
                  style={styles.formInput}
                  value={(form as any)[field.key]}
                  onChangeText={(t) => setForm((p) => ({ ...p, [field.key]: t }))}
                  placeholder={field.placeholder}
                  placeholderTextColor={Colors.textLight}
                  keyboardType={field.keyboardType as any}
                  autoCapitalize="none"
                />
              </View>
            ))}
            <Card style={styles.residentsPreview}>
              <Text style={styles.previewTitle}>
                対象世帯: {state.residents.length}世帯
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
  feeCard: { marginBottom: Spacing.sm },
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: Spacing.sm,
  },
  feeTitle: { flex: 1, fontSize: FontSize.md, fontWeight: '600', color: Colors.text, marginRight: Spacing.sm },
  amountRow: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: Spacing.sm },
  amountLabel: { fontSize: FontSize.sm, color: Colors.textSecondary },
  amount: { fontSize: FontSize.sm, fontWeight: '600', color: Colors.text },
  progressContainer: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm, marginBottom: Spacing.sm },
  progressBar: { flex: 1, height: 6, backgroundColor: Colors.border, borderRadius: 3, overflow: 'hidden' },
  progressFill: { height: '100%', backgroundColor: Colors.success, borderRadius: 3 },
  progressText: { fontSize: FontSize.xs, color: Colors.textSecondary, minWidth: 40 },
  statsRow: { flexDirection: 'row', justifyContent: 'space-between' },
  stat: { alignItems: 'center' },
  statLabel: { fontSize: FontSize.xs, color: Colors.textSecondary },
  statValue: { fontSize: FontSize.sm, fontWeight: '600', color: Colors.text },
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
  summaryRow: { flexDirection: 'row', gap: Spacing.sm, marginBottom: Spacing.md },
  summaryCard: {
    flex: 1,
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
    alignItems: 'center',
    ...Shadow.sm,
  },
  summaryLabel: { fontSize: FontSize.xs, color: Colors.surface + 'CC' },
  summaryValue: { fontSize: FontSize.xl, fontWeight: '700', color: Colors.surface, marginTop: 2 },
  summaryCount: { fontSize: FontSize.xs, color: Colors.surface + 'CC' },
  closeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    backgroundColor: Colors.textSecondary,
    borderRadius: BorderRadius.md,
    paddingVertical: Spacing.md,
    marginBottom: Spacing.md,
  },
  closeButtonText: { fontSize: FontSize.md, fontWeight: '600', color: Colors.surface },
  sectionTitle: { fontSize: FontSize.md, fontWeight: '700', color: Colors.text, marginBottom: Spacing.sm },
  paymentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: Colors.surface,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.sm,
    marginBottom: Spacing.xs,
    ...Shadow.sm,
  },
  paymentRowPaid: { backgroundColor: Colors.success + '10' },
  paymentName: { fontSize: FontSize.md, color: Colors.text },
  paymentRight: { flexDirection: 'row', alignItems: 'center', gap: Spacing.sm },
  paidDate: { fontSize: FontSize.xs, color: Colors.textSecondary },
  statusBadge: {
    width: 28,
    height: 28,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusBadgeText: { fontSize: FontSize.xs, color: Colors.surface, fontWeight: '700' },
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
  residentsPreview: { marginTop: Spacing.sm },
  previewTitle: { fontSize: FontSize.md, fontWeight: '600', color: Colors.text },
});
