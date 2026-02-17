#!/usr/bin/env python3
"""
天気予報比較アプリ (Weather Forecast Comparator)

ブラウザベースのインタラクティブな天気予報比較アプリ。
複数の天気予報サービスから明日の天気を取得し、グラフで可視化する。

使用API（すべて無料・APIキー不要）:
  1. Open-Meteo   - オープンソースの天気予報API
  2. wttr.in      - コンソール向け天気予報サービス
  3. 気象庁 (JMA) - 日本の気象庁の公開API

起動方法:
  python3 weather_app.py
  → ブラウザで http://localhost:8080 を開く
"""

import json
import urllib.request
import urllib.error
import urllib.parse
from http.server import HTTPServer, BaseHTTPRequestHandler
from datetime import datetime, timedelta
from typing import Optional
import threading
import webbrowser
import sys

# ========== 地域データベース ==========

LOCATIONS = {
    # 北海道・東北
    "札幌": {"lat": 43.0621, "lon": 141.3544, "en": "Sapporo", "jma": "016000", "region": "北海道・東北"},
    "仙台": {"lat": 38.2682, "lon": 140.8694, "en": "Sendai", "jma": "040000", "region": "北海道・東北"},
    # 関東
    "東京": {"lat": 35.6762, "lon": 139.6503, "en": "Tokyo", "jma": "130000", "region": "関東"},
    "横浜": {"lat": 35.4437, "lon": 139.6380, "en": "Yokohama", "jma": "140000", "region": "関東"},
    "さいたま": {"lat": 35.8617, "lon": 139.6455, "en": "Saitama", "jma": "110000", "region": "関東"},
    "千葉": {"lat": 35.6073, "lon": 140.1063, "en": "Chiba", "jma": "120000", "region": "関東"},
    # 中部
    "名古屋": {"lat": 35.1815, "lon": 136.9066, "en": "Nagoya", "jma": "230000", "region": "中部"},
    "新潟": {"lat": 37.9026, "lon": 139.0236, "en": "Niigata", "jma": "150000", "region": "中部"},
    "金沢": {"lat": 36.5613, "lon": 136.6562, "en": "Kanazawa", "jma": "170000", "region": "中部"},
    "静岡": {"lat": 34.9756, "lon": 138.3828, "en": "Shizuoka", "jma": "220000", "region": "中部"},
    # 近畿
    "大阪": {"lat": 34.6937, "lon": 135.5023, "en": "Osaka", "jma": "270000", "region": "近畿"},
    "京都": {"lat": 35.0116, "lon": 135.7681, "en": "Kyoto", "jma": "260000", "region": "近畿"},
    "神戸": {"lat": 34.6901, "lon": 135.1956, "en": "Kobe", "jma": "280000", "region": "近畿"},
    # 中国・四国
    "広島": {"lat": 34.3853, "lon": 132.4553, "en": "Hiroshima", "jma": "340000", "region": "中国・四国"},
    "高松": {"lat": 34.3401, "lon": 134.0434, "en": "Takamatsu", "jma": "370000", "region": "中国・四国"},
    # 九州・沖縄
    "福岡": {"lat": 33.5904, "lon": 130.4017, "en": "Fukuoka", "jma": "400000", "region": "九州・沖縄"},
    "鹿児島": {"lat": 31.5966, "lon": 130.5571, "en": "Kagoshima", "jma": "460100", "region": "九州・沖縄"},
    "那覇": {"lat": 26.2124, "lon": 127.6809, "en": "Naha", "jma": "471000", "region": "九州・沖縄"},
}


# ========== API取得関数 ==========

def fetch_json(url: str, timeout: int = 10) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": "WeatherApp/2.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def _safe_float(value) -> Optional[float]:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


WMO_CODES = {
    0: "快晴", 1: "晴れ", 2: "一部曇り", 3: "曇り",
    45: "霧", 48: "着氷性の霧",
    51: "弱い霧雨", 53: "霧雨", 55: "強い霧雨",
    56: "弱い着氷性の霧雨", 57: "強い着氷性の霧雨",
    61: "弱い雨", 63: "雨", 65: "強い雨",
    66: "弱い着氷性の雨", 67: "強い着氷性の雨",
    71: "弱い雪", 73: "雪", 75: "強い雪", 77: "霧雪",
    80: "弱いにわか雨", 81: "にわか雨", 82: "激しいにわか雨",
    85: "弱いにわか雪", 86: "強いにわか雪",
    95: "雷雨", 96: "雹を伴う雷雨", 99: "激しい雹を伴う雷雨",
}

WMO_ICONS = {
    0: "☀️", 1: "🌤️", 2: "⛅", 3: "☁️",
    45: "🌫️", 48: "🌫️",
    51: "🌦️", 53: "🌦️", 55: "🌧️",
    56: "🌧️", 57: "🌧️",
    61: "🌧️", 63: "🌧️", 65: "🌧️",
    66: "🌧️", 67: "🌧️",
    71: "🌨️", 73: "🌨️", 75: "❄️", 77: "🌨️",
    80: "🌦️", 81: "🌧️", 82: "⛈️",
    85: "🌨️", 86: "❄️",
    95: "⛈️", 96: "⛈️", 99: "⛈️",
}


def fetch_open_meteo(city: str) -> dict:
    loc = LOCATIONS[city]
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={loc['lat']}&longitude={loc['lon']}"
            f"&daily=weather_code,temperature_2m_max,temperature_2m_min,"
            f"precipitation_probability_max,wind_speed_10m_max"
            f"&hourly=relative_humidity_2m"
            f"&timezone=Asia%2FTokyo"
            f"&start_date={tomorrow}&end_date={tomorrow}"
        )
        data = fetch_json(url)
        daily = data["daily"]
        code = daily["weather_code"][0]

        humidity_values = data.get("hourly", {}).get("relative_humidity_2m", [])
        avg_humidity = None
        if humidity_values:
            valid = [v for v in humidity_values if v is not None]
            if valid:
                avg_humidity = round(sum(valid) / len(valid), 1)

        return {
            "source": "Open-Meteo",
            "weather": WMO_CODES.get(code, f"不明({code})"),
            "icon": WMO_ICONS.get(code, "❓"),
            "temp_max": daily["temperature_2m_max"][0],
            "temp_min": daily["temperature_2m_min"][0],
            "precipitation": daily["precipitation_probability_max"][0],
            "wind": daily["wind_speed_10m_max"][0],
            "humidity": avg_humidity,
            "error": None,
        }
    except Exception as e:
        return {"source": "Open-Meteo", "error": str(e)}


def fetch_wttr_in(city: str) -> dict:
    loc = LOCATIONS[city]
    try:
        url = f"https://wttr.in/{loc['en']}?format=j1"
        data = fetch_json(url)

        if len(data.get("weather", [])) < 2:
            return {"source": "wttr.in", "error": "明日のデータなし"}

        tw = data["weather"][1]
        hourly = tw.get("hourly", [])
        mid = hourly[len(hourly) // 2] if hourly else {}

        desc = ""
        if mid.get("lang_ja"):
            desc = mid["lang_ja"][0].get("value", "")
        if not desc:
            desc = mid.get("weatherDesc", [{}])[0].get("value", "不明")

        return {
            "source": "wttr.in",
            "weather": desc,
            "icon": "",
            "temp_max": _safe_float(tw.get("maxtempC")),
            "temp_min": _safe_float(tw.get("mintempC")),
            "precipitation": _safe_float(mid.get("chanceofrain")),
            "wind": _safe_float(mid.get("windspeedKmph")),
            "humidity": _safe_float(mid.get("humidity")),
            "error": None,
        }
    except Exception as e:
        return {"source": "wttr.in", "error": str(e)}


def fetch_jma(city: str) -> dict:
    loc = LOCATIONS[city]
    tomorrow_str = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    try:
        url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{loc['jma']}.json"
        data = fetch_json(url)
        ts = data[0]["timeSeries"]

        weather_text = "不明"
        wts = ts[0]
        area = wts["areas"][0]
        for i, td in enumerate(wts["timeDefines"]):
            if td.startswith(tomorrow_str):
                weathers = area.get("weathers", [])
                if i < len(weathers):
                    weather_text = weathers[i]
                break

        precip = None
        if len(ts) > 1:
            pts = ts[1]
            pa = pts["areas"][0]
            pops = pa.get("pops", [])
            vals = []
            for i, td in enumerate(pts["timeDefines"]):
                if td.startswith(tomorrow_str) and i < len(pops):
                    v = _safe_float(pops[i])
                    if v is not None:
                        vals.append(v)
            if vals:
                precip = max(vals)

        temp_max = temp_min = None
        if len(ts) > 2:
            tts = ts[2]
            ta = tts["areas"][0]
            for i, td in enumerate(tts["timeDefines"]):
                if td.startswith(tomorrow_str):
                    mins = ta.get("tempsMin", [])
                    maxs = ta.get("tempsMax", [])
                    if i < len(mins):
                        temp_min = _safe_float(mins[i])
                    if i < len(maxs):
                        temp_max = _safe_float(maxs[i])
                    break

        return {
            "source": "気象庁",
            "weather": weather_text,
            "icon": "",
            "temp_max": temp_max,
            "temp_min": temp_min,
            "precipitation": precip,
            "wind": None,
            "humidity": None,
            "error": None,
        }
    except Exception as e:
        return {"source": "気象庁", "error": str(e)}


# ========== HTTPサーバー ==========

class WeatherHandler(BaseHTTPRequestHandler):

    def log_message(self, format, *args):
        pass  # ログ出力を抑制

    def _send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, html):
        body = html.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        if path == "/":
            self._send_html(HTML_PAGE)

        elif path == "/api/locations":
            regions = {}
            for name, info in LOCATIONS.items():
                r = info["region"]
                if r not in regions:
                    regions[r] = []
                regions[r].append(name)
            self._send_json({"regions": regions})

        elif path == "/api/forecast":
            cities = params.get("cities", [""])[0].split(",")
            cities = [c.strip() for c in cities if c.strip() in LOCATIONS]
            if not cities:
                self._send_json({"error": "都市を選択してください"}, 400)
                return

            tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
            results = {}
            for city in cities:
                city_results = []
                for fetcher in [fetch_open_meteo, fetch_wttr_in, fetch_jma]:
                    city_results.append(fetcher(city))
                results[city] = city_results

            self._send_json({"date": tomorrow, "results": results})

        else:
            self.send_error(404)


# ========== HTMLフロントエンド ==========

HTML_PAGE = r"""<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>天気予報比較アプリ</title>
<style>
  :root {
    --bg: #0f172a;
    --surface: #1e293b;
    --surface2: #334155;
    --border: #475569;
    --text: #f1f5f9;
    --text2: #94a3b8;
    --accent: #38bdf8;
    --accent2: #818cf8;
    --red: #f87171;
    --orange: #fb923c;
    --green: #4ade80;
    --yellow: #facc15;
    --radius: 12px;
  }
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Hiragino Sans",
                 "Noto Sans JP", sans-serif;
    background: var(--bg);
    color: var(--text);
    min-height: 100vh;
  }
  .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
  header {
    text-align: center;
    padding: 30px 0 20px;
  }
  header h1 {
    font-size: 1.8rem;
    background: linear-gradient(135deg, var(--accent), var(--accent2));
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
  }
  header p { color: var(--text2); margin-top: 6px; font-size: 0.95rem; }
  #dateLabel {
    display: inline-block;
    background: var(--surface2);
    padding: 4px 14px;
    border-radius: 20px;
    font-size: 0.85rem;
    color: var(--accent);
    margin-top: 10px;
  }

  /* City selector */
  .selector-panel {
    background: var(--surface);
    border-radius: var(--radius);
    padding: 24px;
    margin: 20px 0;
    border: 1px solid var(--border);
  }
  .selector-panel h2 {
    font-size: 1.1rem;
    margin-bottom: 16px;
    color: var(--accent);
  }
  .region-group { margin-bottom: 14px; }
  .region-label {
    font-size: 0.8rem;
    color: var(--text2);
    margin-bottom: 6px;
    text-transform: uppercase;
    letter-spacing: 1px;
  }
  .city-chips { display: flex; flex-wrap: wrap; gap: 8px; }
  .city-chip {
    padding: 8px 16px;
    border-radius: 20px;
    border: 1px solid var(--border);
    background: var(--surface2);
    color: var(--text);
    cursor: pointer;
    transition: all 0.2s;
    font-size: 0.9rem;
    user-select: none;
  }
  .city-chip:hover { border-color: var(--accent); }
  .city-chip.selected {
    background: var(--accent);
    color: var(--bg);
    border-color: var(--accent);
    font-weight: 600;
  }
  .btn-row {
    display: flex;
    gap: 12px;
    margin-top: 18px;
    align-items: center;
  }
  .btn {
    padding: 12px 32px;
    border-radius: 8px;
    border: none;
    font-size: 1rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
  }
  .btn-primary {
    background: linear-gradient(135deg, var(--accent), var(--accent2));
    color: var(--bg);
  }
  .btn-primary:hover { opacity: 0.9; transform: translateY(-1px); }
  .btn-primary:disabled { opacity: 0.4; cursor: not-allowed; transform: none; }
  .btn-secondary {
    background: var(--surface2);
    color: var(--text2);
    border: 1px solid var(--border);
  }
  .btn-secondary:hover { color: var(--text); border-color: var(--text2); }
  .selected-count { color: var(--text2); font-size: 0.85rem; margin-left: auto; }

  /* Loading */
  .loading {
    text-align: center;
    padding: 60px;
    color: var(--text2);
    display: none;
  }
  .loading.show { display: block; }
  .spinner {
    display: inline-block;
    width: 36px; height: 36px;
    border: 3px solid var(--surface2);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin-bottom: 12px;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  /* Results */
  #results { display: none; }
  #results.show { display: block; }

  /* City Section */
  .city-section {
    background: var(--surface);
    border-radius: var(--radius);
    padding: 24px;
    margin-bottom: 24px;
    border: 1px solid var(--border);
  }
  .city-section h2 {
    font-size: 1.3rem;
    margin-bottom: 18px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .city-section h2 .city-name { color: var(--accent); }

  /* Source cards */
  .source-cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 16px;
    margin-bottom: 24px;
  }
  .source-card {
    background: var(--surface2);
    border-radius: 10px;
    padding: 18px;
    border: 1px solid var(--border);
    position: relative;
    overflow: hidden;
  }
  .source-card::before {
    content: "";
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 3px;
  }
  .source-card:nth-child(1)::before { background: var(--accent); }
  .source-card:nth-child(2)::before { background: var(--green); }
  .source-card:nth-child(3)::before { background: var(--orange); }

  .source-name {
    font-size: 0.8rem;
    color: var(--text2);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 10px;
  }
  .weather-main {
    font-size: 1.1rem;
    font-weight: 600;
    margin-bottom: 12px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .weather-icon { font-size: 1.6rem; }
  .source-stats {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 8px;
  }
  .stat-item {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .stat-label { font-size: 0.75rem; color: var(--text2); }
  .stat-value { font-size: 1rem; font-weight: 600; }
  .stat-value.temp-high { color: var(--red); }
  .stat-value.temp-low { color: var(--accent); }
  .stat-value.rain { color: var(--yellow); }
  .error-card {
    background: rgba(248, 113, 113, 0.1);
    border-color: var(--red);
    color: var(--red);
    text-align: center;
    padding: 30px;
    font-size: 0.9rem;
  }

  /* Charts */
  .charts-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px;
  }
  @media (max-width: 700px) {
    .charts-grid { grid-template-columns: 1fr; }
  }
  .chart-box {
    background: var(--surface2);
    border-radius: 10px;
    padding: 18px;
    border: 1px solid var(--border);
  }
  .chart-title {
    font-size: 0.9rem;
    color: var(--text2);
    margin-bottom: 14px;
    text-align: center;
  }

  /* Bar chart */
  .bar-chart { display: flex; align-items: flex-end; justify-content: center; gap: 12px; height: 160px; }
  .bar-group { display: flex; flex-direction: column; align-items: center; gap: 4px; }
  .bar-wrapper {
    display: flex;
    align-items: flex-end;
    gap: 4px;
    height: 120px;
  }
  .bar {
    width: 28px;
    border-radius: 4px 4px 0 0;
    transition: height 0.6s ease;
    position: relative;
    min-height: 2px;
  }
  .bar-label {
    font-size: 0.7rem;
    color: var(--text2);
    text-align: center;
    max-width: 80px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .bar-val {
    position: absolute;
    top: -18px;
    left: 50%;
    transform: translateX(-50%);
    font-size: 0.7rem;
    font-weight: 600;
    white-space: nowrap;
  }

  /* Legend */
  .chart-legend {
    display: flex;
    justify-content: center;
    gap: 16px;
    margin-top: 10px;
    flex-wrap: wrap;
  }
  .legend-item {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 0.75rem;
    color: var(--text2);
  }
  .legend-dot {
    width: 10px; height: 10px;
    border-radius: 50%;
  }

  /* Multi-city comparison */
  .multi-city-section {
    background: var(--surface);
    border-radius: var(--radius);
    padding: 24px;
    margin-bottom: 24px;
    border: 1px solid var(--border);
  }
  .multi-city-section h2 {
    font-size: 1.3rem;
    margin-bottom: 18px;
    color: var(--accent2);
  }
  .comparison-chart {
    display: flex;
    align-items: flex-end;
    justify-content: center;
    gap: 20px;
    height: 200px;
    padding: 0 10px;
  }
  .comp-group { text-align: center; }
  .comp-bars {
    display: flex;
    align-items: flex-end;
    gap: 3px;
    height: 160px;
    justify-content: center;
  }
  .comp-bar {
    width: 22px;
    border-radius: 3px 3px 0 0;
    transition: height 0.6s ease;
    position: relative;
    min-height: 2px;
  }
  .comp-bar .bar-val {
    font-size: 0.65rem;
    top: -16px;
  }
  .comp-label {
    font-size: 0.8rem;
    color: var(--text);
    margin-top: 6px;
    font-weight: 600;
  }

  footer {
    text-align: center;
    padding: 30px;
    color: var(--text2);
    font-size: 0.8rem;
  }
</style>
</head>
<body>
<div class="container">
  <header>
    <h1>天気予報比較アプリ</h1>
    <p>Open-Meteo / wttr.in / 気象庁 の3社を比較</p>
    <div id="dateLabel"></div>
  </header>

  <div class="selector-panel">
    <h2>比較する都市を選んでください</h2>
    <div id="citySelector"></div>
    <div class="btn-row">
      <button class="btn btn-primary" id="fetchBtn" disabled onclick="fetchForecasts()">
        天気を取得する
      </button>
      <button class="btn btn-secondary" onclick="clearSelection()">クリア</button>
      <span class="selected-count" id="selectedCount">0 都市を選択中</span>
    </div>
  </div>

  <div class="loading" id="loading">
    <div class="spinner"></div>
    <div>天気予報を取得中...</div>
  </div>

  <div id="results"></div>
</div>

<footer>
  天気予報比較アプリ — データ提供: Open-Meteo, wttr.in, 気象庁
</footer>

<script>
const COLORS = {
  sources: ['#38bdf8', '#4ade80', '#fb923c'],
  tempHigh: '#f87171',
  tempLow: '#60a5fa',
  rain: '#facc15',
  wind: '#a78bfa',
  humidity: '#2dd4bf',
};
const SOURCE_NAMES = ['Open-Meteo', 'wttr.in', '気象庁'];
let selectedCities = new Set();
let tomorrow = '';

// Init
(async () => {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  tomorrow = d.toISOString().split('T')[0];
  const dayNames = ['日', '月', '火', '水', '木', '金', '土'];
  document.getElementById('dateLabel').textContent =
    `${tomorrow} (${dayNames[d.getDay()]}) の天気予報`;

  const resp = await fetch('/api/locations');
  const data = await resp.json();
  renderCitySelector(data.regions);
})();

function renderCitySelector(regions) {
  const el = document.getElementById('citySelector');
  let html = '';
  for (const [region, cities] of Object.entries(regions)) {
    html += `<div class="region-group">`;
    html += `<div class="region-label">${region}</div>`;
    html += `<div class="city-chips">`;
    for (const city of cities) {
      html += `<div class="city-chip" data-city="${city}" onclick="toggleCity(this, '${city}')">${city}</div>`;
    }
    html += `</div></div>`;
  }
  el.innerHTML = html;
}

function toggleCity(el, city) {
  if (selectedCities.has(city)) {
    selectedCities.delete(city);
    el.classList.remove('selected');
  } else {
    selectedCities.add(city);
    el.classList.add('selected');
  }
  updateCount();
}

function clearSelection() {
  selectedCities.clear();
  document.querySelectorAll('.city-chip.selected').forEach(e => e.classList.remove('selected'));
  updateCount();
  document.getElementById('results').className = '';
  document.getElementById('results').innerHTML = '';
}

function updateCount() {
  const n = selectedCities.size;
  document.getElementById('selectedCount').textContent = `${n} 都市を選択中`;
  document.getElementById('fetchBtn').disabled = n === 0;
}

async function fetchForecasts() {
  if (selectedCities.size === 0) return;
  const loading = document.getElementById('loading');
  const results = document.getElementById('results');
  results.className = '';
  results.innerHTML = '';
  loading.classList.add('show');

  try {
    const cities = [...selectedCities].join(',');
    const resp = await fetch(`/api/forecast?cities=${encodeURIComponent(cities)}`);
    const data = await resp.json();
    if (data.error) {
      results.innerHTML = `<div class="error-card">${data.error}</div>`;
    } else {
      renderResults(data);
    }
  } catch (e) {
    results.innerHTML = `<div class="city-section"><div class="error-card">通信エラー: ${e.message}</div></div>`;
  }
  loading.classList.remove('show');
  results.className = 'show';
  results.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

function renderResults(data) {
  const container = document.getElementById('results');
  let html = '';

  const cityNames = Object.keys(data.results);

  // Per-city sections
  for (const city of cityNames) {
    const forecasts = data.results[city];
    html += renderCitySection(city, forecasts);
  }

  // Multi-city comparison if 2+
  if (cityNames.length >= 2) {
    html += renderMultiCityComparison(data.results);
  }

  container.innerHTML = html;
}

function renderCitySection(city, forecasts) {
  let html = `<div class="city-section">`;
  html += `<h2><span class="city-name">${city}</span> の明日の天気</h2>`;

  // Source cards
  html += `<div class="source-cards">`;
  for (let i = 0; i < forecasts.length; i++) {
    const f = forecasts[i];
    if (f.error) {
      html += `<div class="source-card error-card">
        <div class="source-name">${f.source}</div>
        <div>取得エラー: ${f.error}</div>
      </div>`;
    } else {
      html += `<div class="source-card">
        <div class="source-name">${f.source}</div>
        <div class="weather-main">
          ${f.icon ? `<span class="weather-icon">${f.icon}</span>` : ''}
          <span>${f.weather}</span>
        </div>
        <div class="source-stats">
          <div class="stat-item">
            <span class="stat-label">最高気温</span>
            <span class="stat-value temp-high">${f.temp_max != null ? f.temp_max + '°C' : '-'}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">最低気温</span>
            <span class="stat-value temp-low">${f.temp_min != null ? f.temp_min + '°C' : '-'}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">降水確率</span>
            <span class="stat-value rain">${f.precipitation != null ? f.precipitation + '%' : '-'}</span>
          </div>
          <div class="stat-item">
            <span class="stat-label">風速</span>
            <span class="stat-value">${f.wind != null ? f.wind + ' km/h' : '-'}</span>
          </div>
          ${f.humidity != null ? `<div class="stat-item">
            <span class="stat-label">湿度</span>
            <span class="stat-value">${f.humidity}%</span>
          </div>` : ''}
        </div>
      </div>`;
    }
  }
  html += `</div>`;

  // Charts
  const valid = forecasts.filter(f => !f.error);
  if (valid.length >= 2) {
    html += renderCharts(valid);
  }

  html += `</div>`;
  return html;
}

function renderCharts(forecasts) {
  let html = `<div class="charts-grid">`;

  // Temperature chart
  html += `<div class="chart-box">`;
  html += `<div class="chart-title">気温比較 (°C)</div>`;
  html += `<div class="bar-chart">`;
  const allTemps = forecasts.flatMap(f => [f.temp_max, f.temp_min]).filter(v => v != null);
  const tempMax = Math.max(...allTemps, 1);
  const tempRange = tempMax - Math.min(0, Math.min(...allTemps));

  for (let i = 0; i < forecasts.length; i++) {
    const f = forecasts[i];
    const hH = f.temp_max != null ? Math.max(5, (f.temp_max / (tempRange || 1)) * 100) : 0;
    const hL = f.temp_min != null ? Math.max(5, (f.temp_min / (tempRange || 1)) * 100) : 0;
    html += `<div class="bar-group">
      <div class="bar-wrapper">
        <div class="bar" style="height:${Math.abs(hH)}px; background:${COLORS.tempHigh}">
          <span class="bar-val" style="color:${COLORS.tempHigh}">${f.temp_max != null ? f.temp_max + '°' : '-'}</span>
        </div>
        <div class="bar" style="height:${Math.abs(hL)}px; background:${COLORS.tempLow}">
          <span class="bar-val" style="color:${COLORS.tempLow}">${f.temp_min != null ? f.temp_min + '°' : '-'}</span>
        </div>
      </div>
      <div class="bar-label">${f.source}</div>
    </div>`;
  }
  html += `</div>`;
  html += `<div class="chart-legend">
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.tempHigh}"></div>最高</div>
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.tempLow}"></div>最低</div>
  </div>`;
  html += `</div>`;

  // Precipitation / Wind / Humidity chart
  html += `<div class="chart-box">`;
  html += `<div class="chart-title">降水確率 / 風速 / 湿度</div>`;
  html += `<div class="bar-chart">`;
  for (let i = 0; i < forecasts.length; i++) {
    const f = forecasts[i];
    const pH = f.precipitation != null ? Math.max(3, f.precipitation * 1.1) : 0;
    const wH = f.wind != null ? Math.max(3, f.wind * 2.5) : 0;
    const hH = f.humidity != null ? Math.max(3, f.humidity * 1.1) : 0;
    html += `<div class="bar-group">
      <div class="bar-wrapper">
        ${f.precipitation != null ? `<div class="bar" style="height:${pH}px; background:${COLORS.rain}">
          <span class="bar-val" style="color:${COLORS.rain}">${f.precipitation}%</span>
        </div>` : ''}
        ${f.wind != null ? `<div class="bar" style="height:${wH}px; background:${COLORS.wind}">
          <span class="bar-val" style="color:${COLORS.wind}">${f.wind}</span>
        </div>` : ''}
        ${f.humidity != null ? `<div class="bar" style="height:${hH}px; background:${COLORS.humidity}">
          <span class="bar-val" style="color:${COLORS.humidity}">${f.humidity}%</span>
        </div>` : ''}
      </div>
      <div class="bar-label">${f.source}</div>
    </div>`;
  }
  html += `</div>`;
  html += `<div class="chart-legend">
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.rain}"></div>降水確率(%)</div>
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.wind}"></div>風速(km/h)</div>
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.humidity}"></div>湿度(%)</div>
  </div>`;
  html += `</div>`;

  html += `</div>`;
  return html;
}

function renderMultiCityComparison(allResults) {
  const cities = Object.keys(allResults);
  let html = `<div class="multi-city-section">`;
  html += `<h2>都市間比較</h2>`;

  // Use Open-Meteo (index 0) as primary, fallback to wttr.in (index 1)
  const cityData = [];
  for (const city of cities) {
    const forecasts = allResults[city];
    const valid = forecasts.find(f => !f.error && f.temp_max != null) || forecasts.find(f => !f.error);
    if (valid && !valid.error) {
      cityData.push({ city, ...valid });
    }
  }

  if (cityData.length < 2) {
    html += `<p style="color:var(--text2);text-align:center">比較可能なデータが不足しています</p>`;
    html += `</div>`;
    return html;
  }

  html += `<div class="charts-grid">`;

  // Temperature comparison
  html += `<div class="chart-box">`;
  html += `<div class="chart-title">各都市の気温比較 (°C)</div>`;
  html += `<div class="comparison-chart">`;
  const allT = cityData.flatMap(d => [d.temp_max, d.temp_min]).filter(v => v != null);
  const tRange = Math.max(...allT, 1) - Math.min(0, Math.min(...allT, 0));
  for (const d of cityData) {
    const hH = d.temp_max != null ? Math.max(5, (d.temp_max / (tRange || 1)) * 130) : 0;
    const hL = d.temp_min != null ? Math.max(5, (d.temp_min / (tRange || 1)) * 130) : 0;
    html += `<div class="comp-group">
      <div class="comp-bars">
        <div class="comp-bar" style="height:${Math.abs(hH)}px; background:${COLORS.tempHigh}">
          <span class="bar-val" style="color:${COLORS.tempHigh}">${d.temp_max != null ? d.temp_max + '°' : ''}</span>
        </div>
        <div class="comp-bar" style="height:${Math.abs(hL)}px; background:${COLORS.tempLow}">
          <span class="bar-val" style="color:${COLORS.tempLow}">${d.temp_min != null ? d.temp_min + '°' : ''}</span>
        </div>
      </div>
      <div class="comp-label">${d.city}</div>
    </div>`;
  }
  html += `</div>`;
  html += `<div class="chart-legend">
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.tempHigh}"></div>最高</div>
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.tempLow}"></div>最低</div>
  </div>`;
  html += `</div>`;

  // Precipitation comparison
  html += `<div class="chart-box">`;
  html += `<div class="chart-title">各都市の降水確率比較 (%)</div>`;
  html += `<div class="comparison-chart">`;
  for (const d of cityData) {
    const h = d.precipitation != null ? Math.max(5, d.precipitation * 1.5) : 0;
    const color = d.precipitation != null && d.precipitation >= 50 ? COLORS.rain :
                  d.precipitation != null && d.precipitation >= 30 ? COLORS.wind : COLORS.green;
    html += `<div class="comp-group">
      <div class="comp-bars">
        <div class="comp-bar" style="height:${h}px; background:${color}; width:36px">
          <span class="bar-val" style="color:${color}">${d.precipitation != null ? d.precipitation + '%' : '-'}</span>
        </div>
      </div>
      <div class="comp-label">${d.city}</div>
    </div>`;
  }
  html += `</div>`;
  html += `<div class="chart-legend">
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.green}"></div>30%未満</div>
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.wind}"></div>30-49%</div>
    <div class="legend-item"><div class="legend-dot" style="background:${COLORS.yellow}"></div>50%以上</div>
  </div>`;
  html += `</div>`;

  html += `</div></div>`;
  return html;
}
</script>
</body>
</html>
"""


# ========== メイン ==========

def main():
    port = 8080
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            pass

    server = HTTPServer(("0.0.0.0", port), WeatherHandler)
    print(f"\n  天気予報比較アプリ 起動中...")
    print(f"  ブラウザで http://localhost:{port} を開いてください")
    print(f"  終了: Ctrl+C\n")

    # ブラウザを自動で開く
    threading.Timer(1.0, lambda: webbrowser.open(f"http://localhost:{port}")).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nサーバーを停止しました。")
        server.server_close()


if __name__ == "__main__":
    main()
