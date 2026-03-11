# Vaultwarden

Менеджер паролей, совместимый с клиентами Bitwarden. 

Стек зависит от моего стека reverse-proxy. Перепишите конфигурацию, если это необходимо.

## Референс

- https://github.com/dani-garcia/vaultwarden

## Развертывание

### 1. Конфигурация

Заполните переменные в файле `vars.yaml` (в качестве примера можно использовать `vars.example.yaml`).

### 2. Запуск

```bash
cd ansible
sudo ansible-playbook playbook.yaml --tags vaultwarden
```
