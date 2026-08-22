#!/usr/bin/env bash
set -euo pipefail
usage() { cat <<'USAGE'
Usage: setup.sh [--work-dir DIR] <temurin-jdk*.tar.gz> [gradle*.zip] [apache-maven*.tar.gz]
Installs the transferred JDK/build tools into a writable prefix. No network or root access is used.
USAGE
}
die(){ printf 'error: %s\n' "$*" >&2; exit 1; }
log(){ printf '[java-setup] %s\n' "$*"; }
WORK_DIR=${JAVA_KIT_WORK_DIR:-$PWD/.tools/java}; [[ -d /mnt/data ]] && WORK_DIR=${JAVA_KIT_WORK_DIR:-/mnt/data/java-kit}
JDK= GRADLE= MAVEN=
while (($#)); do case "$1" in --work-dir) WORK_DIR=$2; shift 2;; -h|--help) usage; exit 0;; -*) die "unknown option: $1";; *) case "$(basename "$1")" in temurin-jdk*.tar.gz) JDK=$1;; gradle-*.zip) GRADLE=$1;; apache-maven-*.tar.gz) MAVEN=$1;; *) die "unrecognized artifact: $1";; esac; shift;; esac; done
[[ -f "$JDK" ]] || die 'Temurin JDK archive is required'
for c in tar unzip; do command -v "$c" >/dev/null || die "$c is required"; done
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR/jdk" "$WORK_DIR/tools"
tar -xzf "$JDK" -C "$WORK_DIR/jdk" --strip-components=1
JAVA_HOME="$WORK_DIR/jdk"; [[ -x "$JAVA_HOME/bin/java" ]] || die 'java binary not found after extraction'
log "$($JAVA_HOME/bin/java -version 2>&1 | head -n1)"
GRADLE_HOME=; if [[ -n "$GRADLE" ]]; then tmp=$(mktemp -d); unzip -q "$GRADLE" -d "$tmp"; dir=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1); [[ -n "$dir" ]] || die 'unexpected Gradle archive'; mv "$dir" "$WORK_DIR/tools/gradle"; rm -rf "$tmp"; GRADLE_HOME="$WORK_DIR/tools/gradle"; JAVA_HOME="$JAVA_HOME" "$GRADLE_HOME/bin/gradle" --version >/dev/null; fi
MAVEN_HOME=; if [[ -n "$MAVEN" ]]; then mkdir -p "$WORK_DIR/tools/maven"; tar -xzf "$MAVEN" -C "$WORK_DIR/tools/maven" --strip-components=1; MAVEN_HOME="$WORK_DIR/tools/maven"; JAVA_HOME="$JAVA_HOME" "$MAVEN_HOME/bin/mvn" --version >/dev/null; fi
cat > "$WORK_DIR/env.sh" <<ENV
export JAVA_HOME=$(printf '%q' "$JAVA_HOME")
export PATH=$(printf '%q' "$JAVA_HOME/bin${GRADLE_HOME:+:$GRADLE_HOME/bin}${MAVEN_HOME:+:$MAVEN_HOME/bin}"):\$PATH
${GRADLE_HOME:+export GRADLE_HOME=$(printf '%q' "$GRADLE_HOME")}
${MAVEN_HOME:+export MAVEN_HOME=$(printf '%q' "$MAVEN_HOME")}
ENV
log "environment file: $WORK_DIR/env.sh"
