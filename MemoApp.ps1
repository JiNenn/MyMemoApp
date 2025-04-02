# ----------------------------
# MemoApp.ps1
# ----------------------------

# 必要な .NET アセンブリの読み込み
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Markdig.dll の読み込み（スクリプトと同じフォルダに配置している前提）
$markdigPath = Join-Path -Path (Get-Location) -ChildPath "Markdig.dll"
[Reflection.Assembly]::LoadFrom($markdigPath) | Out-Null

# グローバル変数：メモ一覧 (簡易的なメモ管理)
$global:Notes = @()

# API 設定
$global:ChatGPT_ApiUrl = "https://api.example.com/chatgpt4o-mini"   # 仮のURL
$global:ChatGPT_ApiKey = "YOUR_API_KEY_HERE"

# -----------------------------------
# 関数: Markdown を HTML に変換
function Convert-MarkdownToHtml {
    param(
        [string]$Markdown
    )
    if ([string]::IsNullOrWhiteSpace($Markdown)) {
        return "<p>(No Content)</p>"
    }
    # Markdig.Markdown の静的メソッドを呼び出す
    return [Markdig.Markdown]::ToHtml($Markdown)
}

# -----------------------------------
# 関数: ChatGPT API を呼び出してテキスト生成
function Invoke-ChatGPT {
    param(
        [string]$Prompt
    )
    $headers = @{
        "Authorization" = "Bearer $global:ChatGPT_ApiKey"
    }
    $body = @{
        prompt = $Prompt
        max_tokens = 256
    } | ConvertTo-Json

    try {
        $response = Invoke-RestMethod -Uri $global:ChatGPT_ApiUrl -Method Post -Headers $headers -Body $body -ContentType "application/json"
        # 仮に "text" プロパティに生成結果がある前提
        return $response.text
    }
    catch {
        [System.Windows.MessageBox]::Show("ChatGPT API 呼び出しに失敗しました: $($_.Exception.Message)")
        return ""
    }
}

# -----------------------------------
# 関数: ホーム画面 (メインウィンドウ) の XAML 定義
$mainWindowXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="MemoApp" Height="450" Width="800">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition/>
    </Grid.RowDefinitions>
    <StackPanel Orientation="Horizontal" Margin="10">
      <Button Name="btnNew" Content="新規作成" Width="100" Margin="0,0,5,0"/>
      <Button Name="btnEdit" Content="編集" Width="100" Margin="0,0,5,0"/>
      <Button Name="btnDelete" Content="削除" Width="100"/>
    </StackPanel>
    <ListBox Name="lbNotes" Grid.Row="1" Margin="10" DisplayMemberPath="Title"/>
  </Grid>
</Window>
"@

# 関数: 編集画面 (メモ編集ウィンドウ) の XAML 定義
$editWindowXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="メモ編集" Height="600" Width="900">
  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="3*"/>
      <ColumnDefinition Width="2*"/>
    </Grid.ColumnDefinitions>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- タイトルエリア -->
    <StackPanel Orientation="Horizontal" Margin="10" Grid.ColumnSpan="2">
      <Label Content="タイトル:" VerticalAlignment="Center"/>
      <TextBox Name="txtTitle" Width="300" Margin="5,0,0,0"/>
      <Button Name="btnGenerateTitle" Content="タイトル自動生成" Margin="10,0,0,0" Width="150"/>
    </StackPanel>

    <!-- 編集エリア (左: マークダウン入力) -->
    <StackPanel Grid.Row="1" Grid.Column="0" Margin="10">
      <TextBlock Text="Markdown本文" FontWeight="Bold" Margin="0,0,0,5"/>
      <ScrollViewer VerticalScrollBarVisibility="Auto" Height="400">
        <TextBox Name="txtContent" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" Height="400"/>
      </ScrollViewer>
      <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
        <Button Name="btnSelectPast" Content="過去メモ参照" Width="120"/>
        <Button Name="btnFillGap" Content="間を埋める" Width="120" Margin="10,0,0,0"/>
      </StackPanel>
    </StackPanel>

    <!-- プレビューエリア (右) -->
    <StackPanel Grid.Row="1" Grid.Column="1" Margin="10">
      <TextBlock Text="プレビュー" FontWeight="Bold" Margin="0,0,0,5"/>
      <WebBrowser Name="wbPreview" Height="400"/>
    </StackPanel>

    <!-- OK/キャンセル -->
    <StackPanel Orientation="Horizontal" Grid.Row="2" Grid.ColumnSpan="2" HorizontalAlignment="Right" Margin="10">
      <Button Name="btnOk" Content="OK" Width="80" Margin="0,0,5,0"/>
      <Button Name="btnCancel" Content="キャンセル" Width="80"/>
    </StackPanel>
  </Grid>
</Window>
"@

# -----------------------------------
# 関数: 過去メモ参照ウィンドウの XAML 定義
$selectMemoXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="過去メモ参照" Height="400" Width="600">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <ListBox Name="lbPastNotes" Margin="10" DisplayMemberPath="Title"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="10" Grid.Row="1">
      <Button Name="btnSelect" Content="OK" Width="80" Margin="0,0,5,0"/>
      <Button Name="btnCancelSelect" Content="キャンセル" Width="80"/>
    </StackPanel>
  </Grid>
</Window>
"@

# -----------------------------------
# XAML を読み込みウィンドウを作成する関数
function Load-XamlWindow {
    param([string]$Xaml)
    $reader = (New-Object System.Xml.XmlNodeReader ([xml]$Xaml))
    return [Windows.Markup.XamlReader]::Load($reader)
}

# -----------------------------------
# 関数: 編集ウィンドウの処理
function Show-EditWindow {
    param(
        [ref]$Note   # メモ情報 (Hashtable またはオブジェクト)
    )
    $editWindow = Load-XamlWindow -Xaml $editWindowXaml

    # コントロール取得
    $txtTitle = $editWindow.FindName("txtTitle")
    $txtContent = $editWindow.FindName("txtContent")
    $btnGenerateTitle = $editWindow.FindName("btnGenerateTitle")
    $btnSelectPast = $editWindow.FindName("btnSelectPast")
    $btnFillGap = $editWindow.FindName("btnFillGap")
    $btnOk = $editWindow.FindName("btnOk")
    $btnCancel = $editWindow.FindName("btnCancel")
    $wbPreview = $editWindow.FindName("wbPreview")

    # 初期値設定
    $txtTitle.Text = $Note.Value.Title
    $txtContent.Text = $Note.Value.Content

    # プレビュー更新用のスクリプトブロック
    $updatePreview = {
        $html = Convert-MarkdownToHtml -Markdown $txtContent.Text
        # WebBrowser に HTML を表示 (NavigateToString は UI スレッドで実行)
        $wbPreview.NavigateToString($html)
    }
    # イベントハンドラ: テキスト変更時にプレビュー更新
    $txtContent.Add_TextChanged({ $updatePreview.Invoke() })

    # ボタン: タイトル自動生成
    $btnGenerateTitle.Add_Click({
        $prompt = "以下のMarkdown文章から就活向けのタイトルを生成してください：`n`n$($txtContent.Text)"
        $generatedTitle = Invoke-ChatGPT -Prompt $prompt
        if ($generatedTitle -ne "") {
            $txtTitle.Text = $generatedTitle.Trim()
        }
    })

    # ボタン: 過去メモ参照 (SelectMemo ウィンドウを呼び出す)
    $btnSelectPast.Add_Click({
        $selectWindow = Load-XamlWindow -Xaml $selectMemoXaml
        $lbPastNotes = $selectWindow.FindName("lbPastNotes")
        $btnSelect = $selectWindow.FindName("btnSelect")
        $btnCancelSelect = $selectWindow.FindName("btnCancelSelect")

        # 過去メモ一覧を設定
        $lbPastNotes.ItemsSource = $global:Notes

        # イベント: OK ボタン
        $btnSelect.Add_Click({
            if ($lbPastNotes.SelectedItem -ne $null) {
                # 選択されたメモの内容を本文末尾に追加（参考情報として）
                $txtContent.Text += "`n`n<!-- 参考メモ -->`n" + $lbPastNotes.SelectedItem.Content
                $selectWindow.DialogResult = $true
                $selectWindow.Close()
            }
            else {
                [System.Windows.MessageBox]::Show("メモを選択してください。")
            }
        })
        $btnCancelSelect.Add_Click({
            $selectWindow.DialogResult = $false
            $selectWindow.Close()
        })

        $selectWindow.ShowDialog() | Out-Null
    })

    # ボタン: 間埋め機能
    $btnFillGap.Add_Click({
        # シンプルに、最初の空行を探して前後の行を取得
        $lines = $txtContent.Text -split "`n"
        $gapIndex = $null
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ([string]::IsNullOrWhiteSpace($lines[$i])) {
                $gapIndex = $i
                break
            }
        }
        if ($gapIndex -eq $null) {
            [System.Windows.MessageBox]::Show("空行が見つかりませんでした。")
            return
        }
        $before = ""
        $after = ""
        for ($j = $gapIndex - 1; $j -ge 0; $j--) {
            if (-not [string]::IsNullOrWhiteSpace($lines[$j])) {
                $before = $lines[$j]
                break
            }
        }
        for ($k = $gapIndex + 1; $k -lt $lines.Count; $k++) {
            if (-not [string]::IsNullOrWhiteSpace($lines[$k])) {
                $after = $lines[$k]
                break
            }
        }
        $prompt = "前文: $before`n後文: $after`n上記の文脈を参考に、間に挿入すべき文章を生成してください。就活向けのエピソードや具体例を含めること。"
        $generatedText = Invoke-ChatGPT -Prompt $prompt
        if ($generatedText -ne "") {
            $lines[$gapIndex] = $generatedText
            $txtContent.Text = $lines -join "`n"
        }
    })

    # OK/キャンセルボタンのイベント
    $btnOk.Add_Click({
        $Note.Value.Title = $txtTitle.Text
        $Note.Value.Content = $txtContent.Text
        $editWindow.DialogResult = $true
        $editWindow.Close()
    })
    $btnCancel.Add_Click({
        $editWindow.DialogResult = $false
        $editWindow.Close()
    })

    $editWindow.ShowDialog() | Out-Null
}

# -----------------------------------
# メインウィンドウの処理
function Show-MainWindow {
    $mainWindow = Load-XamlWindow -Xaml $mainWindowXaml

    # コントロール取得
    $btnNew = $mainWindow.FindName("btnNew")
    $btnEdit = $mainWindow.FindName("btnEdit")
    $btnDelete = $mainWindow.FindName("btnDelete")
    $lbNotes = $mainWindow.FindName("lbNotes")

    # メモ一覧更新の関数
    function Update-NoteList {
        $lbNotes.ItemsSource = $null
        $lbNotes.ItemsSource = $global:Notes
    }

    # 新規作成ボタン
    $btnNew.Add_Click({
        # 新規メモ（空のオブジェクトを PSCustomObject で作成）
        $newNote = [PSCustomObject]@{
            Title = "新規メモ"
            Content = ""
        }
        $global:Notes += $newNote

        # 編集ウィンドウを開く
        $noteRef = [ref]$newNote
        Show-EditWindow -Note $noteRef
        Update-NoteList
    })

    # 編集ボタン
    $btnEdit.Add_Click({
        if ($lbNotes.SelectedItem -ne $null) {
            $selected = $lbNotes.SelectedItem
            $noteRef = [ref]$selected
            Show-EditWindow -Note $noteRef
            Update-NoteList
        }
        else {
            [System.Windows.MessageBox]::Show("編集するメモを選択してください。")
        }
    })

    # 削除ボタン
    $btnDelete.Add_Click({
        if ($lbNotes.SelectedItem -ne $null) {
            $result = [System.Windows.MessageBox]::Show("本当に削除しますか？", "確認", "YesNo", "Question")
            if ($result -eq "Yes") {
                $global:Notes = $global:Notes | Where-Object { $_ -ne $lbNotes.SelectedItem }
                Update-NoteList
            }
        }
        else {
            [System.Windows.MessageBox]::Show("削除するメモを選択してください。")
        }
    })

    $mainWindow.ShowDialog() | Out-Null
}

# -----------------------------------
# アプリ開始
Show-MainWindow
