#!/usr/bin/env bash
# GitHub Actions 전용: 코틀린 컴파일러 jar 를 미리 받아 ~/.m2 에 넣고, Gradle 이 mavenLocal 을 맨 먼저 보게 한다.
#
# 왜: 깃허브 러너에서 Maven Central 이 큰 코틀린 jar 를 github.com 릴리스로 리다이렉트하는데 그쪽이 504 를 자주 낸다
#     (2026-11-09 첫 릴리스 빌드 두 번 연속 실패). Gradle 은 404 가 아닌 오류를 만나면 다음 저장소로 안 넘어가므로
#     mavenLocal 을 맨 앞에 두고 jar 를 여러 출처(구글 미러 → Central → GitHub)에서 재시도해 받아 둔다.
# 사용: bash tools/ci_prefetch_kotlin.sh <코틀린버전>
set -u
V="${1:?kotlin version}"
ARTIFACTS="kotlin-compiler-embeddable kotlin-build-tools-impl kotlin-daemon-embeddable"
SOURCES=(
  "https://maven-central.storage-download.googleapis.com/maven2"
  "https://repo1.maven.org/maven2"
  "https://repo.maven.apache.org/maven2"
)

fetch() { # url dest
  curl -fL --silent --show-error --retry 4 --retry-all-errors --retry-delay 5 --connect-timeout 20 --max-time 600 -o "$2" "$1"
}

for A in $ARTIFACTS; do
  D="$HOME/.m2/repository/org/jetbrains/kotlin/$A/$V"
  mkdir -p "$D"
  for EXT in pom jar; do
    F="$D/$A-$V.$EXT"
    [ -s "$F" ] && { echo "있음: $A.$EXT"; continue; }
    ok=0
    for round in 1 2 3; do
      for S in "${SOURCES[@]}"; do
        if fetch "$S/org/jetbrains/kotlin/$A/$V/$A-$V.$EXT" "$F" && [ -s "$F" ]; then
          echo "받음: $A.$EXT ← $S"; ok=1; break 2
        fi
        rm -f "$F"
      done
      if [ "$EXT" = jar ] && fetch "https://github.com/JetBrains/kotlin/releases/download/v$V/$A-$V.jar" "$F" && [ -s "$F" ]; then
        echo "받음: $A.jar ← GitHub 릴리스"; ok=1; break
      fi
      rm -f "$F"; sleep 15
    done
    [ "$ok" = 1 ] || echo "!! 못 받음: $A.$EXT (Gradle 이 직접 시도한다)"
  done
done

# Gradle 초기화 스크립트: settings 의 dependencyResolutionManagement 저장소 맨 앞에 mavenLocal
# (Flutter 도구의 Gradle 플러그인 포함 빌드가 FAIL_ON_PROJECT_REPOS 로 여기서만 저장소를 정한다.)
# ⚠️ pluginManagement 나 프로젝트 repositories 는 건드리지 않는다 — 건드리면 기본 gradlePluginPortal 이 사라져
#    dev.flutter.flutter-plugin-loader 를 못 찾는다 (2026-11-09 3번째 빌드 실패). 앱 쪽은 android/build.gradle.kts 에 직접 넣었다.
mkdir -p "$HOME/.gradle/init.d"
cat > "$HOME/.gradle/init.d/maven-local-first.gradle" <<'GRADLE'
settingsEvaluated { s ->
    try {
        def h = s.dependencyResolutionManagement.repositories
        if (!h.isEmpty()) {
            def local = h.mavenLocal()
            h.remove(local)
            h.addFirst(local)
        }
    } catch (Throwable ignored) {}
}
GRADLE
echo "init.d/maven-local-first.gradle 작성"
