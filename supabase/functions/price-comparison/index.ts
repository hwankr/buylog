import { corsHeaders } from '../_shared/cors.ts'

type NaverShopItem = {
  index: number
  title: string
  price: number
  mallName: string
  link: string
}

type OpenAiProductAnalysis = {
  index: number
  total_count: number
  unit_price: number
  pure_name: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { itemName, brand, display = 5 } = await req.json()
    const comparisons = await fetchComparisons({
      itemName: String(itemName ?? ''),
      brand: String(brand ?? ''),
      display: Number(display),
    })

    return jsonResponse({ comparisons })
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unknown error' },
      400,
    )
  }
})

async function fetchComparisons({
  itemName,
  brand,
  display,
}: {
  itemName: string
  brand: string
  display: number
}) {
  const naverClientId = Deno.env.get('NAVER_CLIENT_ID')?.trim()
  const naverClientSecret = Deno.env.get('NAVER_CLIENT_SECRET')?.trim()

  if (!naverClientId || !naverClientSecret) {
    throw new Error('Missing Naver API credentials')
  }

  const query = [brand.trim(), itemName.trim()]
    .filter((part) => part.length > 0)
    .join(' ')
  if (!query) return []

  const url = new URL('https://openapi.naver.com/v1/search/shop.json')
  url.searchParams.set('query', query)
  url.searchParams.set('display', String(Math.min(Math.max(display, 1), 10)))
  url.searchParams.set('sort', 'sim')

  const response = await fetch(url, {
    headers: {
      'X-Naver-Client-Id': naverClientId,
      'X-Naver-Client-Secret': naverClientSecret,
    },
  })

  if (!response.ok) {
    throw new Error(`Naver API failed with status ${response.status}`)
  }

  const data = await response.json()
  const shopItems = ((data.items ?? []) as unknown[])
    .map((item, index) => parseNaverShopItem(item, index))
    .filter((item): item is NaverShopItem => item !== null)

  if (shopItems.length === 0) return []

  const analyses = await analyzeWithOpenAi(shopItems)
  const comparisons = shopItems
    .map((item) => {
      const analysis = analyses.get(item.index)
      const productName = analysis?.pure_name ?? item.title
      const suffix = analysis
        ? ` (총 ${analysis.total_count}개 / 개당 ${formatPrice(
            analysis.unit_price,
          )})`
        : ''

      return {
        store: `[${item.mallName}] ${productName}${suffix}`,
        price: item.price,
        link: item.link,
        isLowest: false,
      }
    })
    .sort((a, b) => a.price - b.price)

  return comparisons.map((item, index) => ({
    ...item,
    isLowest: index === 0,
  }))
}

async function analyzeWithOpenAi(items: NaverShopItem[]) {
  const openAiApiKey = Deno.env.get('OPENAI_API_KEY')?.trim()
  if (!openAiApiKey) return new Map<number, OpenAiProductAnalysis>()

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${openAiApiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content:
              '너는 쇼핑 데이터 분석가야. 상품명에서 총 수량과 단가를 계산하고 JSON 스키마로만 응답해.',
          },
          {
            role: 'user',
            content: JSON.stringify({
              products: items.map((item) => ({
                index: item.index,
                title: item.title,
                price: item.price,
              })),
            }),
          },
        ],
        response_format: {
          type: 'json_schema',
          json_schema: {
            name: 'product_price_analysis',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                items: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      index: { type: 'integer' },
                      total_count: { type: 'integer' },
                      unit_price: { type: 'integer' },
                      pure_name: { type: 'string' },
                    },
                    required: [
                      'index',
                      'total_count',
                      'unit_price',
                      'pure_name',
                    ],
                    additionalProperties: false,
                  },
                },
              },
              required: ['items'],
              additionalProperties: false,
            },
          },
        },
      }),
    })

    if (!response.ok) return new Map<number, OpenAiProductAnalysis>()

    const data = await response.json()
    const content = data.choices?.[0]?.message?.content
    if (typeof content !== 'string' || content.length === 0) {
      return new Map<number, OpenAiProductAnalysis>()
    }

    const parsed = JSON.parse(content)
    const analyses = ((parsed.items ?? []) as unknown[]).filter(
      isOpenAiProductAnalysis,
    )

    return new Map(analyses.map((analysis) => [analysis.index, analysis]))
  } catch {
    return new Map<number, OpenAiProductAnalysis>()
  }
}

function parseNaverShopItem(
  item: unknown,
  index: number,
): NaverShopItem | null {
  if (!item || typeof item !== 'object') return null

  const record = item as Record<string, unknown>
  const price = Number.parseInt(String(record.lprice ?? ''), 10)
  if (!Number.isFinite(price) || price <= 0) return null

  return {
    index,
    title: cleanTitle(String(record.title ?? '')),
    price,
    mallName: String(record.mallName ?? '네이버쇼핑').trim(),
    link: String(record.link ?? '').trim(),
  }
}

function isOpenAiProductAnalysis(
  value: unknown,
): value is OpenAiProductAnalysis {
  if (!value || typeof value !== 'object') return false
  const record = value as Record<string, unknown>

  return (
    Number.isInteger(record.index) &&
    Number.isInteger(record.total_count) &&
    Number.isInteger(record.unit_price) &&
    typeof record.pure_name === 'string' &&
    record.pure_name.trim().length > 0
  )
}

function cleanTitle(value: string) {
  return value
    .replace(/<[^>]*>/g, '')
    .replaceAll('&quot;', '"')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .trim()
}

function formatPrice(price: number) {
  return `${Math.trunc(price).toLocaleString('ko-KR')}원`
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json; charset=utf-8',
    },
  })
}
