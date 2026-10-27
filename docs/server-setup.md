# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины

- VirtualBox 7.x, гостевая ОС Ubuntu Server 24.04 LTS
- ОЗУ: 2048 МБ; CPU: 2 ядра; Диск: 25 ГБ, динамически расширяемый

## 2. Сетевые интерфейсы

| Адаптер | Тип       | Адрес          | Назначение                             |
| :-----: | :-------- | :------------- | :------------------------------------- |
|    1    | NAT       | 10.0.2.15      | Доступ в Интернет, репозитории пакетов |
|    2    | Host-only | 192.168.56.101 | Доступ с хоста, веб-сервер             |

## 3. Правило проброса портов

- Имя: ssh;
- Протокол: TCP;
- Хост: 127.0.0.1:2222;
- Гость: 2222.

## 4. Учётные записи

- **student** - группа sudo; парольная аутентификация;
- **devops** - группа sudo; аутентификация по ключу ed25519; вход с хоста командой ssh devops.

## 5. Служба SSH

- Порт: 2222;
- Конфигурация: /etc/ssh/sshd_config.d/99-hardening.conf;
- Директивы:

```
PermitRootLogin no;
PasswordAuthentication no;
PubkeyAuthentication yes;
PermitEmptyPasswords no;
MaxAuthTries 3;
LoginGraceTime 30;

AllowUsers devops;

X11Forwarding no;
ClientAliveInterval 300;
ClientAliveCountMax 2
```

- Активация: ssh.socket отключён, ssh.service включён.

## 6. Правила межсетевого экрана

- Политики: incoming — deny, outgoing — allow;
- Правила: 2222/tcp LIMIT (SSH rate-limited); 80/tcp allow (HTTP); 443/tcp allow (HTTPS).

## 7. Снимки состояния

- _01-clean-install_ - после установки ОС и обновления пакетов;
- _02-keys-configured_ - после задания 1 (учётная запись devops, ключевая аутентификация);
- _03-ssh-hardened_ - после задания 2 (усиление SSH).

## 8. Веб-сервер

- Устанавливаемый пакет: nginx;
- Конфигурация ресурса: /etc/nginx/sites-available/devops-site (активирована симлинком /etc/nginx/sites-enabled/devops-site);
- Каталог ресурса: /var/www/devops-site, владелец devops:devops,права: каталоги 755, файлы 644;
- Сертификат: /etc/ssl/certs/devops.crt (644); ключ: /etc/ssl/private/devops.key (600, root);
- Команда формирования сертификата (срок действия 365 дней):sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048
  -keyout /etc/ssl/private/devops.key -out /etc/ssl/certs/devops.crt
  -subj "/CN=devops.local" -addext "subjectAltName=DNS:devops.local".

## 9. Контейнеризация
Docker Engine установлен на виртуальную машину из официального репозитория Docker по инструкции из документации.
Версия Docker Engine: 29.9.2.

Пользователь devops состоит в группе docker и имеет возможность управлять контейнерами без использования sudo.

Исходный код хранится в репозитории devops-course-2026 на хостовой системе в каталоге app/. На сервере проект размещён по пути /home/devops/app/.

Файл /home/devops/app/.env содержит параметры подключения к PostgreSQL. Права доступа к .env - 600, владелец - devops.

Сервисы:

- app - Flask-приложение, работает от имени непривилегированного пользователя;
- db - PostgreSQL 16.

Приложение опубликовано только на 127.0.0.1:5000 виртуальной машины.

Порт PostgreSQL 5432 не публикуется на хостовой системе.

Для PostgreSQL используется именованный том app_db_data

В существующем HTTPS-блоке /etc/nginx/sites-available/devops-site настроено проксирование:
```
location /app/ {
    proxy_pass http://127.0.0.1:5000/;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

Приложение доступно по адресу https://devops.local/app/.
