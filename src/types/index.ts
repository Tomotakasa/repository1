// 住民
export interface Resident {
  id: string;
  name: string;
  kana: string;
  address: string;
  phone: string;
  email?: string;
  note?: string;
  householdNumber: number;
  createdAt: string;
  updatedAt: string;
}

// 回覧板
export interface Circular {
  id: string;
  title: string;
  content: string;
  createdAt: string;
  dueDate: string;
  status: 'active' | 'completed';
  residents: CircularStatus[];
}

export interface CircularStatus {
  residentId: string;
  residentName: string;
  passed: boolean;
  passedAt?: string;
}

// 集金
export interface FeeCollection {
  id: string;
  title: string;
  amount: number;
  dueDate: string;
  year: number;
  month: number;
  status: 'open' | 'closed';
  payments: Payment[];
  createdAt: string;
}

export interface Payment {
  residentId: string;
  residentName: string;
  paid: boolean;
  paidAt?: string;
  amount?: number;
  note?: string;
}

// 行事・イベント
export interface Event {
  id: string;
  title: string;
  description?: string;
  startDate: string;
  endDate?: string;
  location?: string;
  category: EventCategory;
  isAllDay: boolean;
  createdAt: string;
}

export type EventCategory =
  | 'meeting'
  | 'cleanup'
  | 'festival'
  | 'emergency'
  | 'other';

// お知らせ
export interface Notice {
  id: string;
  title: string;
  content: string;
  category: 'info' | 'urgent' | 'reminder';
  createdAt: string;
  isRead: boolean;
}

// 設定
export interface AppSettings {
  organizationName: string;
  blockName: string;
  leaderName: string;
  fiscalYearStart: number;
  annualFee: number;
}

// ナビゲーション
export type RootTabParamList = {
  Home: undefined;
  Residents: undefined;
  Circular: undefined;
  Fees: undefined;
  Events: undefined;
};

export type HomeStackParamList = {
  HomeMain: undefined;
  NoticeDetail: { notice: Notice };
};

export type ResidentStackParamList = {
  ResidentList: undefined;
  ResidentDetail: { resident: Resident };
  ResidentForm: { resident?: Resident };
};

export type CircularStackParamList = {
  CircularList: undefined;
  CircularDetail: { circular: Circular };
  CircularForm: { circular?: Circular };
};

export type FeeStackParamList = {
  FeeList: undefined;
  FeeDetail: { fee: FeeCollection };
  FeeForm: { fee?: FeeCollection };
};

export type EventStackParamList = {
  EventCalendar: undefined;
  EventDetail: { event: Event };
  EventForm: { event?: Event; date?: string };
};
