# Windows + Docker で CLine46 ファームウェアをビルドする方法

このドキュメントは、Windows 上で Docker Desktop を使い、このリポジトリの ZMK ファームウェアをローカルビルドするための手順です。

推奨環境は **WSL2 + Docker Desktop** です。既存の [scripts/build-firmware.sh](../scripts/build-firmware.sh) をそのまま使えるため、macOS とほぼ同じ操作でビルドできます。

## 前提

- Windows 10 / 11
- WSL2 が有効になっていること
- Ubuntu などの WSL Linux ディストリビューションがインストールされていること
- Docker Desktop がインストールされ、起動していること
- Docker Desktop の WSL integration が有効になっていること
- このリポジトリを WSL 側に clone 済みであること

リポジトリは、できるだけ WSL の Linux ファイルシステム側に置いてください。

推奨:

```text
~/zmk_config_CLine46
```

非推奨:

```text
/mnt/c/Users/...
```

`/mnt/c` 配下でも動く場合はありますが、ビルド時のファイルアクセスが遅くなりやすいです。

## Docker Desktop の確認

PowerShell または WSL で Docker が使えるか確認します。

```sh
docker info
```

WSL 側で `docker info` が成功すれば準備完了です。

失敗する場合は、Docker Desktop の設定で次を確認してください。

- `Settings` > `General` > `Use the WSL 2 based engine`
- `Settings` > `Resources` > `WSL integration`
- 使用している Ubuntu などのディストリビューションが有効になっていること

## リポジトリへ移動する

WSL のターミナルで実行します。

```sh
cd ~/zmk_config_CLine46
```

## 自動ビルドする

通常は、次のスクリプトを実行するだけでビルドできます。

```sh
./scripts/build-firmware.sh
```

このスクリプトは Docker コンテナを起動し、次の処理をまとめて実行します。

- `west init -l config`
- `west update`
- `west zephyr-export`
- 右手側 `CLine46_R rgbled_adapter` のビルド
- 左手側 `CLine46_L rgbled_adapter` のビルド
- `settings_reset` のビルド
- 生成された `.uf2` の `firmware/local` へのコピー

生成物:

```text
firmware/local/CLine46_R-rgbled_adapter-seeeduino_xiao_ble-zmk.uf2
firmware/local/CLine46_L-rgbled_adapter-seeeduino_xiao_ble-zmk.uf2
firmware/local/settings_reset-seeeduino_xiao_ble-zmk.uf2
```

## 2回目以降のビルド

2回目以降も同じコマンドでビルドできます。

```sh
./scripts/build-firmware.sh
```

キーマップ変更だけを素早くビルドしたい場合は、依存リポジトリの更新を省略できます。

```sh
./scripts/build-firmware.sh --skip-update
```

完全に作り直したい場合は、クリーンビルドします。

```sh
./scripts/build-firmware.sh --clean
```

日付別のディレクトリに UF2 を出力する場合:

```sh
./scripts/build-firmware.sh --output firmware/$(date +%Y%m%d)
```

## 手動で Docker コンテナを起動する場合

トラブルシュートや個別ビルドをしたい場合は、WSL のターミナルで次を実行します。

```sh
docker run --rm -it \
  -v "$PWD:/workspaces/zmk-config" \
  -w /workspaces/zmk-config \
  zmkfirmware/zmk-build-arm:stable \
  bash
```

以降のコマンドは、起動した Docker コンテナ内で実行します。

初回:

```sh
west init -l config
west update
west zephyr-export
```

右手側:

```sh
west build -d build/CLine46_R \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -S studio-rpc-usb-uart \
  -- \
  -DBOARD_ROOT=/workspaces/zmk-config \
  -DZMK_CONFIG=/workspaces/zmk-config/config \
  -DSHIELD="CLine46_R rgbled_adapter"
```

左手側:

```sh
west build -d build/CLine46_L \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -- \
  -DBOARD_ROOT=/workspaces/zmk-config \
  -DZMK_CONFIG=/workspaces/zmk-config/config \
  -DSHIELD="CLine46_L rgbled_adapter"
```

settings_reset:

```sh
west build -d build/settings_reset \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -- \
  -DBOARD_ROOT=/workspaces/zmk-config \
  -DZMK_CONFIG=/workspaces/zmk-config/config \
  -DSHIELD="settings_reset"
```

## PowerShell から直接 Docker を使う場合

WSLを使わず、PowerShellから直接コンテナを起動する場合は、リポジトリルートで次を実行します。

```powershell
docker run --rm -it `
  -v "${PWD}:/workspaces/zmk-config" `
  -w /workspaces/zmk-config `
  zmkfirmware/zmk-build-arm:stable `
  bash
```

ただし、この方法では [scripts/build-firmware.sh](../scripts/build-firmware.sh) を Windows 側から直接実行できません。自動ビルドを使う場合は、WSL のターミナルから実行してください。

## 実機への書き込み

XIAO BLE をブートローダーモードにすると、Windows に USB ドライブとして表示されます。

通常は次の順で `.uf2` ファイルを書き込みます。

1. 必要に応じて `settings_reset` を左右へ書き込む
2. 右手側へ `CLine46_R` の UF2 を書き込む
3. 左手側へ `CLine46_L` の UF2 を書き込む

WSL 側に生成した UF2 は、エクスプローラーから次の形式で開けます。

```text
\\wsl$\Ubuntu\home\<ユーザー名>\zmk_config_CLine46\firmware\local
```

`Ubuntu` の部分は、使用している WSL ディストリビューション名に合わせて読み替えてください。

## よくある確認ポイント

### WSL で `docker info` が失敗する

Docker Desktop が起動しているか、WSL integration が有効か確認してください。

### `./scripts/build-firmware.sh` が実行できない

実行権限を付け直してください。

```sh
chmod +x scripts/build-firmware.sh
```

### `bad interpreter` と表示される

Windows 側で改行コードが CRLF に変わっている可能性があります。WSL 側で clone し直すか、改行コードを LF に戻してください。

```sh
git config core.autocrlf input
```

### `/mnt/c` 配下でビルドが遅い

リポジトリを WSL のホームディレクトリ配下へ移動してください。

```sh
cd ~
git clone <このリポジトリのURL> zmk_config_CLine46
```
