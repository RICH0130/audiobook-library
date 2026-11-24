# 有聲書圖書館（Audiobook Library）

把 EPUB 電子書變成可以「邊聽邊讀」的逐字稿，搭配筆記、AI 關鍵字和 ADHD 重點模式。Flutter 開發，支援 iOS 與 Android。

## 功能（MVP）

| 功能 | 說明 |
| --- | --- |
| 匯入 EPUB | 解析目錄與章節，HTML 轉成乾淨的逐句逐字稿（不支援 DRM 加密書） |
| 朗讀 | 手機內建語音引擎，免費可離線；唸到哪句就高亮哪句，正在唸的字加底線，自動捲動 |
| 播放控制 | 播放／暫停、上一句／下一句、上一章／下一章、語速、章節唸完自動接下一章 |
| 閱讀互動 | 點一下句子跳到那句；長按句子可畫重點（4 色）、寫筆記、從這句開始朗讀、複製 |
| 筆記 | 依章節整理所有重點與筆記，點一下跳回原文；左滑刪除 |
| AI 關鍵字 | Claude 從每章挑出 5 到 10 個關鍵詞，在內文中以粗體顏色標示 |
| ADHD 重點模式 | 每章一句話總結 + 3 到 5 個重點卡片；閱讀頁的閃電按鈕可切換「只看重點句」快讀 |
| PDF 匯出 | 重點、關鍵字、你的筆記一起輸出成 PDF，透過系統分享存檔或傳送 |
| 進度保存 | 自動記住每本書讀到第幾章第幾句 |

所有資料（書、筆記、AI 重點）只存在手機上的 SQLite。資料表已預留 `uid` / `updated_at` 欄位，供第二階段雲端同步與分享使用。

## 開始使用

```bash
flutter pub get
flutter run            # 接上手機或開模擬器
flutter test           # 單元測試（文字切句、HTML 轉文字、PDF 產生）
```

需求：Flutter 3.50 以上。iOS 需在 Xcode 設定簽章；Android minSdk 依 Flutter 預設。

### AI 重點設定

1. 到 [console.anthropic.com](https://console.anthropic.com) 申請 API 金鑰
2. App 內「設定」頁貼上金鑰（只存在手機上）
3. 進入書本，點右上角星星圖示進入 ADHD 重點模式，按「整理全書」

使用模型 `claude-opus-5-5`（effort `low`，結構化 JSON 輸出）。長章節會自動分段分析後合併。

### PDF 中文字型

第一次匯出 PDF 時會下載 Noto Sans TC（約 12 MB，SIL Open Font License）並快取在 App 內，之後可離線匯出。

## 專案結構

```
lib/
  main.dart
  models/models.dart            Book / Chapter / Note / ChapterInsight
  services/
    database.dart               SQLite 存取
    epub_importer.dart          EPUB 解析（依 spine 順序）
    text_utils.dart             HTML 轉文字、中英文切句
    tts_player.dart             逐句朗讀與同步高亮
    claude_service.dart         Claude API（關鍵字、重點）
    pdf_exporter.dart           PDF 產生與分享
    settings.dart               使用者設定
  screens/
    library_screen.dart         書架
    reader_screen.dart          逐字稿閱讀 + 播放器
    notes_screen.dart           筆記列表
    adhd_screen.dart            ADHD 重點 + PDF 匯出
    settings_screen.dart        設定
  widgets/sentence_text.dart    單句渲染（關鍵字、朗讀位置、重點色）
```

## 第二階段規劃

- 帳號登入與雲端同步（例如 Supabase）
- 唯讀分享連結：預設只分享書單、筆記與 ADHD 重點；標記為公版書或自有作品的書才分享全文
