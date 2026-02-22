export type ExamType = 'denryoku' | 'kikai';
export type Difficulty = 'basic' | 'standard' | 'advanced';
export type StudyMode = 'learn' | 'quiz' | 'review';

export interface Formula {
  name: string;
  latex: string;
  description: string;
  unit?: string;
}

export interface SubQuestion {
  id: string;
  question: string;
  hint?: string;
  answer: string;
  explanation: string;
  keyPoints?: string[];
}

export interface DiagramSpec {
  type: 'circuit' | 'graph' | 'phasor' | 'block' | 'custom';
  componentId: string;
  caption?: string;
}

export interface Question {
  id: string;
  year: number;
  examType: ExamType;
  category: string;
  title: string;
  problemNumber: number;
  difficulty: Difficulty;
  tags: string[];
  description: string;
  subQuestions: SubQuestion[];
  keyFormulas: Formula[];
  diagram?: DiagramSpec;
  commonMistakes?: string[];
  relatedTopics?: string[];
}

export interface Topic {
  id: string;
  examType: ExamType;
  name: string;
  description: string;
  keyFormulas: Formula[];
  summary: string;
  tips: string[];
}

export interface UserProgress {
  questionId: string;
  correct: boolean;
  attemptedAt: string;
  timeSpent: number;
}

export interface StudySession {
  id: string;
  startedAt: string;
  endedAt?: string;
  examType: ExamType;
  questionsAttempted: string[];
  correctCount: number;
}

export interface AppState {
  progress: Record<string, UserProgress[]>;
  bookmarks: string[];
  studySessions: StudySession[];
  settings: {
    darkMode: boolean;
    showHints: boolean;
    fontSize: 'small' | 'medium' | 'large';
  };
}
