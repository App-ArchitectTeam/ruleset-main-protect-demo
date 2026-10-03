# ハンズオン：Ruleset で main-* への直接 push が止まることを、手で確かめる

> **ゴール**：「`main-*` は PR のマージでしか変えられない」ことを、画面を触って確かめる。設定を外すと止まらなくなることも見て、止めているのが Ruleset だと分かる
> **所要時間**：20分
> **前提**：Ruleset `protect-main` を [README.md](README.md) の「設定内容」どおりに作ってあること

このリポジトリはダミーなので、何をしても実害はない。

## このリポジトリのブランチ

| ブランチ | Ruleset の対象か | 役割（本物の Manifest でいうと） |
|---|---|---|
| `main`・`main-ita` | **対象**（守られている） | ArgoCD が読む場所。PR のマージでしか変えさせたくない |
| `release-ita` | 対象外 | 変更を入れる場所。直接 push してよい |
| `main-itb` | 対象 | 検証のときに作ったブランチ。今回は使わない |

---

## 1. 画面から `main-ita` を直接書き換えようとする → 止まる

1. リポジトリのトップで、左上のブランチ切り替え（`main` と書かれたボタン）を押し、`main-ita` を選ぶ
2. `sample.txt` を開き、右上の鉛筆アイコン（Edit this file）を押す
3. 中身を `value: direct-edit` に書き換え、右上の **Commit changes...** を押す
4. 出てきたダイアログを見る

**見るところ**：「`main-ita` に直接コミットする」という選択肢が選べず、**新しいブランチを作って PR を出す**選択肢だけになっている（または、コミットしようとするとルール違反のメッセージが出る）。

> [!NOTE]
> 画面の編集も、裏では `git push` と同じ扱い。だから画面からでも、ターミナルからでも同じように止まる。

ここでは何もコミットせず、**Cancel** で閉じる（鉛筆の編集画面も **Cancel changes** で閉じる）。

## 2. 画面から `main-ita` を削除しようとする → 止まる

1. リポジトリのトップで **Branches**（ブランチ数が書かれたリンク）を開く
2. `main-ita` の行のゴミ箱アイコンを見る

**見るところ**：ゴミ箱が押せない、または押すとルール違反で削除できない。`release-ita` の行は押せる状態になっている（**押さないこと**。押してしまったら、すぐ横に出る **Restore** で戻す）。

## 3. PR を通せば `main-ita` を変えられる

ここが「正しい道」。本物では、Tekton や W0 が作る PR を人がマージする、の流れにあたる。

1. ブランチを `release-ita` に切り替え、`sample.txt` を鉛筆で編集する。中身を `value: via-pr` にする
2. **Commit changes...** → **Commit directly to the `release-ita` branch** を選んで **Commit changes**（`release-ita` は対象外なので、直接コミットできる）
3. 上部の **Pull requests** → **New pull request**
4. **base** を `main-ita`、**compare** を `release-ita` にする（← 左が「入れる先」、右が「入れるもの」）
5. **Create pull request** → タイトルはそのままで **Create pull request**
6. **Merge pull request** → **Confirm merge**
7. ブランチを `main-ita` に切り替えて `sample.txt` を開く

**見るところ**：`main-ita` の `sample.txt` が `value: via-pr` になっている。1 では止められた変更が、PR を通すと入る。

## 4. Ruleset を止めると、直接書き換えられてしまう（比較実験）

「止めているのは本当に Ruleset なのか」を確かめる。**終わったら必ず元に戻す。**

1. **Settings** → 左メニュー **Rules** → **Rulesets** → `protect-main` を開く
2. **Enforcement status** を **Disabled** にして、一番下の **Save changes**
3. 1 と同じ手順で、`main-ita` の `sample.txt` を `value: direct-edit` に書き換えて **Commit changes...**

**見るところ**：今度は **Commit directly to the `main-ita` branch** が選べる。選んでコミットすると、**PR を通らずに `main-ita` が変わってしまう**。本物の Manifest なら、レビューされていない変更がそのまま ArgoCD に読まれる状態。

4. **すぐ元に戻す**：`protect-main` の **Enforcement status** を **Active** に戻して **Save changes**
5. 1 をもう一度やり、また止まるようになったことを確かめる

> [!IMPORTANT]
> **Enforcement status が Active でなければ何も止まらない。** Evaluate（記録だけ）や Disabled のままにしていないか、設定のあとに必ず確かめる。

## 5. ターミナルからも止まることを確かめる（任意）

画面でできない操作（force push）も含めて、まとめて確かめるスクリプトがある。

```bash
git clone https://github.com/App-ArchitectTeam/ruleset-main-protect-demo.git
cd ruleset-main-protect-demo
bash verify.sh
```

| # | 操作 | 期待 |
|---|---|---|
| 1 | `main-ita` に直接 push | 拒否 |
| 2 | `main` に直接 push | 拒否 |
| 3 | `main-ita` に force push（履歴の書き換え） | 拒否 |
| 4 | `main-ita` を削除 | 拒否 |
| 5 | `release-ita` に push | 成功 |

最後に `OK 5 件 / NG 0 件` と出れば成功。拒否されたときは次のように表示される。

```
remote: error: GH013: Repository rule violations found for refs/heads/main-ita.
remote: - Changes must be made through a pull request.
 ! [remote rejected] main-ita -> main-ita (push declined due to repository rule violations)
```

> [!WARNING]
> 4 の比較実験の途中（Disabled のまま）で `verify.sh` を流さないこと。本当に `main-ita` が書き換わったり消えたりする。NG が出るとそこで止まり、元に戻すコマンドが表示される。

## まとめ

| 操作 | Ruleset Active | Ruleset Disabled |
|---|---|---|
| `main-ita` を画面・git で直接変える | 止まる | **入ってしまう** |
| `main-ita` を削除・force push | 止まる | **できてしまう** |
| `release-ita` → `main-ita` の PR をマージ | できる | できる |

**`main-*` を変える道は「PR のマージ」1本だけになる。** だから PR の宛先（base）を正しくすることが大事で、それを人の手でやらせないのが W0（PR の自動作成）の役割。
