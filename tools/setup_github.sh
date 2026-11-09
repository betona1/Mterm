#!/usr/bin/env bash
# 깃허브 자동 업데이트 마무리 — 터미널에서 한 번만:  ! bash tools/setup_github.sh
#
# 1) gh 토큰에 workflow 권한을 더한다 (브라우저가 열리면 승인)
# 2) 서명 키를 GitHub Secrets 에 넣는다 (KEYSTORE_BASE64 · KEYSTORE_PASSWORD · KEY_PASSWORD · KEY_ALIAS)
# 3) .github/workflows/release.yml 을 커밋·푸시한다 → Actions 가 APK 릴리스 + Pages(PWA) 배포를 시작
set -e
cd "$(dirname "$0")/.."

echo "== 1) gh 권한 (workflow) =="
if gh auth status 2>&1 | grep -q "workflow"; then
  echo "이미 workflow 권한이 있어요 — 건너뜀"
else
  gh auth refresh -h github.com -s workflow,repo
fi

echo "== 2) Secrets =="
. <(sed 's/^/export KP_/' android/key.properties)
gh secret set KEYSTORE_BASE64 --body "$(base64 -w0 android/mterm-release.jks)"
gh secret set KEYSTORE_PASSWORD --body "$KP_storePassword"
gh secret set KEY_PASSWORD --body "$KP_keyPassword"
gh secret set KEY_ALIAS --body "$KP_keyAlias"
gh secret list

echo "== 3) 워크플로 푸시 =="
git add .github/workflows/release.yml
git -c user.name="betona1" -c user.email="netkjy@gmail.com" commit -m "GitHub Actions: APK 릴리스 + Pages(PWA) 자동 배포

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>" || true
git push origin main
echo
echo "끝. 진행 상황: https://github.com/betona1/Mterm/actions"
echo "릴리스:      https://github.com/betona1/Mterm/releases"
echo "PWA:         https://betona1.github.io/Mterm/"
