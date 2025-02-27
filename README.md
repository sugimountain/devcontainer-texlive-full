# devcontainer-texlive-full
Devcontainer で LaTeX を使うためのリポジトリです。
TexLive公式のFullイメージを使用しています。

`lualatex`, `platex`, `uplatex`に対応しています。

タイプセット方法に合わせてsettings.jsonの値を変えてください。ない場合は調べて自分で作ってください。

デフォルト値は最後に使ったタイプセット方法を記憶するように設定してあります。
```
// settings.json
  "latex-workshop.latex.recipe.default": "lastused"
``` 
| タイプセット方法 | 値 |
| --- | --- |
| (u)pLaTeX | "latexmk (latexmkrc)"（.latexmkrc 要作成）|
| LuaLaTeX | "latexmk (lualatex)" |

`upLaTeX`でタイプセットする場合は、`.latexmkrc` が必要です。
もしも`upLaTeX`ではなく`pLaTeX`を使いたい場合は、.latexmkrcの以下の部分を書き換えてください。

```
# fmtlatexの呼び出し
$pdf_mode = 3;
% platexを使う場合はuplatexをplatexに変更
$latex = 'internal fmtlatex uplatex ~ ~ ~
$dvipdf = 'dvipdfmx %O -o %D %S';
$max_repeat = 5;
```

# 参考にしたサイト

[Qiita: なるべくデフォルトのまま使いたい人へ](https://qiita.com/Yarakashi_Kikohshi/items/e9270af54569640fe80f)

[ただしい高速LaTeX論](https://qiita.com/JyJyJcr/items/69769c88eea9d0dae152)

[WSLとVSCodeを用いて高速で快適なLaTeX環境をインストールしたい](https://qiita.com/utaoji/items/d2a880905172440b27fe#latexmkrc%E3%81%AE%E8%A8%AD%E5%AE%9A)
