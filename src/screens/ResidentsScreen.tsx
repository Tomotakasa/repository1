import { Ionicons } from '@expo/vector-icons';
import React, { useState } from 'react';
import {
  Alert,
  FlatList,
  Linking,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  TouchableOpacity,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import Card from '../components/common/Card';
import { useApp } from '../store/AppContext';
import { Resident } from '../types';
import { generateId } from '../utils/helpers';
import { BorderRadius, Colors, FontSize, Shadow, Spacing } from '../utils/theme';

type ModalMode = 'none' | 'add' | 'edit' | 'detail';

const EMPTY_RESIDENT: Omit<Resident, 'id' | 'createdAt' | 'updatedAt'> = {
  name: '',
  kana: '',
  address: '',
  phone: '',
  email: '',
  note: '',
  householdNumber: 0,
};

export default function ResidentsScreen() {
  const { state, dispatch, saveResidents } = useApp();
  const insets = useSafeAreaInsets();
  const [search, setSearch] = useState('');
  const [modalMode, setModalMode] = useState<ModalMode>('none');
  const [selectedResident, setSelectedResident] = useState<Resident | null>(null);
  const [form, setForm] = useState(EMPTY_RESIDENT);

  const filtered = state.residents
    .filter(
      (r) =>
        r.name.includes(search) ||
        r.kana.includes(search) ||
        r.address.includes(search)
    )
    .sort((a, b) => a.householdNumber - b.householdNumber);

  const openAdd = () => {
    setForm({ ...EMPTY_RESIDENT, householdNumber: state.residents.length + 1 });
    setModalMode('add');
  };

  const openEdit = (resident: Resident) => {
    setSelectedResident(resident);
    setForm({ ...resident });
    setModalMode('edit');
  };

  const openDetail = (resident: Resident) => {
    setSelectedResident(resident);
    setModalMode('detail');
  };

  const handleSave = async () => {
    if (!form.name.trim()) {
      Alert.alert('エラー', '氏名を入力してください');
      return;
    }
    if (!form.phone.trim()) {
      Alert.alert('エラー', '電話番号を入力してください');
      return;
    }

    const now = new Date().toISOString();
    let updatedResidents: Resident[];

    if (modalMode === 'add') {
      const newResident: Resident = {
        ...form,
        id: generateId(),
        createdAt: now,
        updatedAt: now,
      };
      dispatch({ type: 'ADD_RESIDENT', payload: newResident });
      updatedResidents = [...state.residents, newResident];
    } else {
      const updated: Resident = {
        ...selectedResident!,
        ...form,
        updatedAt: now,
      };
      dispatch({ type: 'UPDATE_RESIDENT', payload: updated });
      updatedResidents = state.residents.map((r) =>
        r.id === updated.id ? updated : r
      );
    }

    await saveResidents(updatedResidents);
    setModalMode('none');
  };

  const handleDelete = (resident: Resident) => {
    Alert.alert(
      '削除確認',
      `「${resident.name}」を削除しますか？`,
      [
        { text: 'キャンセル', style: 'cancel' },
        {
          text: '削除',
          style: 'destructive',
          onPress: async () => {
            dispatch({ type: 'DELETE_RESIDENT', payload: resident.id });
            const updated = state.residents.filter((r) => r.id !== resident.id);
            await saveResidents(updated);
            setModalMode('none');
          },
        },
      ]
    );
  };

  const callPhone = (phone: string) => {
    Linking.openURL(`tel:${phone}`);
  };

  return (
    <View style={[styles.container, { paddingTop: insets.top }]}>
      {/* ヘッダー */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>住民名簿</Text>
        <Text style={styles.headerCount}>{state.residents.length}世帯</Text>
      </View>

      {/* 検索 */}
      <View style={styles.searchContainer}>
        <Ionicons name="search" size={18} color={Colors.textSecondary} />
        <TextInput
          style={styles.searchInput}
          value={search}
          onChangeText={setSearch}
          placeholder="氏名・住所で検索"
          placeholderTextColor={Colors.textLight}
        />
        {search.length > 0 && (
          <TouchableOpacity onPress={() => setSearch('')}>
            <Ionicons name="close-circle" size={18} color={Colors.textSecondary} />
          </TouchableOpacity>
        )}
      </View>

      {/* リスト */}
      <FlatList
        data={filtered}
        keyExtractor={(item) => item.id}
        contentContainerStyle={{ padding: Spacing.md, paddingBottom: insets.bottom + 80 }}
        renderItem={({ item }) => (
          <Card style={styles.residentCard} onPress={() => openDetail(item)}>
            <View style={styles.residentNumber}>
              <Text style={styles.numberText}>{item.householdNumber}</Text>
            </View>
            <View style={styles.residentInfo}>
              <Text style={styles.residentName}>{item.name}</Text>
              <Text style={styles.residentKana}>{item.kana}</Text>
              <Text style={styles.residentAddress}>{item.address}</Text>
            </View>
            <TouchableOpacity
              style={styles.phoneButton}
              onPress={() => callPhone(item.phone)}
            >
              <Ionicons name="call" size={20} color={Colors.primary} />
            </TouchableOpacity>
          </Card>
        )}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Ionicons name="people-outline" size={48} color={Colors.textLight} />
            <Text style={styles.emptyText}>住民が登録されていません</Text>
          </View>
        }
      />

      {/* 追加ボタン */}
      <TouchableOpacity
        style={[styles.fab, { bottom: insets.bottom + 80 }]}
        onPress={openAdd}
      >
        <Ionicons name="add" size={28} color={Colors.surface} />
      </TouchableOpacity>

      {/* 詳細モーダル */}
      <Modal visible={modalMode === 'detail'} animationType="slide" presentationStyle="pageSheet">
        {selectedResident && (
          <View style={[styles.modalContainer, { paddingTop: insets.top }]}>
            <View style={styles.modalHeader}>
              <TouchableOpacity onPress={() => setModalMode('none')}>
                <Ionicons name="close" size={24} color={Colors.text} />
              </TouchableOpacity>
              <Text style={styles.modalTitle}>住民詳細</Text>
              <TouchableOpacity onPress={() => openEdit(selectedResident)}>
                <Text style={styles.editText}>編集</Text>
              </TouchableOpacity>
            </View>

            <ScrollView style={styles.detailContent}>
              <View style={styles.detailAvatar}>
                <Text style={styles.avatarText}>
                  {selectedResident.name.charAt(0)}
                </Text>
              </View>
              <Text style={styles.detailName}>{selectedResident.name}</Text>
              <Text style={styles.detailKana}>{selectedResident.kana}</Text>

              <Card style={styles.detailCard}>
                {[
                  { icon: 'home', label: '住所', value: selectedResident.address },
                  { icon: 'call', label: '電話番号', value: selectedResident.phone },
                  { icon: 'mail', label: 'メール', value: selectedResident.email || '未登録' },
                  { icon: 'list', label: '班番号', value: `${selectedResident.householdNumber}番` },
                ].map((item) => (
                  <View key={item.label} style={styles.detailRow}>
                    <Ionicons name={item.icon as any} size={18} color={Colors.primary} />
                    <View style={styles.detailRowContent}>
                      <Text style={styles.detailLabel}>{item.label}</Text>
                      <Text style={styles.detailValue}>{item.value}</Text>
                    </View>
                  </View>
                ))}
                {selectedResident.note && (
                  <View style={styles.detailRow}>
                    <Ionicons name="document-text" size={18} color={Colors.primary} />
                    <View style={styles.detailRowContent}>
                      <Text style={styles.detailLabel}>備考</Text>
                      <Text style={styles.detailValue}>{selectedResident.note}</Text>
                    </View>
                  </View>
                )}
              </Card>

              <View style={styles.actionButtons}>
                <TouchableOpacity
                  style={[styles.actionBtn, { backgroundColor: Colors.primary }]}
                  onPress={() => callPhone(selectedResident.phone)}
                >
                  <Ionicons name="call" size={20} color={Colors.surface} />
                  <Text style={styles.actionBtnText}>電話する</Text>
                </TouchableOpacity>
                {selectedResident.email && (
                  <TouchableOpacity
                    style={[styles.actionBtn, { backgroundColor: Colors.info }]}
                    onPress={() => Linking.openURL(`mailto:${selectedResident.email}`)}
                  >
                    <Ionicons name="mail" size={20} color={Colors.surface} />
                    <Text style={styles.actionBtnText}>メール</Text>
                  </TouchableOpacity>
                )}
              </View>

              <TouchableOpacity
                style={styles.deleteButton}
                onPress={() => handleDelete(selectedResident)}
              >
                <Text style={styles.deleteText}>この住民を削除</Text>
              </TouchableOpacity>
            </ScrollView>
          </View>
        )}
      </Modal>

      {/* 追加・編集モーダル */}
      <Modal
        visible={modalMode === 'add' || modalMode === 'edit'}
        animationType="slide"
        presentationStyle="pageSheet"
      >
        <View style={[styles.modalContainer, { paddingTop: insets.top }]}>
          <View style={styles.modalHeader}>
            <TouchableOpacity onPress={() => setModalMode('none')}>
              <Text style={styles.cancelText}>キャンセル</Text>
            </TouchableOpacity>
            <Text style={styles.modalTitle}>
              {modalMode === 'add' ? '住民追加' : '住民編集'}
            </Text>
            <TouchableOpacity onPress={handleSave}>
              <Text style={styles.saveText}>保存</Text>
            </TouchableOpacity>
          </View>

          <ScrollView style={styles.formContent}>
            {[
              { label: '氏名 *', key: 'name', placeholder: '山田 太郎', keyboardType: 'default' },
              { label: 'ふりがな', key: 'kana', placeholder: 'やまだ たろう', keyboardType: 'default' },
              { label: '住所 *', key: 'address', placeholder: '○○町1-1-1', keyboardType: 'default' },
              { label: '電話番号 *', key: 'phone', placeholder: '090-0000-0000', keyboardType: 'phone-pad' },
              { label: 'メールアドレス', key: 'email', placeholder: 'example@example.com', keyboardType: 'email-address' },
              { label: '班番号', key: 'householdNumber', placeholder: '1', keyboardType: 'number-pad' },
              { label: '備考', key: 'note', placeholder: 'メモ', keyboardType: 'default' },
            ].map((field) => (
              <View key={field.key} style={styles.formField}>
                <Text style={styles.formLabel}>{field.label}</Text>
                <TextInput
                  style={styles.formInput}
                  value={
                    field.key === 'householdNumber'
                      ? String(form.householdNumber || '')
                      : String((form as any)[field.key] || '')
                  }
                  onChangeText={(text) =>
                    setForm((prev) => ({
                      ...prev,
                      [field.key]: field.key === 'householdNumber' ? parseInt(text) || 0 : text,
                    }))
                  }
                  placeholder={field.placeholder}
                  placeholderTextColor={Colors.textLight}
                  keyboardType={field.keyboardType as any}
                  autoCapitalize="none"
                />
              </View>
            ))}
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
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerTitle: { fontSize: FontSize.xl, fontWeight: '700', color: Colors.surface },
  headerCount: { fontSize: FontSize.sm, color: Colors.surface + 'CC' },
  searchContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: Colors.surface,
    margin: Spacing.md,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    borderRadius: BorderRadius.md,
    gap: Spacing.sm,
    ...Shadow.sm,
  },
  searchInput: { flex: 1, fontSize: FontSize.md, color: Colors.text },
  residentCard: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: Spacing.sm,
    gap: Spacing.sm,
  },
  residentNumber: {
    width: 36,
    height: 36,
    borderRadius: 18,
    backgroundColor: Colors.primary + '15',
    justifyContent: 'center',
    alignItems: 'center',
  },
  numberText: { fontSize: FontSize.sm, fontWeight: '700', color: Colors.primary },
  residentInfo: { flex: 1 },
  residentName: { fontSize: FontSize.md, fontWeight: '600', color: Colors.text },
  residentKana: { fontSize: FontSize.xs, color: Colors.textSecondary, marginTop: 1 },
  residentAddress: { fontSize: FontSize.xs, color: Colors.textSecondary, marginTop: 2 },
  phoneButton: {
    padding: Spacing.sm,
    backgroundColor: Colors.primary + '15',
    borderRadius: BorderRadius.round,
  },
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
  modalTitle: { fontSize: FontSize.lg, fontWeight: '700', color: Colors.text },
  editText: { fontSize: FontSize.md, color: Colors.primary, fontWeight: '600' },
  cancelText: { fontSize: FontSize.md, color: Colors.textSecondary },
  saveText: { fontSize: FontSize.md, color: Colors.primary, fontWeight: '700' },
  detailContent: { flex: 1 },
  detailAvatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: Colors.primary,
    justifyContent: 'center',
    alignItems: 'center',
    alignSelf: 'center',
    marginTop: Spacing.xl,
  },
  avatarText: { fontSize: FontSize.xxxl, color: Colors.surface, fontWeight: '700' },
  detailName: {
    textAlign: 'center',
    fontSize: FontSize.xxl,
    fontWeight: '700',
    color: Colors.text,
    marginTop: Spacing.md,
  },
  detailKana: {
    textAlign: 'center',
    fontSize: FontSize.sm,
    color: Colors.textSecondary,
    marginBottom: Spacing.lg,
  },
  detailCard: { margin: Spacing.md },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.sm,
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.divider,
  },
  detailRowContent: { flex: 1 },
  detailLabel: { fontSize: FontSize.xs, color: Colors.textSecondary, marginBottom: 2 },
  detailValue: { fontSize: FontSize.md, color: Colors.text },
  actionButtons: {
    flexDirection: 'row',
    gap: Spacing.sm,
    paddingHorizontal: Spacing.md,
    marginBottom: Spacing.lg,
  },
  actionBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: Spacing.sm,
    paddingVertical: Spacing.md,
    borderRadius: BorderRadius.md,
  },
  actionBtnText: { fontSize: FontSize.md, fontWeight: '600', color: Colors.surface },
  deleteButton: {
    marginHorizontal: Spacing.md,
    marginBottom: Spacing.xl,
    padding: Spacing.md,
    alignItems: 'center',
  },
  deleteText: { fontSize: FontSize.md, color: Colors.error, fontWeight: '600' },
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
});
