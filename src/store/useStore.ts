import { useState, useEffect, useCallback } from 'react';
import type { AppState, UserProgress, StudySession, ExamType } from '../types';

const STORAGE_KEY = 'denkishunin_state';

const defaultState: AppState = {
  progress: {},
  bookmarks: [],
  studySessions: [],
  settings: {
    darkMode: true,
    showHints: true,
    fontSize: 'medium',
  },
};

function loadState(): AppState {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return defaultState;
    return { ...defaultState, ...JSON.parse(raw) };
  } catch {
    return defaultState;
  }
}

function saveState(state: AppState) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // storage full
  }
}

export function useAppStore() {
  const [state, setState] = useState<AppState>(loadState);

  useEffect(() => {
    saveState(state);
  }, [state]);

  const recordAnswer = useCallback((questionId: string, correct: boolean, timeSpent: number) => {
    setState(prev => {
      const existing = prev.progress[questionId] ?? [];
      const entry: UserProgress = {
        questionId,
        correct,
        attemptedAt: new Date().toISOString(),
        timeSpent,
      };
      return {
        ...prev,
        progress: {
          ...prev.progress,
          [questionId]: [...existing, entry],
        },
      };
    });
  }, []);

  const toggleBookmark = useCallback((questionId: string) => {
    setState(prev => {
      const has = prev.bookmarks.includes(questionId);
      return {
        ...prev,
        bookmarks: has
          ? prev.bookmarks.filter(id => id !== questionId)
          : [...prev.bookmarks, questionId],
      };
    });
  }, []);

  const startSession = useCallback((examType: ExamType): string => {
    const id = `session_${Date.now()}`;
    const session: StudySession = {
      id,
      startedAt: new Date().toISOString(),
      examType,
      questionsAttempted: [],
      correctCount: 0,
    };
    setState(prev => ({
      ...prev,
      studySessions: [...prev.studySessions, session],
    }));
    return id;
  }, []);

  const updateSettings = useCallback((updates: Partial<AppState['settings']>) => {
    setState(prev => ({
      ...prev,
      settings: { ...prev.settings, ...updates },
    }));
  }, []);

  const getQuestionStats = useCallback((questionId: string) => {
    const attempts = state.progress[questionId] ?? [];
    if (attempts.length === 0) return null;
    const correct = attempts.filter(a => a.correct).length;
    return {
      total: attempts.length,
      correct,
      rate: Math.round((correct / attempts.length) * 100),
      lastAttempted: attempts[attempts.length - 1].attemptedAt,
    };
  }, [state.progress]);

  const getWeakTopics = useCallback(() => {
    const topicStats: Record<string, { correct: number; total: number }> = {};
    Object.entries(state.progress).forEach(([qId, attempts]) => {
      const tag = qId.split('_')[0];
      if (!topicStats[tag]) topicStats[tag] = { correct: 0, total: 0 };
      topicStats[tag].total += attempts.length;
      topicStats[tag].correct += attempts.filter(a => a.correct).length;
    });
    return Object.entries(topicStats)
      .map(([tag, s]) => ({ tag, rate: Math.round((s.correct / s.total) * 100), total: s.total }))
      .filter(t => t.total >= 2)
      .sort((a, b) => a.rate - b.rate);
  }, [state.progress]);

  const resetProgress = useCallback(() => {
    setState(prev => ({ ...prev, progress: {}, studySessions: [] }));
  }, []);

  return {
    state,
    recordAnswer,
    toggleBookmark,
    startSession,
    updateSettings,
    getQuestionStats,
    getWeakTopics,
    resetProgress,
  };
}

export type AppStore = ReturnType<typeof useAppStore>;
