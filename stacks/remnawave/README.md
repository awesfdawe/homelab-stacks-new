# Remnawave

Стек панели управления Xray-нодами. В него входят:

- [Remnawave](https://github.com/remnawave/panel) и необходимые для него Redis и PostgreSQL
- [Subscription page](https://github.com/remnawave/subscription-page)

Стек зависит от моего стека reverse-proxy. Перепишите конфигурацию, если это необходимо.

## Развертывание

### 1. Конфигурация

Заполните переменные в файле `vars.yaml` (в качестве примера можно использовать `vars.example.yaml`).

### 2. Запуск

```bash
cd ansible
sudo ansible-playbook playbook.yaml --tags remnawave
```

1. Зайдите в панель Remnawave и зарегистрируйте аккаунт.

2. Перейдите в настройки Remnawave -> API-токены -> Создать. Скопируйте этот токен и добавьте его в `vars.yaml`.

3. Перезапустите стек:

```bash
sudo ansible-playbook playbook.yaml --tags remnawave
```

## Развертывание (без Ansible)

### 1. Конфигурация

Заполните файл `.env`:

```env
DOMAIN=example.com # Главный домен
REMNAWAVE_SUBDOMAIN=remna # Поддомен для панели. remna.DOMAIN -> remna.example.com

SUBSCRIPTION_SUBDOMAIN=sub # Поддомен для страницы подписок. sub.DOMAIN -> sub.example.com

SUBSCRIPTION_PREFIX=0ew012e90319312. # Рандомный путь, можно сгенерировать через openssl rand -hex 24 (чем длиннее, тем лучше)

JWT_AUTH_SECRET=0310qweioqiweiq... # Обязательно сгенерировать через openssl rand -hex 64

JWT_API_TOKENS_SECRET=0310qweioqiweiq... # Обязательно сгенерировать через openssl rand -hex 64
```

### 2. Создание директории

```bash
mkdir -p /mnt/docker-volumes/remnawave
chmod 0750 /mnt/docker-volumes/remnawave
```

### 3. Запуск

```bash
sudo docker compose up -d
```

1. Зайдите в панель Remnawave и зарегистрируйте аккаунт.

2. Перейдите в настройки Remnawave -> API-токены -> Создать. Скопируйте этот токен и добавьте его в `.env`:

```env
REMNAWAVE_API_TOKEN=0310qweioqiweiq...
```

3. Перезапустите стек:

```bash
sudo docker compose up -d
```
