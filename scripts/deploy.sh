#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5"

# 1. Разбор аргумента --dry-run
DRY_RUN=0
case "${1:-}" in
  "")        ;;
  --dry-run) DRY_RUN=1 ;;
  *) echo "Ошибка: неизвестный аргумент '${1}'. Использование: $0 [--dry-run]" >&2; exit 1 ;;
esac
# 2. Проверки по требованиям 4 и 5
if [[ ! -f "${LOCAL_DIR}index.html" ]]; then
  echo "Ошибка: ${LOCAL_DIR}index.html не найден — доставка прервана." >&2
  exit 1
fi
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Ошибка: в репозитории есть незафиксированные изменения:" >&2
  git status --short >&2
  echo "Зафиксируйте их и повторите доставку." >&2
  exit 1
fi
# 3. Синхронизация каталога ${LOCAL_DIR} на ${REMOTE}:${REMOTE_DIR}
# 4. При --dry-run — завершение с кодом 0 без проверки доступности
if [[ $DRY_RUN -eq 1 ]]; then
  rsync -azv --dry-run --delete --chmod=D755,F644 \
        -e "ssh $SSH_OPTS" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
  echo "--dry-run: план показан, состояние сервера не изменено."
  exit 0
fi

rsync -azv --delete --chmod=D755,F644 \
      -e "ssh $SSH_OPTS" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 5. Проверка доступности ${SITE_URL} и завершение с корректным кодом возврата
if curl -fsS --cacert "$CA_CERT" "$SITE_URL" -o /dev/null; then
  echo "Деплой успешен. Коммит: $(git rev-parse --short HEAD)"
  exit 0
else
  echo "Ошибка: ${SITE_URL} недоступен после доставки." >&2
  exit 1
fi
