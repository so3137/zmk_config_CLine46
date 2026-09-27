# マウスジェスチャーの設定

このリポジトリでは、右手側の PMW3610 トラックボール入力に [`kot149/zmk-mouse-gesture`](https://github.com/kot149/zmk-mouse-gesture) を組み込み、レイヤーごとに異なるマウスジェスチャーを実行できるようにしています。

現在の設定では、レイヤー4とレイヤー5で別々のジェスチャーセットを使います。どちらのレイヤーでも、ジェスチャー入力中はカーソルを動かさないようにしています。

## 関連ファイル

- [config/west.yml](../config/west.yml): `zmk-mouse-gesture` モジュールの取得設定
- [boards/shields/CLine46/CLine46.dtsi](../boards/shields/CLine46/CLine46.dtsi): `mouse-gesture.dtsi` の読み込みと hold-tap 互換設定
- [boards/shields/CLine46/CLine46_R.overlay](../boards/shields/CLine46/CLine46_R.overlay): 右手側トラックボールへの gesture processor 設定
- [config/CLine46.keymap](../config/CLine46.keymap): レイヤー構成

## west module の追加

外部モジュールは [config/west.yml](../config/west.yml) で追加しています。

```yaml
remotes:
  - name: kot149
    url-base: https://github.com/kot149

projects:
  - name: zmk-mouse-gesture
    remote: kot149
    revision: v1
```

初回、または `west.yml` 変更後は依存リポジトリを更新します。

```sh
./scripts/build-firmware.sh
```

すでに `west update` 済みで、設定変更だけを確認する場合は次で十分です。

```sh
./scripts/build-firmware.sh --skip-update
```

## 共通 include

[CLine46.dtsi](../boards/shields/CLine46/CLine46.dtsi) で `mouse-gesture.dtsi` を読み込んでいます。

```dts
#include <mouse-gesture.dtsi>
```

この ZMK fork では `behavior-hold-tap` の `tapping-term-ms` が必須のため、`zmk-mouse-gesture` が提供する `mouse_gesture_kp` / `mouse_gesture_mkp` に値を補っています。

```dts
&mouse_gesture_kp {
    tapping-term-ms = <200>;
};

&mouse_gesture_mkp {
    tapping-term-ms = <200>;
};
```

## レイヤーごとの割り当て

[CLine46_R.overlay](../boards/shields/CLine46/CLine46_R.overlay) の `trackball_listener` に、レイヤー別の child node を追加しています。

```dts
gesture {
    layers = <4>;
    input-processors = <&mouse_runtime_input_processor>,
        <&zip_xy_transform INPUT_TRANSFORM_X_INVERT>,
        <&zip_mouse_gesture_layer_4>,
        <&zip_xy_scaler 0 1>;
};

gesture_layer_5 {
    layers = <5>;
    input-processors = <&mouse_runtime_input_processor>,
        <&zip_xy_transform INPUT_TRANSFORM_X_INVERT>,
        <&zip_mouse_gesture_layer_5>,
        <&zip_xy_scaler 0 1>;
};
```

ポイント:

- `layers = <4>` / `layers = <5>` で、対象レイヤーだけに processor を適用します。
- `zip_mouse_gesture_layer_4` と `zip_mouse_gesture_layer_5` を分けることで、レイヤーごとに異なる gesture pattern を定義できます。
- `&zip_xy_scaler 0 1` で X/Y 移動量を 0 にし、ジェスチャー中にカーソルが動かないようにしています。
- レイヤー4/5以外では、通常のトラックボール移動が使われます。

## 現在のジェスチャー

### レイヤー4

| ジェスチャー | 実行内容 |
| --- | --- |
| 右 | `Alt+Left` |
| 左 | `Alt+Right` |
| 下、右 | `Ctrl+W` |
| 下、左 | `Ctrl+T` |

### レイヤー5

| ジェスチャー | 実行内容 |
| --- | --- |
| 上 | `Ctrl+C` |
| 下 | `Ctrl+V` |
| 左 | `Ctrl+Z` |
| 右 | `Ctrl+Y` |

## ジェスチャーを追加する

レイヤー4へ追加する場合は `zip_mouse_gesture_layer_4` に child node を追加します。レイヤー5へ追加する場合は `zip_mouse_gesture_layer_5` に追加します。

例:

```dts
save {
    pattern = <GESTURE_UP GESTURE_DOWN>;
    bindings = <&kp LC(S)>;
};
```

`pattern` には次の方向を組み合わせます。

- `GESTURE_UP`
- `GESTURE_DOWN`
- `GESTURE_LEFT`
- `GESTURE_RIGHT`

`bindings` には通常の ZMK behavior を指定できます。

## 調整項目

各 gesture processor では、現在次の設定を使っています。

```dts
stroke-size = <300>;
enable-eager-mode;
always-active;
```

- `stroke-size`: 1ストロークとして認識する移動量です。小さくすると短い移動で認識し、大きくすると大きめに動かす必要があります。
- `enable-eager-mode`: パターン一致時に早めに binding を実行します。
- `always-active`: activation key を使わず、対象レイヤーに入っている間は gesture processor を常時有効にします。

## 注意点

- レイヤー4/5の child override では `process-next` を指定していません。そのため、該当レイヤーでは base の通常移動 processor は実行されません。
- カーソルを止めたい場合は、gesture processor の後ろに `&zip_xy_scaler 0 1` を置きます。前に置くと gesture processor 側も移動量を受け取れなくなります。
- トラックボールは右手側にあるため、実体の設定は `CLine46_R.overlay` に置いています。
- モジュール追加後に `#include <mouse-gesture.dtsi>` が見つからない場合は、`west update` が済んでいるか確認してください。
