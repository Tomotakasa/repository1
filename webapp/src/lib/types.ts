export type MessageRole = 'user' | 'assistant'

export interface ChatMessage {
  id: string
  role: MessageRole
  content: string
  timestamp: Date
  isStreaming?: boolean
}

export type LLMBackend = 'claude' | 'ollama' | 'openai-compatible' | 'groq'

export interface Settings {
  llmBackend: LLMBackend
  claudeModel: string       // APIキーはサーバー側環境変数で管理
  ollamaEndpoint: string
  ollamaModel: string
  customEndpoint: string
  customApiKey: string
  customModel: string
  groqApiKey: string
  groqModel: string
}

export const DEFAULT_SETTINGS: Settings = {
  llmBackend: 'claude',
  claudeModel: 'claude-sonnet-4-6',
  ollamaEndpoint: 'http://localhost:11434',
  ollamaModel: 'phi3:mini',
  customEndpoint: '',
  customApiKey: '',
  customModel: '',
  groqApiKey: '',
  groqModel: 'llama-3.1-8b-instant'
}

export const CLAUDE_MODELS = [
  { id: 'claude-opus-4-6', label: 'Claude Opus 4.6（最高品質）' },
  { id: 'claude-sonnet-4-6', label: 'Claude Sonnet 4.6（推奨）' },
  { id: 'claude-haiku-4-5-20251001', label: 'Claude Haiku 4.5（高速）' }
]

export const OLLAMA_MODELS = [
  { id: 'phi3:mini', label: 'phi3:mini（約2.2GB）- Microsoft製、日本語◎' },
  { id: 'gemma2:2b', label: 'gemma2:2b（約1.6GB）- Google製、バランス型' },
  { id: 'llama3.2:3b', label: 'llama3.2:3b（約2.0GB）- Meta製' },
  { id: 'llama3.1:8b', label: 'llama3.1:8b（約4.7GB）- 高品質' },
  { id: 'qwen2.5:0.5b', label: 'qwen2.5:0.5b（約0.4GB）- 超軽量' }
]

export const GROQ_MODELS = [
  { id: 'llama-3.1-8b-instant', label: 'Llama 3.1 8B Instant（推奨・最速）' },
  { id: 'llama-3.3-70b-versatile', label: 'Llama 3.3 70B（高品質）' },
  { id: 'mixtral-8x7b-32768', label: 'Mixtral 8x7B（バランス型）' },
  { id: 'gemma2-9b-it', label: 'Gemma2 9B（Google製）' }
]
