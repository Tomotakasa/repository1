'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import Sidebar from '@/components/Sidebar'
import MessageBubble from '@/components/MessageBubble'
import { ChatMessage, Settings, DEFAULT_SETTINGS } from '@/lib/types'
import { loadSettings, loadHistory, saveHistory } from '@/lib/storage'

export default function ChatPage() {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [input, setInput] = useState('')
  const [settings, setSettings] = useState<Settings>(DEFAULT_SETTINGS)
  const [isStreaming, setIsStreaming] = useState(false)
  const abortRef = useRef<AbortController | null>(null)
  const bottomRef = useRef<HTMLDivElement>(null)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  useEffect(() => {
    setSettings(loadSettings())
    setMessages(loadHistory())
  }, [])

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages])

  const send = useCallback(async () => {
    const text = input.trim()
    if (!text || isStreaming) return

    const userMsg: ChatMessage = {
      id: crypto.randomUUID(),
      role: 'user',
      content: text,
      timestamp: new Date()
    }

    const assistantMsg: ChatMessage = {
      id: crypto.randomUUID(),
      role: 'assistant',
      content: '',
      timestamp: new Date(),
      isStreaming: true
    }

    const nextMessages = [...messages, userMsg, assistantMsg]
    setMessages(nextMessages)
    setInput('')
    setIsStreaming(true)

    // Auto-resize textarea back
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
    }

    const controller = new AbortController()
    abortRef.current = controller

    try {
      const apiMessages = nextMessages
        .filter(m => !m.isStreaming)
        .map(m => ({ role: m.role, content: m.content }))

      const res = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ messages: apiMessages, settings }),
        signal: controller.signal
      })

      if (!res.ok) {
        const err = await res.json()
        setMessages(prev => {
          const updated = prev.map(m =>
            m.id === assistantMsg.id
              ? { ...m, content: `エラー: ${err.error}`, isStreaming: false }
              : m
          )
          saveHistory(updated)
          return updated
        })
        return
      }

      const reader = res.body!.getReader()
      const decoder = new TextDecoder()
      let accumulated = ''

      while (true) {
        const { done, value } = await reader.read()
        if (done) break
        accumulated += decoder.decode(value, { stream: true })
        const snap = accumulated
        setMessages(prev =>
          prev.map(m =>
            m.id === assistantMsg.id ? { ...m, content: snap } : m
          )
        )
      }

      setMessages(prev => {
        const updated = prev.map(m =>
          m.id === assistantMsg.id ? { ...m, content: accumulated, isStreaming: false } : m
        )
        saveHistory(updated)
        return updated
      })
    } catch (e) {
      if ((e as Error).name === 'AbortError') {
        setMessages(prev => {
          const updated = prev.map(m =>
            m.id === assistantMsg.id ? { ...m, isStreaming: false } : m
          )
          saveHistory(updated)
          return updated
        })
      }
    } finally {
      setIsStreaming(false)
      abortRef.current = null
    }
  }, [input, isStreaming, messages, settings])

  function handleStop() {
    abortRef.current?.abort()
  }

  function handleKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      send()
    }
  }

  function handleInput(e: React.ChangeEvent<HTMLTextAreaElement>) {
    setInput(e.target.value)
    // Auto-resize
    e.target.style.height = 'auto'
    e.target.style.height = `${Math.min(e.target.scrollHeight, 160)}px`
  }

  function handleClearChat() {
    setMessages([])
    saveHistory([])
  }

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar />
      <div className="flex flex-col flex-1 min-w-0">
        {/* Header */}
        <header className="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between shrink-0">
          <div>
            <h1 className="font-semibold text-gray-800">チャット</h1>
            <p className="text-xs text-gray-400">
              {settings.llmBackend === 'claude'
                ? `Claude API（${settings.claudeModel}）`
                : settings.llmBackend === 'groq'
                ? `Groq（${settings.groqModel || 'llama-3.1-8b-instant'}）`
                : settings.llmBackend === 'ollama'
                ? `Ollama（${settings.ollamaModel}）`
                : `カスタムAPI（${settings.customModel || '未設定'}）`}
            </p>
          </div>
          {messages.length > 0 && (
            <button
              onClick={handleClearChat}
              className="text-xs text-gray-400 hover:text-gray-600 transition-colors"
            >
              会話をクリア
            </button>
          )}
        </header>

        {/* Messages */}
        <div className="flex-1 overflow-y-auto px-4 py-4">
          {messages.length === 0 && (
            <div className="flex flex-col items-center justify-center h-full text-center text-gray-400">
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-violet-500 to-blue-500 flex items-center justify-center text-white text-2xl mb-4">
                AI
              </div>
              <p className="font-medium text-gray-500">何でも聞いてください</p>
              <p className="text-sm mt-1">コードの質問・レビュー・バグ修正など</p>
              <div className="mt-6 grid grid-cols-1 sm:grid-cols-2 gap-2 max-w-md">
                {QUICK_PROMPTS.map(p => (
                  <button
                    key={p}
                    onClick={() => setInput(p)}
                    className="text-left text-sm bg-white border border-gray-200 rounded-xl px-3 py-2 hover:border-blue-300 hover:bg-blue-50 transition-colors"
                  >
                    {p}
                  </button>
                ))}
              </div>
            </div>
          )}
          {messages.map(msg => (
            <MessageBubble key={msg.id} message={msg} />
          ))}
          <div ref={bottomRef} />
        </div>

        {/* Input area */}
        <div className="bg-white border-t border-gray-200 px-4 py-3 shrink-0">
          <div className="flex items-end gap-2 max-w-4xl mx-auto">
            <textarea
              ref={textareaRef}
              value={input}
              onChange={handleInput}
              onKeyDown={handleKeyDown}
              placeholder="メッセージを入力... (Enterで送信、Shift+Enterで改行)"
              rows={1}
              disabled={isStreaming}
              className="flex-1 resize-none rounded-xl border border-gray-300 px-4 py-3 text-sm focus:outline-none focus:border-blue-400 focus:ring-2 focus:ring-blue-100 disabled:bg-gray-50 disabled:text-gray-400 transition-colors"
              style={{ minHeight: '48px', maxHeight: '160px' }}
            />
            {isStreaming ? (
              <button
                onClick={handleStop}
                className="w-12 h-12 rounded-xl bg-red-500 hover:bg-red-600 text-white flex items-center justify-center transition-colors shrink-0"
                title="停止"
              >
                <StopIcon />
              </button>
            ) : (
              <button
                onClick={send}
                disabled={!input.trim()}
                className="w-12 h-12 rounded-xl bg-blue-600 hover:bg-blue-700 disabled:bg-gray-200 disabled:cursor-not-allowed text-white flex items-center justify-center transition-colors shrink-0"
                title="送信"
              >
                <SendIcon />
              </button>
            )}
          </div>
          <p className="text-center text-[10px] text-gray-300 mt-2">
            Enterで送信 / Shift+Enterで改行
          </p>
        </div>
      </div>
    </div>
  )
}

const QUICK_PROMPTS = [
  'このコードをレビューして',
  'バグの原因を探して',
  'Pythonでリストをソートするには？',
  'READMEの書き方を教えて'
]

function SendIcon() {
  return (
    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
    </svg>
  )
}

function StopIcon() {
  return (
    <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
      <rect x="6" y="6" width="12" height="12" rx="2" />
    </svg>
  )
}
