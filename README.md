# 股票庫存管理 App

免費、開源的個人美股庫存管理 App，定位介於「記帳軟體」與「投資組合追蹤器」之間。
匯入券商交易紀錄（或手動記帳）後，自動計算持倉、抓取即時報價，並以圖表呈現資產狀況。

以 Flutter 開發，單一程式碼庫支援 macOS / Windows / Linux / iOS / Android / **網頁版**。
**不需要申請任何 API Key、沒有訂閱費、資料全部存在你自己的裝置上。**

🌐 **線上版（免安裝）**：https://stock-portfolio-3ba.pages.dev
（資料存在瀏覽器本機儲存空間，報價經由 Cloudflare Worker 代理轉發）

## 功能

### 記帳
- **CSV 匯入**：支援 Yahoo Finance 匯出格式的逐筆交易紀錄，自動去重——同一份檔案重複匯入不會產生重複交易
- **手動記帳**：輸入代號或公司名稱即時搜尋（美股、台股皆可），選定後自動帶入現價，買/賣、股數（支援碎股）、日期（預設今天）

### 追蹤清單與個股詳情
- **自選股追蹤**：不需持有也能加入追蹤，清單顯示現價與今日漲跌
- **個股詳情頁**：日K／週K／月K 蠟燭圖＋成交量、開高低收、52 週高低、市值、本益比；持有的股票會顯示持倉摘要並在 K 線上標出你的平均成本線

### 持倉與損益
- 成本採**加權平均法**：賣出時以當下平均成本認列已實現損益
- **今日損益**：每檔與整體組合的當日漲跌金額與 %
- **股息追蹤**（預設關閉，設定中開啟）：自動抓取歷史配息，依除息日當時持股計算累計股息收入。若你的券商有開股息再投資（DRIP），股息已以碎股買入出現在交易紀錄中，請保持關閉以免重複計算
- **XIRR 年化報酬率**：資金加權、含股息，反映你的錢實際成長速度
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

### 雲端同步（選用）
- **Google Drive 同步**：用自己的 Google 帳號登入後，資料自動同步到你 Drive 的 App 專屬隱藏空間（`drive.appdata` 最小權限，App 看不到你的其他檔案）
- 多裝置登入同一帳號即雙向合併；刪除透過墓碑機制同步，不會復活
- 開發者需在 Google Cloud Console 建立免費的 iOS OAuth Client ID 並填入
  `lib/services/google_drive_sync_service.dart` 與兩個 Info.plist

### 外觀
- **背景深淺切換**：淺色／深色／跟隨系統，設定會記住
- **漲跌配色切換**：美股慣例（漲綠跌紅）／台股慣例（漲紅跌綠）

---

## 安裝教學

### 方法一：直接下載安裝檔（推薦）

到 [Releases 頁面](https://github.com/wythe5774133/stock_portfolio_app/releases) 下載對應平台的檔案：

| 平台 | 檔案 | 安裝方式 |
|---|---|---|
| macOS | `StockPortfolio-macOS-*.zip` | 解壓縮後把 App 拖進「應用程式」。第一次開啟請對 App **按右鍵 → 打開**（未經 Apple 公證會有警告）；若仍無法開啟，終端機執行 `xattr -cr /Applications/stock_portfolio_app.app` |
| Windows | `StockPortfolio-Windows-*.zip` | 解壓縮到任意資料夾，執行 `stock_portfolio_app.exe`（SmartScreen 警告點「其他資訊 → 仍要執行」） |
| Linux | `StockPortfolio-Linux-*.tar.gz` | 解壓縮後執行 `bundle/stock_portfolio_app` |
| Android | `StockPortfolio-Android-*.apk` | 傳到手機點開安裝，需允許「安裝未知的應用程式」 |
| iOS | 無安裝檔 | Apple 簽章限制，請用下方「從原始碼建置」側載 |

### 方法二：從原始碼建置

共同步驟：

### 步驟 0：安裝 Flutter SDK（所有平台都要）

依照官方指南安裝 Flutter 3.44 以上版本：https://docs.flutter.dev/get-started/install
安裝後在終端機確認：

```bash
flutter doctor
```

### 步驟 1：取得原始碼並準備依賴（所有平台都要）

```bash
git clone https://github.com/wythe5774133/stock_portfolio_app.git
cd stock_portfolio_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### macOS

需求：macOS 10.15 以上、已安裝 Xcode（App Store 免費下載）並接受授權：

```bash
sudo xcodebuild -license accept
flutter build macos --release
```

建置完成後，App 在 `build/macos/Build/Products/Release/stock_portfolio_app.app`。
把它拖進「應用程式」資料夾即可日常使用：

```bash
cp -r build/macos/Build/Products/Release/stock_portfolio_app.app /Applications/
```

### Windows

需求：Windows 10 以上、[Visual Studio](https://visualstudio.microsoft.com/downloads/)（Community 版免費）並勾選「使用 C++ 的桌面開發」工作負載。

```powershell
flutter build windows --release
```

建置完成後，整個 `build\windows\x64\runner\Release\` 資料夾就是可攜式程式，
複製到任何位置（例如 `C:\Program Files\StockPortfolio\`），執行裡面的
`stock_portfolio_app.exe`。可以對它按右鍵→釘選到開始畫面。

### Linux

需求：先安裝桌面建置依賴（以 Ubuntu/Debian 為例）：

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter build linux --release
```

執行檔在 `build/linux/x64/release/bundle/stock_portfolio_app`，
整個 `bundle/` 資料夾可以搬到任何位置執行。

### Android

需求：安裝 [Android Studio](https://developer.android.com/studio)（含 Android SDK）。

```bash
flutter build apk --release
```

產出的安裝檔在 `build/app/outputs/flutter-apk/app-release.apk`。
把它傳到手機（AirDrop、雲端硬碟、USB 都可以）點開安裝，
第一次安裝需要在手機設定中允許「安裝未知的應用程式」。

### iOS / iPad

需求：一台 Mac＋Xcode，用免費 Apple ID 即可側載（不用付開發者年費）：

1. `open ios/Runner.xcworkspace` 開啟 Xcode
2. 在 Signing & Capabilities 分頁選擇你的 Apple ID 作為 Team，
   Bundle Identifier 改成任意唯一字串（例如 `com.yourname.stockportfolio`）
3. iPhone 接上 Mac，執行 `flutter run --release -d <裝置>`
4. 手機上到「設定 → 一般 → VPN 與裝置管理」信任你的開發者憑證

注意：免費 Apple ID 簽署的 App 每 7 天需重新安裝一次；付費開發者帳號則為一年。

---

## 開發

```bash
flutter test        # 83 個單元與 widget 測試
flutter analyze     # 靜態分析
dart run tool/quote_probe.dart    # 驗證 Yahoo 報價端點在目前網路環境可用
```

### 專案結構

```
lib/
├── models/      # 純資料類別（交易、持倉、報價、快照、配息）
├── database/    # drift + SQLite（交易紀錄、報價快取、歷史股價、配息事件）
├── services/    # CSV 解析、Yahoo 報價、代號搜尋、配息、時段判斷、背景輪詢
├── logic/       # 持倉計算引擎（加權平均、TWR、XIRR）與 Repository
└── ui/          # 儀表板畫面與圖表元件（fl_chart）、深淺主題
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
- Windows：`%USERPROFILE%\Documents\stock_portfolio.sqlite`
- 交易紀錄、報價快取、歷史股價、配息事件都在同一個檔案，備份它就是備份全部

## 注意事項

- 報價來自 Yahoo Finance 非官方端點，有數秒延遲，App 內會標示目前時段與更新時間
- 期間損益與大盤比較採時間加權報酬率（TWR）、統計卡的 XIRR 為資金加權年化，
  兩者與持倉列表的未實現損益（成本觀點）角度不同，數字本來就會不一樣
- 本 App 僅供個人記帳參考，不構成投資建議

## 授權

[MIT License](LICENSE) — 自由使用、修改、散布。
