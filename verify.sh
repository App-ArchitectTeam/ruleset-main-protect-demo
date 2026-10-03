#!/usr/bin/env bash
# Ruleset が効いているかを確かめる。main / main-ita への直接 push・force push・削除が拒否され、
# release-ita への push は通ることを見る。手元の作業ツリーは変えない。
#   bash verify.sh
set -u
cd "$(dirname "$0")"
git fetch -q --prune origin

pass=0; fail=0
check() {  # check <番号と内容> <expect: reject|accept> <git push の引数...>
  local name=$1 expect=$2; shift 2
  local out; out=$(git push "$@" 2>&1)
  local got=accept; grep -q "rejected" <<<"$out" && got=reject
  if [ "$got" = "$expect" ]; then
    echo "OK  ${name}（期待どおり ${expect}）"; pass=$((pass+1))
  else
    echo "NG  ${name}（期待 ${expect}／結果 ${got}）"; fail=$((fail+1))
  fi
  grep -E "remote: - " <<<"$out" | sed 's/^/      /'
  if [ "$got" != "$expect" ] && [ "$expect" = reject ]; then
    echo
    echo "ここで止めます。Ruleset が効いておらず、今の操作がそのまま GitHub に入りました。"
    echo "設定を見直す前に、次の2行で main と main-ita を元に戻してください（Ruleset を消すか Disabled にしてから実行）:"
    echo "  git push -f origin ${orig_main}:refs/heads/main"
    echo "  git push -f origin ${orig_main_ita}:refs/heads/main-ita"
    exit 1
  fi
}

orig_main=$(git rev-parse origin/main)
orig_main_ita=$(git rev-parse origin/main-ita)

# 中身は同じで、コミットだけ新しく作る（作業ツリーは触らない）
on_main_ita=$(git commit-tree "origin/main-ita^{tree}" -p origin/main-ita -m "直接 push テスト")
on_main=$(git commit-tree "origin/main^{tree}" -p origin/main -m "直接 push テスト")
orphan=$(git commit-tree "origin/main-ita^{tree}" -m "履歴書き換えテスト")
on_release=$(git commit-tree "origin/release-ita^{tree}" -p origin/release-ita -m "release-ita への push テスト")

check "1 main-ita に直接 push"   reject origin "$on_main_ita:refs/heads/main-ita"
check "2 main に直接 push"       reject origin "$on_main:refs/heads/main"
check "3 main-ita に force push" reject -f origin "$orphan:refs/heads/main-ita"
check "4 main-ita を削除"        reject origin --delete main-ita
check "5 release-ita に push"    accept origin "$on_release:refs/heads/release-ita"

echo "---- OK $pass 件 / NG $fail 件"
