import { Circular, Event, FeeCollection, Notice, Resident } from '../types';

export const SAMPLE_RESIDENTS: Resident[] = [
  {
    id: '1',
    name: '田中 太郎',
    kana: 'タナカ タロウ',
    address: '○○町1-1-1',
    phone: '090-1234-5678',
    email: 'tanaka@example.com',
    householdNumber: 1,
    note: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '2',
    name: '鈴木 花子',
    kana: 'スズキ ハナコ',
    address: '○○町1-1-2',
    phone: '090-2345-6789',
    householdNumber: 2,
    note: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '3',
    name: '佐藤 次郎',
    kana: 'サトウ ジロウ',
    address: '○○町1-1-3',
    phone: '090-3456-7890',
    householdNumber: 3,
    note: '高齢者世帯',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '4',
    name: '山田 美咲',
    kana: 'ヤマダ ミサキ',
    address: '○○町1-1-4',
    phone: '090-4567-8901',
    householdNumber: 4,
    note: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '5',
    name: '伊藤 健一',
    kana: 'イトウ ケンイチ',
    address: '○○町1-1-5',
    phone: '090-5678-9012',
    householdNumber: 5,
    note: '',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
];

const today = new Date();
const nextWeek = new Date(today);
nextWeek.setDate(today.getDate() + 7);

export const SAMPLE_CIRCULARS: Circular[] = [
  {
    id: '1',
    title: '○月定例会のお知らせ',
    content: '今月の定例会を下記の通り開催いたします。\n\n日時：○月○日（○）午後7時\n場所：集会所\n\n出席できない方はご連絡ください。',
    createdAt: new Date().toISOString(),
    dueDate: nextWeek.toISOString(),
    status: 'active',
    residents: SAMPLE_RESIDENTS.map((r, index) => ({
      residentId: r.id,
      residentName: r.name,
      passed: index < 2,
      passedAt: index < 2 ? new Date().toISOString() : undefined,
    })),
  },
];

export const SAMPLE_FEES: FeeCollection[] = [
  {
    id: '1',
    title: '令和6年度 町内会費',
    amount: 3000,
    dueDate: new Date(today.getFullYear(), today.getMonth() + 1, 0).toISOString(),
    year: today.getFullYear(),
    month: today.getMonth() + 1,
    status: 'open',
    createdAt: new Date().toISOString(),
    payments: SAMPLE_RESIDENTS.map((r, index) => ({
      residentId: r.id,
      residentName: r.name,
      paid: index < 3,
      paidAt: index < 3 ? new Date().toISOString() : undefined,
      amount: 3000,
    })),
  },
];

const eventDates = [0, 5, 12, 20, 30].map((offset) => {
  const d = new Date(today);
  d.setDate(today.getDate() + offset);
  return d;
});

export const SAMPLE_EVENTS: Event[] = [
  {
    id: '1',
    title: '班長定例会議',
    description: '今月の班長会議です。出席をお願いします。',
    startDate: eventDates[1].toISOString(),
    location: '集会所',
    category: 'meeting',
    isAllDay: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: '2',
    title: '地区清掃活動',
    description: '地区内の清掃を行います。ゴミ袋・軍手持参。',
    startDate: eventDates[2].toISOString(),
    location: '○○公園周辺',
    category: 'cleanup',
    isAllDay: true,
    createdAt: new Date().toISOString(),
  },
  {
    id: '3',
    title: '夏祭り準備委員会',
    description: '夏祭りの準備委員会を開催します。',
    startDate: eventDates[3].toISOString(),
    location: '公民館',
    category: 'festival',
    isAllDay: false,
    createdAt: new Date().toISOString(),
  },
  {
    id: '4',
    title: '防災訓練',
    description: '年次防災訓練。全住民参加をお願いします。',
    startDate: eventDates[4].toISOString(),
    location: '○○小学校',
    category: 'emergency',
    isAllDay: true,
    createdAt: new Date().toISOString(),
  },
];

export const SAMPLE_NOTICES: Notice[] = [
  {
    id: '1',
    title: '回覧板が届いています',
    content: '「○月定例会のお知らせ」の回覧板があなたのところで止まっています。次の方へお渡しください。',
    category: 'urgent',
    createdAt: new Date().toISOString(),
    isRead: false,
  },
  {
    id: '2',
    title: '集金のお願い',
    content: '令和6年度の町内会費の徴収期限が近づいています。未納の方はお早めにご連絡ください。',
    category: 'reminder',
    createdAt: new Date(today.getTime() - 86400000).toISOString(),
    isRead: false,
  },
  {
    id: '3',
    title: 'アプリへようこそ',
    content: '町内会班長アプリをご利用いただきありがとうございます。住民管理、回覧板、集金管理などの機能をご活用ください。',
    category: 'info',
    createdAt: new Date(today.getTime() - 86400000 * 3).toISOString(),
    isRead: true,
  },
];
