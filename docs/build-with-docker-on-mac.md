# macOS + Docker で CLine46 ファームウェアをビルドする方法

このドキュメントは、macOS 上で Docker Desktop または OrbStack を使い、このリポジトリの ZMK ファームウェアをローカルビルドするための手順です。

## 前提

- macOS に Docker Desktop または OrbStack がインストールされていること
- Docker が起動していること
- このリポジトリをローカルに clone 済みであること

```sh
cd /path/to/zmk_config_CLine46
```

以降のコマンドは、リポジトリのルートディレクトリで実行します。

## 自動ビルドする

通常は、次のスクリプトを実行するだけでビルドできます。

```sh
./scripts/build-firmware.sh
```

このスクリプトは macOS 側から実行します。内部で Docker コンテナを起動し、次の処理をまとめて実行します。

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

### オプション

依存リポジトリの更新を省略してビルドする場合:

```sh
./scripts/build-firmware.sh --skip-update
```

クリーンビルドする場合:

```sh
./scripts/build-firmware.sh --clean
```

UF2 の出力先を変える場合:

```sh
./scripts/build-firmware.sh --output firmware/$(date +%Y%m%d)
```

以下は、スクリプトが内部で実行している手動手順です。トラブルシュートや個別ビルドをしたい場合に参照してください。

## Docker コンテナを起動する

ZMK の ARM ビルド用 Docker イメージを使って、現在のリポジトリをコンテナ内の `/workspaces/zmk-config` にマウントします。

```sh
docker run --rm -it \
  -v "$PWD:/workspaces/zmk-config" \
  -w /workspaces/zmk-config \
  zmkfirmware/zmk-build-arm:stable \
  bash
```

以降のコマンドは、起動した Docker コンテナ内で実行します。

## west ワークスペースを初期化する

このリポジトリでは [config/west.yml](../config/west.yml) に ZMK 本体と追加モジュールが定義されています。

初回だけ、次のコマンドで west ワークスペースを初期化します。

```sh
west init -l config
west update
west zephyr-export
```

2回目以降、依存関係を取り直したい場合は次だけで十分です。

```sh
west update
```

## ファームウェアをビルドする

[build.yaml](../build.yaml) では、次の3つをビルド対象にしています。

- `CLine46_R rgbled_adapter`
- `CLine46_L rgbled_adapter`
- `settings_reset`

### 右手側をビルドする

右手側は Central 側で、トラックボールと ZMK Studio / DYA Studio 関連の設定も含みます。

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

生成物:

```sh
build/CLine46_R/zephyr/zmk.uf2
```

### 左手側をビルドする

```sh
west build -d build/CLine46_L \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -- \
  -DBOARD_ROOT=/workspaces/zmk-config \
  -DZMK_CONFIG=/workspaces/zmk-config/config \
  -DSHIELD="CLine46_L rgbled_adapter"
```

生成物:

```sh
build/CLine46_L/zephyr/zmk.uf2
```

### settings_reset をビルドする

Bluetooth ペアリング情報や設定をリセットするための UF2 です。

```sh
west build -d build/settings_reset \
  -s zmk/app \
  -b seeeduino_xiao_ble \
  -- \
  -DBOARD_ROOT=/workspaces/zmk-config \
  -DZMK_CONFIG=/workspaces/zmk-config/config \
  -DSHIELD="settings_reset"
```

生成物:

```sh
build/settings_reset/zephyr/zmk.uf2
```

## 生成した UF2 をわかりやすい名前でコピーする

必要であれば、リポジトリ内の `firmware` ディレクトリへコピーします。

```sh
mkdir -p firmware/local

cp build/CLine46_R/zephyr/zmk.uf2 \
  "firmware/local/CLine46_R-rgbled_adapter-seeeduino_xiao_ble-zmk.uf2"

cp build/CLine46_L/zephyr/zmk.uf2 \
  "firmware/local/CLine46_L-rgbled_adapter-seeeduino_xiao_ble-zmk.uf2"

cp build/settings_reset/zephyr/zmk.uf2 \
  "firmware/local/settings_reset-seeeduino_xiao_ble-zmk.uf2"
```

## ビルドをやり直す

設定を変更して再ビルドする場合は、同じ `west build` コマンドを再実行します。

完全にクリーンビルドしたい場合は、対象の build ディレクトリを消してから実行します。

```sh
rm -rf build/CLine46_R
rm -rf build/CLine46_L
rm -rf build/settings_reset
```

## よくある確認ポイント

### Docker イメージの取得で失敗する

Docker Desktop が起動しているか、ネットワークに接続されているか確認してください。

```sh
docker info
```

### `west update` が失敗する

[config/west.yml](../config/west.yml) で複数の GitHub リポジトリを取得しています。ネットワーク接続、GitHub へのアクセス、プロキシ設定を確認してください。

### shield が見つからない

このリポジトリでは shield 定義が [boards/shields/CLine46](../boards/shields/CLine46) にあります。

`west build` はリポジトリルートで実行してください。コンテナ内では、作業ディレクトリが次になっていることを確認します。

```sh
pwd
```

期待値:

```text
/workspaces/zmk-config
```

### macOS 側で UF2 が見えない

Docker 起動時に `-v "$PWD:/workspaces/zmk-config"` でマウントしているため、コンテナ内で作成した `build` や `firmware/local` は macOS 側の同じリポジトリ内にも表示されます。

## 実機への書き込み

XIAO BLE をブートローダーモードにして、macOS に表示されたドライブへ対象の `.uf2` ファイルをコピーします。

通常は次の順で書き込みます。

1. 必要に応じて `settings_reset` を左右へ書き込む
2. 右手側へ `CLine46_R` の UF2 を書き込む
3. 左手側へ `CLine46_L` の UF2 を書き込む
