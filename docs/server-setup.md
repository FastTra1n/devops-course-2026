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
