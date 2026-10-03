# ruleset-main-protect-demo

GitHub の Rulesets で「`main` と `main-*` への直接 push を禁止し、PR 経由だけにする」ことが本当にできるかを確かめるための、検証専用リポジトリ。
中身はダミー（`sample.txt` だけ）。実案件の情報は入れない。

手で触って確かめる手順は [ハンズオン_Ruleset.md](ハンズオン_Ruleset.md)。ターミナルでまとめて確かめるなら `bash verify.sh`。

## 結論

**できる。** `main`・`main-*` への直接 push・force push・削除はすべて拒否され、PR のマージだけが通る。admin も止まる。
`main-*` に当てはまる「新しいブランチ」の作成は止まらない（#7）。ArgoCD は Application に書いたブランチしか読まないので、問題にならないと判断した。

## 前提

| 項目 | 条件 |
|---|---|
| プラン | private リポジトリで使うには Organization が **Team 以上**。Free プランでは public リポジトリだけ（このリポジトリが public なのはそのため） |
| 設定する人 | リポジトリの admin |

## 設定内容

[`rulesets/protect-main.json`](rulesets/protect-main.json) のとおり。

| 項目 | 値 |
|---|---|
| Ruleset Name | `protect-main` |
| Enforcement status | Active |
| Bypass list | なし |
| Target branches | `main`、`main-*`（`main-*` は `main` 自体を含まないので2つとも入れる） |
| Restrict creations | OFF（下の「#7 について」） |
| Restrict deletions | ON |
| Block force pushes | ON |
| Require a pull request before merging | ON（Required approvals は 0） |

### 画面で設定する手順

1. リポジトリの **Settings** → 左メニュー **Rules** → **Rulesets**
2. **New ruleset** → **New branch ruleset**
3. 上の表のとおりに入力する。Target branches は **Add target** → **Include by pattern** で `main` と `main-*` を1つずつ追加する
4. **Create** を押す

### コマンドで設定する場合

```bash
gh api -X POST repos/<owner>/<repo>/rulesets --input rulesets/protect-main.json
```

JSON は記録用で、置いただけでは何も起きない。上のコマンドを実行したときに設定される。

## 検証結果（2026-10-03）

| # | 操作 | 期待 | 結果 |
|---|---|---|---|
| 1 | `main-ita` に直接 push | 拒否 | ✅ 拒否（`Changes must be made through a pull request.`） |
| 2 | `main` に直接 push | 拒否 | ✅ 拒否（同上） |
| 3 | `main-ita` に force push | 拒否 | ✅ 拒否（`Cannot force-push to this branch`） |
| 4 | `main-ita` を削除 | 拒否 | ✅ 拒否（`Cannot delete this branch`） |
| 5 | `release-ita` → `main-ita` の PR をマージ | 成功 | ✅ 成功（PR #1） |
| 6 | 対象外の `release-ita` に直接 push | 成功 | ✅ 成功 |
| 7 | まだ無い `main-itb` を直接作成（Restrict creations OFF のとき） | ― | ⚠️ **作れてしまう**（PR を通らない中身の `main-*` ができる） |
| 8 | まだ無い `main-itc` を直接作成（Restrict creations ON のとき） | 拒否 | ✅ 拒否（`Cannot create ref due to creations being restricted.`）。`release-itc` は作れる |

1〜4 は、Organization の admin のアカウントで実行して拒否された。

拒否されたときの表示:

```
remote: error: GH013: Repository rule violations found for refs/heads/main-ita.
remote: - Changes must be made through a pull request.
 ! [remote rejected] main-ita -> main-ita (push declined due to repository rule violations)
```

### #7 について

守りたいのは「すでにあって ArgoCD が読んでいる `main-*` の中身」で、それは PR 必須・force push 禁止・削除禁止で守れている。新しく作ったブランチは、Application をそこへ向けない限りデプロイされないので、**Restrict creations は OFF にした**。新しい工程のブランチを Application に登録するときに、中身を人が確認する。

新規作成も止めたい場合は Restrict creations を ON にする（#8 で効くことを確認済み）。その場合、新しいブランチを作るときは admin が一時的に Bypass list に入るなどの手間が増える。

（検証で作った `main-itb` は、削除禁止のルールのため残している）
