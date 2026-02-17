#!/usr/bin/env python3
"""
天気予報アグリゲーター
複数の天気予報サービスから明日の天気予報を取得し、一覧表示するプログラム。

使用するAPI（すべて無料・APIキー不要）:
  1. Open-Meteo   - オープンソースの天気予報API
  2. wttr.in      - コンソール向け天気予報サービス
  3. 気象庁 (JMA) - 日本の気象庁の公開API
"""

import json
import urllib.request
import urllib.error
from datetime import datetime, timedelta
from typing import Optional


# ========== データクラス ==========

class ForecastResult:
    """天気予報の取得結果を保持するクラス"""

    def __init__(
        self,
        source: str,
        location: str,
        date: str,
        weather: str,
        temp_max: Optional[float] = None,
        temp_min: Optional[float] = None,
        precipitation_prob: Optional[float] = None,
        humidity: Optional[float] = None,
        wind_speed: Optional[float] = None,
        error: Optional[str] = None,
    ):
        self.source = source
        self.location = location
        self.date = date
        self.weather = weather
        self.temp_max = temp_max
        self.temp_min = temp_min
        self.precipitation_prob = precipitation_prob
        self.humidity = humidity
        self.wind_speed = wind_speed
        self.error = error


# ========== API取得関数 ==========

def fetch_json(url: str, timeout: int = 10) -> dict:
    """URLからJSONを取得する共通関数"""
    req = urllib.request.Request(url, headers={"User-Agent": "WeatherAggregator/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))


def fetch_open_meteo(lat: float, lon: float, location_name: str) -> ForecastResult:
    """
    Open-Meteo API から明日の天気予報を取得
    https://open-meteo.com/
    """
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    source = "Open-Meteo"

    try:
        url = (
            f"https://api.open-meteo.com/v1/forecast"
            f"?latitude={lat}&longitude={lon}"
            f"&daily=weather_code,temperature_2m_max,temperature_2m_min,"
            f"precipitation_probability_max,wind_speed_10m_max"
            f"&timezone=Asia%2FTokyo"
            f"&start_date={tomorrow}&end_date={tomorrow}"
        )
        data = fetch_json(url)
        daily = data["daily"]

        weather_code = daily["weather_code"][0]
        weather_text = _wmo_weather_code_to_text(weather_code)

        return ForecastResult(
            source=source,
            location=location_name,
            date=tomorrow,
            weather=weather_text,
            temp_max=daily["temperature_2m_max"][0],
            temp_min=daily["temperature_2m_min"][0],
            precipitation_prob=daily["precipitation_probability_max"][0],
            wind_speed=daily["wind_speed_10m_max"][0],
        )
    except Exception as e:
        return ForecastResult(
            source=source, location=location_name, date=tomorrow,
            weather="取得失敗", error=str(e),
        )


def fetch_wttr_in(location: str) -> ForecastResult:
    """
    wttr.in API から明日の天気予報を取得
    https://wttr.in/:help
    """
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    source = "wttr.in"

    try:
        url = f"https://wttr.in/{location}?format=j1"
        data = fetch_json(url)

        # weather配列の[1]が明日の天気
        if len(data.get("weather", [])) < 2:
            return ForecastResult(
                source=source, location=location, date=tomorrow,
                weather="取得失敗", error="明日のデータが見つかりません",
            )

        tomorrow_data = data["weather"][1]
        hourly = tomorrow_data.get("hourly", [])

        # 日中（12時）のデータを取得
        midday = hourly[len(hourly) // 2] if hourly else {}

        # 天気の説明を取得
        weather_desc = ""
        if midday.get("lang_ja"):
            weather_desc = midday["lang_ja"][0].get("value", "")
        if not weather_desc:
            weather_desc = midday.get("weatherDesc", [{}])[0].get("value", "不明")

        return ForecastResult(
            source=source,
            location=location,
            date=tomorrow_data.get("date", tomorrow),
            weather=weather_desc,
            temp_max=_safe_float(tomorrow_data.get("maxtempC")),
            temp_min=_safe_float(tomorrow_data.get("mintempC")),
            precipitation_prob=_safe_float(midday.get("chanceofrain")),
            humidity=_safe_float(midday.get("humidity")),
            wind_speed=_safe_float(midday.get("windspeedKmph")),
        )
    except Exception as e:
        return ForecastResult(
            source=source, location=location, date=tomorrow,
            weather="取得失敗", error=str(e),
        )


def fetch_jma(area_code: str, location_name: str) -> ForecastResult:
    """
    気象庁 (JMA) API から天気予報を取得
    https://www.jma.go.jp/bosai/forecast/
    """
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
    source = "気象庁 (JMA)"

    try:
        url = f"https://www.jma.go.jp/bosai/forecast/data/forecast/{area_code}.json"
        data = fetch_json(url)

        # 3日間予報（最初の要素）からデータを取得
        forecast = data[0]
        time_series = forecast["timeSeries"]

        # 天気情報（timeSeries[0]）
        weather_ts = time_series[0]
        weather_areas = weather_ts["areas"]
        weather_area = weather_areas[0]

        time_defines = weather_ts["timeDefines"]
        tomorrow_str = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

        weather_text = "不明"
        weather_idx = -1
        for i, td in enumerate(time_defines):
            if td.startswith(tomorrow_str):
                weather_idx = i
                break

        if weather_idx >= 0:
            weathers = weather_area.get("weathers", [])
            if weather_idx < len(weathers):
                weather_text = weathers[weather_idx]

        # 降水確率（timeSeries[1]）
        precip_prob = None
        if len(time_series) > 1:
            pop_ts = time_series[1]
            pop_areas = pop_ts["areas"]
            pop_area = pop_areas[0]
            pop_time_defines = pop_ts["timeDefines"]
            pops = pop_area.get("pops", [])

            tomorrow_pops = []
            for i, td in enumerate(time_defines if len(pop_time_defines) == 0 else pop_time_defines):
                if td.startswith(tomorrow_str) and i < len(pops):
                    val = _safe_float(pops[i])
                    if val is not None:
                        tomorrow_pops.append(val)

            if tomorrow_pops:
                precip_prob = max(tomorrow_pops)

        # 気温（timeSeries[2]）
        temp_max = None
        temp_min = None
        if len(time_series) > 2:
            temp_ts = time_series[2]
            temp_areas = temp_ts["areas"]
            temp_area = temp_areas[0]
            temp_time_defines = temp_ts["timeDefines"]
            temps_min_list = temp_area.get("tempsMin", [])
            temps_max_list = temp_area.get("tempsMax", [])

            for i, td in enumerate(temp_time_defines):
                if td.startswith(tomorrow_str):
                    if i < len(temps_min_list):
                        temp_min = _safe_float(temps_min_list[i])
                    if i < len(temps_max_list):
                        temp_max = _safe_float(temps_max_list[i])
                    break

        return ForecastResult(
            source=source,
            location=location_name,
            date=tomorrow,
            weather=weather_text,
            temp_max=temp_max,
            temp_min=temp_min,
            precipitation_prob=precip_prob,
        )
    except Exception as e:
        return ForecastResult(
            source=source, location=location_name, date=tomorrow,
            weather="取得失敗", error=str(e),
        )


# ========== ユーティリティ ==========

def _safe_float(value) -> Optional[float]:
    """安全にfloatに変換する"""
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


def _wmo_weather_code_to_text(code: int) -> str:
    """WMO天気コードを日本語テキストに変換"""
    wmo_codes = {
        0: "快晴",
        1: "晴れ",
        2: "一部曇り",
        3: "曇り",
        45: "霧",
        48: "着氷性の霧",
        51: "弱い霧雨",
        53: "霧雨",
        55: "強い霧雨",
        56: "弱い着氷性の霧雨",
        57: "強い着氷性の霧雨",
        61: "弱い雨",
        63: "雨",
        65: "強い雨",
        66: "弱い着氷性の雨",
        67: "強い着氷性の雨",
        71: "弱い雪",
        73: "雪",
        75: "強い雪",
        77: "霧雪",
        80: "弱いにわか雨",
        81: "にわか雨",
        82: "激しいにわか雨",
        85: "弱いにわか雪",
        86: "強いにわか雪",
        95: "雷雨",
        96: "雹を伴う雷雨",
        99: "激しい雹を伴う雷雨",
    }
    return wmo_codes.get(code, f"不明(コード:{code})")


def _fmt(value, unit: str = "", width: int = 0) -> str:
    """値をフォーマットする。Noneの場合は '-' を返す"""
    if value is None:
        text = "-"
    elif isinstance(value, float):
        text = f"{value:.1f}{unit}"
    else:
        text = f"{value}{unit}"
    return text.rjust(width) if width else text


# ========== 表示関数 ==========

def display_results(results: list[ForecastResult]) -> None:
    """天気予報の結果を一覧表示する"""
    tomorrow = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")

    print()
    print("=" * 78)
    print(f"  明日 ({tomorrow}) の天気予報 - 各社比較")
    print("=" * 78)

    for r in results:
        print()
        if r.error:
            print(f"  【{r.source}】 ({r.location})")
            print(f"    ⚠ 取得エラー: {r.error}")
            continue

        print(f"  【{r.source}】 ({r.location})")
        print(f"    天気:       {r.weather}")
        print(f"    最高気温:   {_fmt(r.temp_max, '°C')}")
        print(f"    最低気温:   {_fmt(r.temp_min, '°C')}")
        print(f"    降水確率:   {_fmt(r.precipitation_prob, '%')}")
        if r.humidity is not None:
            print(f"    湿度:       {_fmt(r.humidity, '%')}")
        if r.wind_speed is not None:
            print(f"    風速:       {_fmt(r.wind_speed, 'km/h')}")

    # 比較表
    valid = [r for r in results if not r.error]
    if len(valid) >= 2:
        print()
        print("-" * 78)
        print("  【比較サマリー】")
        print("-" * 78)

        col_w = 20
        src_header = "".join(r.source[:col_w].ljust(col_w) for r in valid)
        print(f"  {'項目':<12}{src_header}")
        print(f"  {'─' * 12}{'─' * col_w * len(valid)}")

        row_weather = "".join(
            (r.weather[:col_w - 1]).ljust(col_w) for r in valid
        )
        print(f"  {'天気':<12}{row_weather}")

        row_max = "".join(_fmt(r.temp_max, "°C").ljust(col_w) for r in valid)
        print(f"  {'最高気温':<10}{row_max}")

        row_min = "".join(_fmt(r.temp_min, "°C").ljust(col_w) for r in valid)
        print(f"  {'最低気温':<10}{row_min}")

        row_pop = "".join(
            _fmt(r.precipitation_prob, "%").ljust(col_w) for r in valid
        )
        print(f"  {'降水確率':<10}{row_pop}")

    print()
    print("=" * 78)
    print()


# ========== 地域設定 ==========

# 主要都市の設定
LOCATIONS = {
    "東京": {
        "lat": 35.6762,
        "lon": 139.6503,
        "wttr_query": "Tokyo",
        "jma_area_code": "130000",  # 東京都
    },
    "大阪": {
        "lat": 34.6937,
        "lon": 135.5023,
        "wttr_query": "Osaka",
        "jma_area_code": "270000",  # 大阪府
    },
    "名古屋": {
        "lat": 35.1815,
        "lon": 136.9066,
        "wttr_query": "Nagoya",
        "jma_area_code": "230000",  # 愛知県
    },
}


# ========== メイン ==========

def get_forecasts(city: str = "東京") -> list[ForecastResult]:
    """指定した都市の天気予報を各サービスから取得する"""
    loc = LOCATIONS.get(city)
    if loc is None:
        print(f"エラー: '{city}' は未対応の都市です。")
        print(f"対応都市: {', '.join(LOCATIONS.keys())}")
        return []

    print(f"\n'{city}' の明日の天気予報を取得中...")

    results = []

    print("  [1/3] Open-Meteo から取得中...")
    results.append(fetch_open_meteo(loc["lat"], loc["lon"], city))

    print("  [2/3] wttr.in から取得中...")
    results.append(fetch_wttr_in(loc["wttr_query"]))

    print("  [3/3] 気象庁 (JMA) から取得中...")
    results.append(fetch_jma(loc["jma_area_code"], city))

    return results


def main():
    """メインエントリポイント"""
    import sys

    # コマンドライン引数で都市を指定可能
    if len(sys.argv) > 1:
        city = sys.argv[1]
    else:
        city = "東京"

    # 全都市モード: "all" を指定すると全都市の天気を取得
    if city == "all":
        for city_name in LOCATIONS:
            results = get_forecasts(city_name)
            if results:
                display_results(results)
    else:
        results = get_forecasts(city)
        if results:
            display_results(results)


if __name__ == "__main__":
    main()
