# MyMemoApp

MyMemoApp は、PowerShell を活用して作成した Windows 用 WPF メモ帳アプリです。  
Markdown 形式でメモを編集し、ChatGPT API（ChatGPT-4o mini 想定）を利用してタイトル生成や文章補完などの機能を実装しています。

## 特徴

- **ホーム画面**: メモ一覧の表示、新規作成、編集、削除が可能
- **編集画面**:
  - Markdown 入力とリアルタイムプレビュー
  - ChatGPT API 連携によるタイトル自動生成
  - 空行を利用した前後文脈からの「間埋め」機能
  - 過去メモ参照機能による、参考情報の取り込み

## 必要なもの

- Windows 10/11
- PowerShell 5.1 または PowerShell 7
- [Markdig.dll](https://github.com/lunet-io/markdig)  
  ※ダウンロードした Markdig.dll は本プロジェクトのルートフォルダに配置してください

## インストールと実行方法

1. **プロジェクトフォルダの作成**
    ```powershell
    mkdir MyMemoApp
    cd MyMemoApp
    ```

2. **スクリプトファイルの作成**
    - `MemoApp.ps1` を作成し、プロジェクトのコードを貼り付けます。

    ```powershell
    New-Item -Path . -Name "MemoApp.ps1" -ItemType "File" -Force
    ```
    ※コード内容は [MemoApp.ps1 のサンプルコード](./MemoApp.ps1) を参照してください。

3. **Markdig.dll の配置**
    - ダウンロード済みの Markdig.dll をプロジェクトフォルダにコピーします。
    ```powershell
    Copy-Item -Path "C:\Downloads\Markdig.dll" -Destination .\
    ```

4. **実行ポリシーの設定（初回または毎回必要な場合）**
    ```powershell
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
    ```

5. **スクリプトの実行**
    ```powershell
    .\MemoApp.ps1
    ```

## 重要: エンコーディングについて

このプロジェクトでは、特殊文字（改行コードやバックティックなど）が正しく認識されるように、**すべてのスクリプトファイルを「UTF-8 with BOM」で保存する必要があります**。

### Visual Studio Code を利用している場合

1. **ファイルを開く**  
   対象の `MemoApp.ps1` を VSCode で開きます。

2. **エンコーディングの確認**  
   エディタウィンドウの右下に現在のエンコーディングが表示されます。  
   ※例: 「UTF-8」または「UTF-8 with BOM」

3. **エンコーディングの変更**
   - 右下のエンコーディング表示部分をクリックし、「Reopen with Encoding」を選択します。
   - 表示されるリストから **「UTF-8 with BOM」** を選択してください。

4. **保存**  
   エンコーディングを変更して再オープンした後、`Ctrl+S` で保存します。

> ※ この手順を必ず実施してください。  
> UTF-8 with BOM で保存しないと、バックティック (`) や改行コードが正しく認識されず、実行時にエラーが発生する可能性があります。

## トラブルシューティング

- **「UTF-8 with BOM」が選択肢にない場合**  
  VSCode のバージョンが最新であるか確認し、コマンドパレット（`Ctrl+Shift+P`）から「Change File Encoding」コマンドを使用してください。また、settings.json の設定が原因の場合もあるため、必要に応じて設定を見直してください。

---

以上の手順に従って、正しい環境でアプリを実行してください。  
この README を参考に、UTF-8 with BOM での保存を必ず確認することで、エンコーディングに関するミスを防ぐことができます。
