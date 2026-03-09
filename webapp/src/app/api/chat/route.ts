import { NextRequest } from 'next/server'
import Anthropic from '@anthropic-ai/sdk'

export const runtime = 'nodejs'

interface RequestBody {
  messages: { role: 'user' | 'assistant'; content: string }[]
  settings: {
    llmBackend: 'claude' | 'ollama' | 'openai-compatible' | 'groq'
    claudeModel: string       // APIキーはサーバー側環境変数で管理
    ollamaEndpoint: string
    ollamaModel: string
    customEndpoint: string
    customApiKey: string
    customModel: string
    groqApiKey: string
    groqModel: string
  }
}

const SYSTEM_PROMPT =
  'あなたは優秀なAIアシスタントです。コードの質問にも、日常の質問にも丁寧に答えてください。'

export async function POST(req: NextRequest) {
  const body: RequestBody = await req.json()
  const { messages, settings } = body

  if (settings.llmBackend === 'claude') {
    return handleClaude(messages, settings)
  } else if (settings.llmBackend === 'groq') {
    return handleGroq(messages, settings)
  } else {
    return handleOpenAICompatible(messages, settings)
  }
}

async function handleClaude(
  messages: RequestBody['messages'],
  settings: RequestBody['settings']
) {
  // APIキーはサーバー側の環境変数から取得（クライアントには渡さない）
  const apiKey = process.env.CLAUDE_API_KEY
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: 'サーバーにCLAUDE_API_KEYが設定されていません。Vercel環境変数を確認してください。' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const client = new Anthropic({ apiKey })

  const stream = await client.messages.stream({
    model: settings.claudeModel || 'claude-sonnet-4-6',
    max_tokens: 8192,
    system: SYSTEM_PROMPT,
    messages
  })

  const encoder = new TextEncoder()
  const readable = new ReadableStream({
    async start(controller) {
      try {
        for await (const chunk of stream) {
          if (
            chunk.type === 'content_block_delta' &&
            chunk.delta.type === 'text_delta'
          ) {
            controller.enqueue(encoder.encode(chunk.delta.text))
          }
        }
      } finally {
        controller.close()
      }
    }
  })

  return new Response(readable, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' }
  })
}

async function handleGroq(
  messages: RequestBody['messages'],
  settings: RequestBody['settings']
) {
  if (!settings.groqApiKey) {
    return new Response(
      JSON.stringify({ error: 'GroqのAPIキーが設定されていません。設定画面で入力してください。' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const endpoint = 'https://api.groq.com/openai/v1/chat/completions'
  const model = settings.groqModel || 'llama-3.1-8b-instant'
  const allMessages = [{ role: 'system', content: SYSTEM_PROMPT }, ...messages]

  let upstream: Response
  try {
    upstream = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${settings.groqApiKey}`
      },
      body: JSON.stringify({ model, messages: allMessages, stream: true })
    })
  } catch {
    return new Response(
      JSON.stringify({ error: 'Groq APIに接続できませんでした。' }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    )
  }

  if (!upstream.ok) {
    const text = await upstream.text()
    return new Response(
      JSON.stringify({ error: `Groq APIエラー (${upstream.status}): ${text}` }),
      { status: upstream.status, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const encoder = new TextEncoder()
  const readable = new ReadableStream({
    async start(controller) {
      const reader = upstream.body!.getReader()
      const decoder = new TextDecoder()
      let buffer = ''

      try {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          buffer += decoder.decode(value, { stream: true })
          const lines = buffer.split('\n')
          buffer = lines.pop() ?? ''

          for (const line of lines) {
            const trimmed = line.trim()
            if (!trimmed || !trimmed.startsWith('data: ')) continue
            const data = trimmed.slice(6)
            if (data === '[DONE]') continue
            try {
              const json = JSON.parse(data)
              const text = json.choices?.[0]?.delta?.content
              if (text) controller.enqueue(encoder.encode(text))
            } catch { /* ignore */ }
          }
        }
      } finally {
        controller.close()
      }
    }
  })

  return new Response(readable, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' }
  })
}

async function handleOpenAICompatible(
  messages: RequestBody['messages'],
  settings: RequestBody['settings']
) {
  const isOllama = settings.llmBackend === 'ollama'
  const baseUrl = isOllama ? settings.ollamaEndpoint : settings.customEndpoint
  const model = isOllama ? settings.ollamaModel : settings.customModel

  if (!baseUrl) {
    const label = isOllama ? 'OllamaのエンドポイントURL' : 'カスタムAPIのエンドポイントURL'
    return new Response(
      JSON.stringify({ error: `${label}が設定されていません。設定画面で入力してください。` }),
      { status: 400, headers: { 'Content-Type': 'application/json' } }
    )
  }

  const endpoint = isOllama
    ? `${baseUrl.replace(/\/$/, '')}/api/chat`
    : `${baseUrl.replace(/\/$/, '')}/chat/completions`

  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (!isOllama && settings.customApiKey) {
    headers['Authorization'] = `Bearer ${settings.customApiKey}`
  }

  const allMessages = [{ role: 'system', content: SYSTEM_PROMPT }, ...messages]

  let upstream: Response
  try {
    upstream = await fetch(endpoint, {
      method: 'POST',
      headers,
      body: JSON.stringify({ model, messages: allMessages, stream: true })
    })
  } catch {
    return new Response(
      JSON.stringify({ error: `サーバーに接続できませんでした: ${endpoint}` }),
      { status: 502, headers: { 'Content-Type': 'application/json' } }
    )
  }

  if (!upstream.ok) {
    const text = await upstream.text()
    return new Response(
      JSON.stringify({ error: `APIエラー (${upstream.status}): ${text}` }),
      { status: upstream.status, headers: { 'Content-Type': 'application/json' } }
    )
  }

  // Transform the upstream SSE/NDJSON stream to plain text
  const encoder = new TextEncoder()
  const readable = new ReadableStream({
    async start(controller) {
      const reader = upstream.body!.getReader()
      const decoder = new TextDecoder()
      let buffer = ''

      try {
        while (true) {
          const { done, value } = await reader.read()
          if (done) break

          buffer += decoder.decode(value, { stream: true })
          const lines = buffer.split('\n')
          buffer = lines.pop() ?? ''

          for (const line of lines) {
            const trimmed = line.trim()
            if (!trimmed) continue

            // OpenAI-compatible SSE
            if (trimmed.startsWith('data: ')) {
              const data = trimmed.slice(6)
              if (data === '[DONE]') continue
              try {
                const json = JSON.parse(data)
                const text = json.choices?.[0]?.delta?.content
                if (text) controller.enqueue(encoder.encode(text))
              } catch { /* ignore */ }
              continue
            }

            // Ollama NDJSON
            try {
              const json = JSON.parse(trimmed)
              const text = json.message?.content ?? json.response
              if (text) controller.enqueue(encoder.encode(text))
            } catch { /* ignore */ }
          }
        }
      } finally {
        controller.close()
      }
    }
  })

  return new Response(readable, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' }
  })
}
