# 股票庫存管理 App

個人使用的美股庫存管理 App，定位介於「記帳軟體」與「投資組合追蹤器」之間。
匯入券商交易紀錄（或手動記帳）後，自動計算持倉、抓取即時報價，並以圖表呈現資產狀況。

以 Flutter 開發，單一程式碼庫支援 macOS / Windows / Linux / iOS / Android。
完全免費：不需要申請任何 API Key，開啟即用。

## 功能

### 記帳
- **CSV 匯入**：支援 Yahoo Finance 匯出格式的逐筆交易紀錄，自動去重——同一份檔案重複匯入不會產生重複交易
- **手動記帳**：輸入代號或公司名稱即時搜尋（美股、台股皆可），選定後自動帶入現價，買/賣、股數（支援碎股）、日期（預設今天）

### 持倉計算
- 成本採**加權平均法**：賣出時以當下平均成本認列已實現損益
- 自動計算每檔的淨持股、平均成本、未實現與已實現損益
- 已清倉的股票獨立顯示已實現損益

### 即時報價
- Yahoo Finance 非官方端點（免 API Key），涵蓋**盤前／盤中／盤後**三種價格
- 依美東時段自動調整背景更新頻率：盤中 45 秒、盤前盤後 3 分鐘、休市停止
- 報價快取於本地，離線時顯示「最後更新於 X 分鐘前」
- 被限流（429）時指數退避並自動切換備援端點，不會讓 App 崩潰

### 圖表
- **資產曲線**：總市值＋總成本雙線，由交易紀錄與歷史股價逐日重建完整歷史
- **時間範圍**：1月／3月／6月／YTD／1年／2年／全部，並顯示**期間損益**（已扣除期間新投入的本金，加碼不會被誤算成獲利）
- **大盤比較**：可疊加 S&P 500、那斯達克、台灣加權指數，自動切換為報酬率%模式（時間加權法 TWR，起點歸零公平比較）
- **雙圓餅圖**：市值配置 vs 成本配置，對照漲跌造成的配置變化
- **漲跌配色切換**：美股慣例（漲綠跌紅）／台股慣例（漲紅跌綠）

## 建置與執行

需要 [Flutter SDK](https://docs.flutter.dev/get-started/install)（3.44 以上）。

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 產生 drift 資料庫程式碼
flutter run -d macos        # 或 windows / linux
```

### 測試

```bash
flutter test        # 73 個單元與 widget 測試
flutter analyze
```

另有手動驗證工具：

```bash
dart run tool/quote_probe.dart    # 驗證 Yahoo 報價端點在目前網路環境可用
```

## 專案結構

```
lib/
├── models/      # 純資料類別（交易、持倉、報價、快照）
├── database/    # drift + SQLite（交易紀錄、報價快取、歷史股價）
├── services/    # CSV 解析、Yahoo 報價、代號搜尋、時段判斷、背景輪詢
├── logic/       # 持倉計算引擎與 Repository（UI 唯一的資料入口）
└── ui/          # 儀表板畫面與圖表元件（fl_chart）
```

UI 與底層完全分離：畫面只透過 `PortfolioRepository` 取得資料，
改介面不會動到計算邏輯，底層正確性由單元測試保證。

## CSV 格式

欄位順序固定的 Yahoo Finance 匯出格式，App 只解析交易必要欄位
（`Symbol`、`Trade Date`、`Purchase Price`、`Quantity`、`Transaction Type`），
其餘報價快照欄位自動忽略：

```csv
Symbol,Current Price,Date,Time,Change,Open,High,Low,Volume,Trade Date,Purchase Price,Quantity,Commission,High Limit,Low Limit,Comment,Transaction Type
NVDA,210.96,2026/07/10,16:00 EDT,8.18,201.92,211.0,201.92,147203662,20260707,194.478914,0.77129,,,,,BUY
```

## 資料儲存

所有資料存在本地 SQLite，沒有雲端後端：

- macOS：`~/Library/Containers/com.wythe.stockPortfolioApp/Data/Documents/stock_portfolio.sqlite`
- 交易紀錄、報價快取、歷史股價都在同一個檔案，備份它就是備份全部

## 注意事項

- 報價來自 Yahoo Finance 非官方端點，有數秒延遲，App 內會標示目前時段與更新時間
- 期間損益與大盤比較採時間加權報酬率（TWR），與持倉列表的未實現損益（成本觀點）本來就會不同
- 本 App 僅供個人記帳參考，不構成投資建議
