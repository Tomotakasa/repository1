import { EventCategory } from '../types';
import { Colors } from './theme';

export function formatDate(dateString: string, format: 'short' | 'long' | 'time' | 'monthDay' = 'short'): string {
  const date = new Date(dateString);
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  const day = date.getDate();
  const hours = date.getHours().toString().padStart(2, '0');
  const minutes = date.getMinutes().toString().padStart(2, '0');
  const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
  const weekday = weekdays[date.getDay()];

  switch (format) {
    case 'long':
      return `${year}年${month}月${day}日（${weekday}）`;
    case 'time':
      return `${year}年${month}月${day}日 ${hours}:${minutes}`;
    case 'monthDay':
      return `${month}月${day}日（${weekday}）`;
    default:
      return `${year}/${month.toString().padStart(2, '0')}/${day.toString().padStart(2, '0')}`;
  }
}

export function formatRelativeTime(dateString: string): string {
  const now = new Date();
  const date = new Date(dateString);
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMins / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffMins < 1) return 'たった今';
  if (diffMins < 60) return `${diffMins}分前`;
  if (diffHours < 24) return `${diffHours}時間前`;
  if (diffDays < 7) return `${diffDays}日前`;
  return formatDate(dateString);
}

export function formatCurrency(amount: number): string {
  return `¥${amount.toLocaleString('ja-JP')}`;
}

export function getEventCategoryLabel(category: EventCategory): string {
  const labels: Record<EventCategory, string> = {
    meeting: '会議',
    cleanup: '清掃',
    festival: '行事',
    emergency: '防災',
    other: 'その他',
  };
  return labels[category];
}

export function getEventCategoryColor(category: EventCategory): string {
  const colorMap: Record<EventCategory, string> = {
    meeting: Colors.meeting,
    cleanup: Colors.cleanup,
    festival: Colors.festival,
    emergency: Colors.emergency,
    other: Colors.other,
  };
  return colorMap[category];
}

export function generateId(): string {
  return Date.now().toString(36) + Math.random().toString(36).substring(2);
}

export function getNoticeCategoryLabel(category: 'info' | 'urgent' | 'reminder'): string {
  const labels = { info: 'お知らせ', urgent: '重要', reminder: 'リマインダー' };
  return labels[category];
}

export function getNoticeCategoryColor(category: 'info' | 'urgent' | 'reminder'): string {
  const colors = {
    info: Colors.info,
    urgent: Colors.error,
    reminder: Colors.warning,
  };
  return colors[category];
}

export function isOverdue(dateString: string): boolean {
  return new Date(dateString) < new Date();
}

export function daysUntil(dateString: string): number {
  const now = new Date();
  now.setHours(0, 0, 0, 0);
  const target = new Date(dateString);
  target.setHours(0, 0, 0, 0);
  return Math.ceil((target.getTime() - now.getTime()) / 86400000);
}

export function isSameDay(date1: string, date2: string): boolean {
  const d1 = new Date(date1);
  const d2 = new Date(date2);
  return (
    d1.getFullYear() === d2.getFullYear() &&
    d1.getMonth() === d2.getMonth() &&
    d1.getDate() === d2.getDate()
  );
}
