import React, { createContext, useContext, useEffect, useReducer } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  AppSettings,
  Circular,
  Event,
  FeeCollection,
  Notice,
  Resident,
} from '../types';
import { SAMPLE_RESIDENTS, SAMPLE_EVENTS, SAMPLE_CIRCULARS, SAMPLE_FEES, SAMPLE_NOTICES } from '../utils/sampleData';

// ストレージキー
const STORAGE_KEYS = {
  RESIDENTS: '@chonaikai:residents',
  CIRCULARS: '@chonaikai:circulars',
  FEES: '@chonaikai:fees',
  EVENTS: '@chonaikai:events',
  NOTICES: '@chonaikai:notices',
  SETTINGS: '@chonaikai:settings',
};

// 状態の型
interface AppState {
  residents: Resident[];
  circulars: Circular[];
  fees: FeeCollection[];
  events: Event[];
  notices: Notice[];
  settings: AppSettings;
  isLoading: boolean;
}

// アクションの型
type AppAction =
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'LOAD_DATA'; payload: Partial<AppState> }
  | { type: 'ADD_RESIDENT'; payload: Resident }
  | { type: 'UPDATE_RESIDENT'; payload: Resident }
  | { type: 'DELETE_RESIDENT'; payload: string }
  | { type: 'ADD_CIRCULAR'; payload: Circular }
  | { type: 'UPDATE_CIRCULAR'; payload: Circular }
  | { type: 'DELETE_CIRCULAR'; payload: string }
  | { type: 'ADD_FEE'; payload: FeeCollection }
  | { type: 'UPDATE_FEE'; payload: FeeCollection }
  | { type: 'DELETE_FEE'; payload: string }
  | { type: 'ADD_EVENT'; payload: Event }
  | { type: 'UPDATE_EVENT'; payload: Event }
  | { type: 'DELETE_EVENT'; payload: string }
  | { type: 'ADD_NOTICE'; payload: Notice }
  | { type: 'MARK_NOTICE_READ'; payload: string }
  | { type: 'UPDATE_SETTINGS'; payload: AppSettings };

const defaultSettings: AppSettings = {
  organizationName: '○○町内会',
  blockName: '1班',
  leaderName: '',
  fiscalYearStart: 4,
  annualFee: 3000,
};

const initialState: AppState = {
  residents: [],
  circulars: [],
  fees: [],
  events: [],
  notices: [],
  settings: defaultSettings,
  isLoading: true,
};

function reducer(state: AppState, action: AppAction): AppState {
  switch (action.type) {
    case 'SET_LOADING':
      return { ...state, isLoading: action.payload };
    case 'LOAD_DATA':
      return { ...state, ...action.payload, isLoading: false };
    case 'ADD_RESIDENT':
      return { ...state, residents: [...state.residents, action.payload] };
    case 'UPDATE_RESIDENT':
      return {
        ...state,
        residents: state.residents.map((r) =>
          r.id === action.payload.id ? action.payload : r
        ),
      };
    case 'DELETE_RESIDENT':
      return {
        ...state,
        residents: state.residents.filter((r) => r.id !== action.payload),
      };
    case 'ADD_CIRCULAR':
      return { ...state, circulars: [...state.circulars, action.payload] };
    case 'UPDATE_CIRCULAR':
      return {
        ...state,
        circulars: state.circulars.map((c) =>
          c.id === action.payload.id ? action.payload : c
        ),
      };
    case 'DELETE_CIRCULAR':
      return {
        ...state,
        circulars: state.circulars.filter((c) => c.id !== action.payload),
      };
    case 'ADD_FEE':
      return { ...state, fees: [...state.fees, action.payload] };
    case 'UPDATE_FEE':
      return {
        ...state,
        fees: state.fees.map((f) =>
          f.id === action.payload.id ? action.payload : f
        ),
      };
    case 'DELETE_FEE':
      return {
        ...state,
        fees: state.fees.filter((f) => f.id !== action.payload),
      };
    case 'ADD_EVENT':
      return { ...state, events: [...state.events, action.payload] };
    case 'UPDATE_EVENT':
      return {
        ...state,
        events: state.events.map((e) =>
          e.id === action.payload.id ? action.payload : e
        ),
      };
    case 'DELETE_EVENT':
      return {
        ...state,
        events: state.events.filter((e) => e.id !== action.payload),
      };
    case 'ADD_NOTICE':
      return { ...state, notices: [action.payload, ...state.notices] };
    case 'MARK_NOTICE_READ':
      return {
        ...state,
        notices: state.notices.map((n) =>
          n.id === action.payload ? { ...n, isRead: true } : n
        ),
      };
    case 'UPDATE_SETTINGS':
      return { ...state, settings: action.payload };
    default:
      return state;
  }
}

// コンテキスト
interface AppContextType {
  state: AppState;
  dispatch: React.Dispatch<AppAction>;
  saveResidents: (residents: Resident[]) => Promise<void>;
  saveCirculars: (circulars: Circular[]) => Promise<void>;
  saveFees: (fees: FeeCollection[]) => Promise<void>;
  saveEvents: (events: Event[]) => Promise<void>;
  saveNotices: (notices: Notice[]) => Promise<void>;
  saveSettings: (settings: AppSettings) => Promise<void>;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export function AppProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(reducer, initialState);

  useEffect(() => {
    loadAllData();
  }, []);

  const loadAllData = async () => {
    try {
      const [
        residentsJson,
        circularsJson,
        feesJson,
        eventsJson,
        noticesJson,
        settingsJson,
      ] = await Promise.all([
        AsyncStorage.getItem(STORAGE_KEYS.RESIDENTS),
        AsyncStorage.getItem(STORAGE_KEYS.CIRCULARS),
        AsyncStorage.getItem(STORAGE_KEYS.FEES),
        AsyncStorage.getItem(STORAGE_KEYS.EVENTS),
        AsyncStorage.getItem(STORAGE_KEYS.NOTICES),
        AsyncStorage.getItem(STORAGE_KEYS.SETTINGS),
      ]);

      dispatch({
        type: 'LOAD_DATA',
        payload: {
          residents: residentsJson ? JSON.parse(residentsJson) : SAMPLE_RESIDENTS,
          circulars: circularsJson ? JSON.parse(circularsJson) : SAMPLE_CIRCULARS,
          fees: feesJson ? JSON.parse(feesJson) : SAMPLE_FEES,
          events: eventsJson ? JSON.parse(eventsJson) : SAMPLE_EVENTS,
          notices: noticesJson ? JSON.parse(noticesJson) : SAMPLE_NOTICES,
          settings: settingsJson
            ? JSON.parse(settingsJson)
            : defaultSettings,
        },
      });
    } catch (error) {
      console.error('データの読み込みに失敗しました:', error);
      dispatch({ type: 'SET_LOADING', payload: false });
    }
  };

  const saveResidents = async (residents: Resident[]) => {
    await AsyncStorage.setItem(STORAGE_KEYS.RESIDENTS, JSON.stringify(residents));
  };

  const saveCirculars = async (circulars: Circular[]) => {
    await AsyncStorage.setItem(STORAGE_KEYS.CIRCULARS, JSON.stringify(circulars));
  };

  const saveFees = async (fees: FeeCollection[]) => {
    await AsyncStorage.setItem(STORAGE_KEYS.FEES, JSON.stringify(fees));
  };

  const saveEvents = async (events: Event[]) => {
    await AsyncStorage.setItem(STORAGE_KEYS.EVENTS, JSON.stringify(events));
  };

  const saveNotices = async (notices: Notice[]) => {
    await AsyncStorage.setItem(STORAGE_KEYS.NOTICES, JSON.stringify(notices));
  };

  const saveSettings = async (settings: AppSettings) => {
    await AsyncStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(settings));
  };

  return (
    <AppContext.Provider
      value={{
        state,
        dispatch,
        saveResidents,
        saveCirculars,
        saveFees,
        saveEvents,
        saveNotices,
        saveSettings,
      }}
    >
      {children}
    </AppContext.Provider>
  );
}

export function useApp() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within AppProvider');
  }
  return context;
}
