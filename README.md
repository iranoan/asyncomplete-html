# asyncomplete-html-id

## 概要

* [asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim) の補完で
  * HTML の class, id 名の補完候補をだす
    * 次の設定時のオムニ補完と違い指定済みの class, id は補完候補から除外する

      ```vim
      setlocal omnifunc=lsp#complete
      ```

  * HTML タグ内の href/src 属性でパスの補完をする
    * a タグの href 属性では id の補完もする
    * さらに

        ```vim
        let g:asyncomplete_auto_completeopt = 0
        set completeopt=menuone,noinsert,noselect,popup
        ```

      と completeopt に popupが有れば、次を追加で表示する
      * HTML/XHTML ファイル名の補完なら title タグの内容
      * id の属性値なら要素の内容か 40 行先まで

### 制限

* タグ固有の class, id の属性値は同一行である必要がある
  * 異なる行ではグローバルな値のみリスト・アップする
* class, id の属性値の絞り込みはタグの子孫要素は考慮しない
* リストアップするのは
  * 編集している HTML の head 要素内に

    ```html
    <link rel="stylesheet" type="text/css" href="default.css">
    ```

    のような、もしくは style 要素内や読み込み指定した CSS ファイルに

    ```CSS
    @import url(default.css);
    ```

    のように使用する CSS が具体的に記述されている**ローカル・ファイル**のみ
  * class/id 名の判定はゆるいので、余分な候補が含まれる場合も有る
* syntax の {group-name} (構文グループ名) で htmlString, htmlValue, htmlTag を条件にしているので

  ```vim
  syntax on
  ```

  にする必要がある

## 注意事項

* デフォルトで class, id 名扱いにするのは [0-9A-Za-z\_-] (英数字と -\_)、ファイル名は [0-9A-Za-z.\_-] 相当
  * 変更する場合は asyncomplete#sources#html\_id#GetSourceOptions() の refresh\_pattern を指定する  
    この時 \c (大・小文字区別なし) 相当で URL に使われる /, # も加えて指定する必要がある
* Vim9 script で書かれているので、[asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim) の他のソースと異なり、上に有る通り関数名がスネーク・ケースではなく、アッパー・キャメル・ケースになっているので設定時に注意が必要

## 要件

* Vim 9.0 以上
* [asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim)
* NeoVim では動作しない

## 設定方法

\~/.vim/vimrc などの設定ファイルに次のような記載を加える

```vim
call asyncomplete#register_source(asyncomplete#sources#html_id#GetSourceOptions({}))
```

## 使用方法

設定が終われば、class/id の属性値で [asyncomplete.vim](https://github.com/prabirshrestha/asyncomplete.vim) の補完候補に現れる
