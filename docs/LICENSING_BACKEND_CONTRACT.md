# Licensing Backend Contract

Atualizado em: 2026-03-06

## Objetivo

O checkout do Fala acontece no site via Paddle.
O app macOS nao fala diretamente com a Paddle para ativacao.

Fluxo esperado:

1. cliente compra no site
2. webhook `transaction.completed` provisiona uma licenca no Worker
3. a tela de sucesso do checkout mostra um `activationCode`
4. o app envia esse codigo ao backend
5. o backend devolve um `entitlementToken` assinado
6. o app salva esse token no Keychain e valida localmente offline

## Configuracao esperada no app

O app le estas chaves do `Info.plist`:

- `FalaLicensingBaseURL`
- `FalaEntitlementPublicKeyBase64`

Sem essas chaves, a ativacao falha de forma honesta.

## Endpoints

### `POST /api/licenses/activate`

Request:

```json
{
  "activationCode": "FALA-ABCD-EFGH-JKLM",
  "machineId": "uuid-da-instalacao",
  "machineName": "Meu MacBook Pro",
  "appVersion": "1.0.2 (3)"
}
```

Response:

```json
{
  "entitlementToken": "<compact-jws>",
  "email": "customer@example.com"
}
```

### `POST /api/licenses/refresh`

Request:

```json
{
  "entitlementToken": "<compact-jws>",
  "machineId": "uuid-da-instalacao",
  "machineName": "Meu MacBook Pro",
  "appVersion": "1.0.2 (3)"
}
```

Response:

```json
{
  "entitlementToken": "<compact-jws>",
  "email": "customer@example.com"
}
```

### `POST /api/licenses/deactivate`

Request:

```json
{
  "entitlementToken": "<compact-jws>",
  "machineId": "uuid-da-instalacao"
}
```

Response:

```json
{
  "success": true
}
```

### `GET /api/licenses/checkout-status?transactionId=txn_...`

Responses:

```json
{
  "status": "pending",
  "transactionId": "txn_..."
}
```

```json
{
  "status": "ready",
  "transactionId": "txn_...",
  "activationCode": "FALA-ABCD-EFGH-JKLM"
}
```

```json
{
  "status": "revoked",
  "transactionId": "txn_..."
}
```

## Webhook esperado

### `POST /api/paddle/webhook`

- assinatura validada via `Paddle-Signature`
- `transaction.completed` cria a licenca
- `adjustment.updated` com status aprovado revoga a licenca

## Token esperado pelo app

Formato:

- JWS compact com 3 partes separadas por `.`
- assinatura Ed25519 valida contra `FalaEntitlementPublicKeyBase64`

Claims usadas:

```json
{
  "iat": 1741220000,
  "exp": 1748996000,
  "product_id": "fala-pro",
  "email": "customer@example.com",
  "license_id": "lic_...",
  "transaction_id": "txn_...",
  "machine_id": "uuid-da-instalacao",
  "machine_name": "Meu MacBook Pro"
}
```

Regras aplicadas localmente:

- `exp` deve estar no futuro, mas um token expirado ainda pode tentar `refresh` uma vez no startup
- `product_id`, quando presente, deve ser `fala-pro`
- `machine_id`, quando presente, deve bater com a instalacao atual
- assinatura deve ser valida

## Politica de licenca

- uma compra gera 1 licenca
- cada licenca pode ficar ativa em ate 3 Macs pessoais
- `deactivate` libera a vaga da maquina
- token emitido com validade de 90 dias
- app tenta refresh quando faltarem 30 dias ou menos

## Erros esperados do backend

Para falha, o app tenta ler uma destas chaves na resposta:

- `message`
- `detail`
- `error`

Exemplo:

```json
{
  "message": "Activation code not found."
}
```

## Observacoes

- nao colocar API key, webhook secret ou qualquer credencial da Paddle dentro do app
- o app trata Paddle apenas como origem comercial da compra, nao como backend de ativacao
- a chave privada Ed25519 vive apenas no Worker
