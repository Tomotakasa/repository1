import { Ionicons } from '@expo/vector-icons';
import React, { useState } from 'react';
import {
  Alert,
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
import { AppSettings } from '../types';
import { BorderRadius, Colors, FontSize, Spacing } from '../utils/theme';

export default function SettingsScreen({ navigation }: any) {
  const { state, dispatch, saveSettings } = useApp();
  const insets = useSafeAreaInsets();
  const [isEditing, setIsEditing] = useState(false);
  const [form, setForm] = useState<AppSettings>({ ...state.settings });

  const handleSave = async () => {
    if (!form.organizationName.trim()) {
      Alert.alert('エラー', '町内会名を入力してください');
      return;
    }
    dispatch({ type: 'UPDATE_SETTINGS', payload: form });
    await saveSettings(form);
    setIsEditing(false);
    Alert.alert('保存完了', '設定を保存しました');
  };

  const handleCancel = () => {
    setForm({ ...state.settings });
    setIsEditing(false);
  };

  const stats = [
    { label: '登録住民', value: `${state.residents.length}世帯`, icon: 'people' },
    {
      label: '回覧中',
      value: `${state.circulars.filter((c) => c.status === 'active').length}件`,
      icon: 'document-text',
    },
    {
      label: '集金管理',
      value: `${state.fees.filter((f) => f.status === 'open').length}件`,
      icon: 'cash',
    },
    { label: '行事予定', value: `${state.events.length}件`, icon: 'calendar' },
  ];

  return (
    <ScrollView
      style={styles.container}
      contentContainerStyle={{ paddingBottom: insets.bottom + Spacing.xl }}
    >
      {/* ヘッダー */}
      <View style={[styles.header, { paddingTop: insets.top + Spacing.md }]}>
        <TouchableOpacity onPress={() => navigation.goBack()}>
          <Ionicons name="arrow-back" size={24} color={Colors.surface} />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>設定</Text>
        <TouchableOpacity onPress={isEditing ? handleSave : () => setIsEditing(true)}>
          <Text style={styles.headerAction}>
            {isEditing ? '保存' : '編集'}
          </Text>
        </TouchableOpacity>
      </View>

      <View style={styles.content}>
        {/* 統計 */}
        <View style={styles.statsGrid}>
          {stats.map((stat) => (
            <View key={stat.label} style={styles.statCard}>
              <Ionicons name={stat.icon as any} size={22} color={Colors.primary} />
              <Text style={styles.statValue}>{stat.value}</Text>
              <Text style={styles.statLabel}>{stat.label}</Text>
            </View>
          ))}
        </View>

        {/* 基本設定 */}
        <Text style={styles.sectionTitle}>基本設定</Text>
        <Card style={styles.settingsCard}>
          {isEditing ? (
            <>
              {[
                { label: '町内会名', key: 'organizationName', placeholder: '○○町内会' },
                { label: '班名', key: 'blockName', placeholder: '1班' },
                { label: '班長名', key: 'leaderName', placeholder: '山田 太郎' },
                { label: '年会費（円）', key: 'annualFee', placeholder: '3000', numeric: true },
              ].map((field) => (
                <View key={field.key} style={styles.editRow}>
                  <Text style={styles.editLabel}>{field.label}</Text>
                  <TextInput
                    style={styles.editInput}
                    value={
                      field.numeric
                        ? String((form as any)[field.key])
                        : (form as any)[field.key]
                    }
                    onChangeText={(t) =>
                      setForm((p) => ({
                        ...p,
                        [field.key]: field.numeric ? parseInt(t) || 0 : t,
                      }))
                    }
                    placeholder={field.placeholder}
                    placeholderTextColor={Colors.textLight}
                    keyboardType={field.numeric ? 'number-pad' : 'default'}
                  />
                </View>
              ))}
              <TouchableOpacity style={styles.cancelRow} onPress={handleCancel}>
                <Text style={styles.cancelText}>キャンセル</Text>
              </TouchableOpacity>
            </>
          ) : (
            <>
              {[
                { label: '町内会名', value: state.settings.organizationName },
                { label: '班名', value: state.settings.blockName },
                { label: '班長名', value: state.settings.leaderName || '未設定' },
                { label: '年会費', value: `¥${state.settings.annualFee.toLocaleString()}` },
              ].map((item) => (
                <View key={item.label} style={styles.settingRow}>
                  <Text style={styles.settingLabel}>{item.label}</Text>
                  <Text style={styles.settingValue}>{item.value}</Text>
                </View>
              ))}
            </>
          )}
        </Card>

        {/* アプリ情報 */}
        <Text style={styles.sectionTitle}>アプリ情報</Text>
        <Card style={styles.settingsCard}>
          {[
            { label: 'アプリ名', value: '町内会班長アプリ' },
            { label: 'バージョン', value: '1.0.0' },
            { label: '対応機能', value: '住民管理・回覧板・集金管理・行事予定' },
          ].map((item) => (
            <View key={item.label} style={styles.settingRow}>
              <Text style={styles.settingLabel}>{item.label}</Text>
              <Text style={styles.settingValue}>{item.value}</Text>
            </View>
          ))}
        </Card>

        {/* 使い方ガイド */}
        <Text style={styles.sectionTitle}>使い方ガイド</Text>
        <Card style={styles.guideCard}>
          {[
            {
              icon: 'people',
              color: Colors.primary,
              title: '住民名簿',
              desc: '世帯主・連絡先を管理。タップで電話・メール可能。',
            },
            {
              icon: 'document-text',
              color: Colors.secondary,
              title: '回覧板',
              desc: '回覧板を作成し、各世帯の確認状況をリアルタイム管理。',
            },
            {
              icon: 'cash',
              color: Colors.warning,
              title: '集金管理',
              desc: '町内会費などの集金状況を管理。未収金を一目で確認。',
            },
            {
              icon: 'calendar',
              color: Colors.info,
              title: '行事予定',
              desc: '清掃・会議・祭りなどの行事をカテゴリ別に管理。',
            },
          ].map((item) => (
            <View key={item.title} style={styles.guideItem}>
              <View style={[styles.guideIcon, { backgroundColor: item.color + '15' }]}>
                <Ionicons name={item.icon as any} size={20} color={item.color} />
              </View>
              <View style={styles.guideContent}>
                <Text style={styles.guideTitle}>{item.title}</Text>
                <Text style={styles.guideDesc}>{item.desc}</Text>
              </View>
            </View>
          ))}
        </Card>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: Colors.background },
  header: {
    backgroundColor: Colors.primary,
    paddingHorizontal: Spacing.md,
    paddingBottom: Spacing.lg,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerTitle: { fontSize: FontSize.xl, fontWeight: '700', color: Colors.surface },
  headerAction: { fontSize: FontSize.md, color: Colors.surface, fontWeight: '600' },
  content: { padding: Spacing.md },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: Spacing.sm,
    marginBottom: Spacing.lg,
  },
  statCard: {
    width: '47%',
    backgroundColor: Colors.surface,
    borderRadius: BorderRadius.md,
    padding: Spacing.md,
    alignItems: 'center',
    gap: Spacing.xs,
  },
  statValue: { fontSize: FontSize.xl, fontWeight: '700', color: Colors.text },
  statLabel: { fontSize: FontSize.xs, color: Colors.textSecondary },
  sectionTitle: {
    fontSize: FontSize.sm,
    fontWeight: '700',
    color: Colors.textSecondary,
    marginBottom: Spacing.sm,
    marginTop: Spacing.md,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  settingsCard: { marginBottom: Spacing.sm },
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.divider,
  },
  settingLabel: { fontSize: FontSize.md, color: Colors.textSecondary },
  settingValue: { fontSize: FontSize.md, color: Colors.text, fontWeight: '500' },
  editRow: { marginBottom: Spacing.sm },
  editLabel: { fontSize: FontSize.sm, color: Colors.textSecondary, marginBottom: Spacing.xs },
  editInput: {
    backgroundColor: Colors.background,
    borderRadius: BorderRadius.sm,
    paddingHorizontal: Spacing.md,
    paddingVertical: Spacing.sm,
    fontSize: FontSize.md,
    color: Colors.text,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  cancelRow: { alignItems: 'center', paddingTop: Spacing.sm },
  cancelText: { fontSize: FontSize.md, color: Colors.textSecondary },
  guideCard: {},
  guideItem: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: Spacing.md,
    paddingVertical: Spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: Colors.divider,
  },
  guideIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    justifyContent: 'center',
    alignItems: 'center',
    flexShrink: 0,
  },
  guideContent: { flex: 1 },
  guideTitle: { fontSize: FontSize.md, fontWeight: '600', color: Colors.text, marginBottom: 2 },
  guideDesc: { fontSize: FontSize.sm, color: Colors.textSecondary, lineHeight: 18 },
});
