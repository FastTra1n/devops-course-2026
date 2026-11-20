#!/usr/bin/env bash
set -uo pipefail
PASS=0; FAIL=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  [OK] $desc"; ((PASS++))
  else
    echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')";
    ((FAIL++))
  fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"
# TODO 1: порт SSH отличается от 22
check "Порт SSH отличается от стандартного 22" "True" "$(sudo sshd -T | awk '/^port/{print ($2==22)?"False":"True"}')"
# TODO 2: maxauthtries равен 3
check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"
# TODO 3: политика по умолчанию для входящих — deny
check "Политика по умолчанию для входящих — deny" "deny" "$(sudo ufw status verbose | awk '/^Default:/{print $2}')"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf "  %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# а) служба активна
check "Служба nginx активна" "active" "$(systemctl is-active nginx)"
# б) конфигурация синтаксически корректна (код возврата nginx -t)
check "Конфигурация nginx корректна" "0" "$(sudo nginx -t >/dev/null 2>&1; echo $?)"
# в) сертификат истекает не ранее чем через 30 дней (2592000 с)
check "Сертификат действителен более 30 дней" "0" "$(sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; echo $?)"
# г) нет файлов с правом записи для всех
check "Нет файлов, доступных на запись всем" "0" "$(find /var/www/devops-site -perm -o+w | wc -l)"
# г) права ключа равны 600
check "Права ключа TLS равны 600" "600" "$(sudo stat -c '%a' /etc/ssl/private/devops.key)"

echo "[5] Контейнеризация"
# а) служба docker активна
check "Служба Docker активна" "active" "$(systemctl is-active docker)"
# б) контейнер СУБД находится в состоянии healthy
check "PostgreSQL здоров" "healthy" "$(docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null)"
# в) порты 5000 и 5432 не прослушиваются ни на одном адресе, кроме 127.0.0.1
PORTS_STATUS="$(
    ss -tln | awk '
        NR > 1 {
            addr = $4
            if (addr ~ /:(5000|5432)$/ &&
                addr != "127.0.0.1:5000" &&
                addr != "127.0.0.1:5432") {
                bad = 1
            }
        }
        END {
            print bad ? "unsafe" : "safe"
        }
    '
)"

check "Порты 5000 и 5432 защищены" "safe" "$PORTS_STATUS"
# г) права файла ~/app/.env равны 600
check "Права файла .env" "600" "$(stat -c '%a' "$HOME/app/.env" 2>/dev/null)"

echo "[6] Контрольная работа № 2"

# а) контейнер сервиса redis находится в состоянии healthy.
REDIS_ID="$(docker compose --project-directory "$HOME/kr2" ps -q redis)"

check "Redis healthy" "healthy" \
  "$(docker inspect -f '{{.State.Health.Status}}' "$REDIS_ID" 2>/dev/null)"

# б) порт 8003 опубликован только на адресе 127.0.0.1
check "Порт приложения защищён" "127.0.0.1:8003" \
  "$(docker compose --project-directory "$HOME/kr2" port app 8003 2>/dev/null)"

# в) права файла ~/kr2/.env равны 600
check "Права KR2 .env" "600" \
  "$(stat -c '%a' "$HOME/kr2/.env" 2>/dev/null)"

# г) сертификат /etc/ssl/certs/kr2.crt истекает не ранее чем через 30 дней
check "Сертификат KR2 действителен" "0" \
  "$(sudo openssl x509 -checkend 2592000 -noout \
      -in /etc/ssl/certs/kr2.crt >/dev/null 2>&1; echo $?)"

# д) ресурс kr2 активирован (символическая ссылка в /etc/nginx/sites-enabled/)
check "Ресурс KR2 активирован" "yes" \
  "$([[ -L /etc/nginx/sites-enabled/kr2 ]] && echo yes || echo no)"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
