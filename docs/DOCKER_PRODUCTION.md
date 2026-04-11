# Build e deploy da imagem Docker para produção (GS2 Next Connecta)

Este guia descreve como gerar a imagem Docker em modo produção e subir o ambiente.

## Pré-requisitos

- Docker instalado
- Repositório no estado desejado (ex.: branch `feature/rebrand-custom-branding` com commit do rebrand)
- Acesso a um registry (Docker Hub, AWS ECR, etc.), se for publicar a imagem

## 1. Build da imagem

**Opção A – Script (recomendado)**

Na raiz do projeto, execute:

```bash
# Linux / macOS / Git Bash (dê permissão uma vez: chmod +x scripts/build-docker-image.sh)
./scripts/build-docker-image.sh
```

Com nome e tag customizados:

```bash
./scripts/build-docker-image.sh meu-registry/gs2-next-connecta v1.0.0
```

No Windows (CMD):

```cmd
scripts\build-docker-image.bat
scripts\build-docker-image.bat meu-registry/gs2-next-connecta v1.0.0
```

O script usa por padrão `gs2-next-connecta:latest` e faz o build com `-f ./docker/Dockerfile` e contexto na raiz do projeto.

**Opção B – Comando manual**

Na raiz do projeto:

```bash
# Nome da imagem (ajuste o nome/registry se quiser)
export IMAGE_NAME=gs2-next-connecta
export IMAGE_TAG=latest

# Build para produção (RAILS_ENV=production é o padrão do Dockerfile)
docker build -t $IMAGE_NAME:$IMAGE_TAG -f ./docker/Dockerfile .
```

**Opção C – Makefile**

```bash
# Edite APP_NAME no Makefile para gs2-next-connecta ou use:
docker build -t gs2-next-connecta:latest -f ./docker/Dockerfile .
```

O build vai:

- Instalar dependências Ruby e Node/pnpm
- Fazer `rake assets:precompile` (frontend compilado dentro da imagem)
- Gerar `.git_sha` a partir do commit atual
- Produzir uma imagem Alpine com a aplicação em `/app`

Tempo típico: vários minutos (depende da máquina).

## 2. Testar a imagem localmente

Você precisa de **PostgreSQL** e **Redis** rodando. Exemplo com docker-compose só para infra:

**Arquivo de ambiente para produção:** use `.env.prod` (cópia do `.env` na raiz). Revise e ajuste para produção: `SECRET_KEY_BASE`, `FRONTEND_URL`, `POSTGRES_*`, `REDIS_URL`, `RAILS_ENV=production`, etc. O arquivo `.env.prod` está no `.gitignore` para não versionar segredos.

**Crie um `docker-compose.prod.yml` (exemplo):**

```yaml
services:
  app:
    image: gs2-next-connecta:latest
    env_file: .env.prod
    environment:
      - RAILS_ENV=production
      - POSTGRES_HOST=postgres
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    command: bundle exec rails s -b 0.0.0.0 -p 3000
    ports:
      - "3000:3000"

  sidekiq:
    image: gs2-next-connecta:latest
    env_file: .env
    environment:
      - RAILS_ENV=production
      - POSTGRES_HOST=postgres
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    command: bundle exec sidekiq -C config/sidekiq.yml

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: chatwoot_production
    volumes:
      - postgres_data:/var/lib/postgresql/data
    # Ajuste porta se precisar acessar de fora
    # ports:
    #   - "5432:5432"

  redis:
    image: redis:alpine
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

**Variáveis importantes no `.env` (produção):**

- `SECRET_KEY_BASE` – gere com `rails secret`
- `FRONTEND_URL` – URL do front (ex.: https://chat.seudominio.com)
- `POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DATABASE`
- `REDIS_URL` – ex.: `redis://redis:6379`
- `MAILER_SENDER_EMAIL` – ex.: GS2 Next Connecta <noreply@seudominio.com>

**Rodar e criar o banco:**

```bash
# Subir apenas postgres e redis
docker compose -f docker-compose.prod.yml up -d postgres redis

# Primeira vez: criar e migrar o banco (rode na sua máquina com bundle ou em um container one-off)
# Com container:
docker compose -f docker-compose.prod.yml run --rm app bundle exec rails db:create db:migrate

# Sincronizar branding (logos/nome) no banco
docker compose -f docker-compose.prod.yml run --rm app bundle exec rake branding:sync_config

# Subir app e sidekiq
docker compose -f docker-compose.prod.yml up -d app sidekiq
```

Acesse `http://localhost:3000` (ou a URL configurada).

## 3. Publicar a imagem em um registry

**Docker Hub:**

```bash
docker tag gs2-next-connecta:latest SEU_USUARIO/gs2-next-connecta:latest
docker push SEU_USUARIO/gs2-next-connecta:latest
```

**AWS ECR (exemplo):**

```bash
aws ecr get-login-password --region sa-east-1 | docker login --username AWS --password-stdin ID_DA_CONTA.dkr.ecr.sa-east-1.amazonaws.com
docker tag gs2-next-connecta:latest ID_DA_CONTA.dkr.ecr.sa-east-1.amazonaws.com/gs2-next-connecta:latest
docker push ID_DA_CONTA.dkr.ecr.sa-east-1.amazonaws.com/gs2-next-connecta:latest
```

Use a mesma tag (`latest` ou uma versão, ex.: `v1.0.0`) no seu ambiente de produção.

## 4. Deploy em produção

- No servidor/ Kubernetes/ ECS etc., use a imagem publicada (ex.: `SEU_USUARIO/gs2-next-connecta:latest`).
- Garanta que o mesmo `.env` (ou variáveis de ambiente) de produção esteja configurado.
- Rode **um processo** com `bundle exec rails s -b 0.0.0.0 -p 3000` e **outro** com `bundle exec sidekiq -C config/sidekiq.yml`.
- Após o primeiro deploy, execute no container ou em um job one-off:
  - `bundle exec rails db:create db:migrate` (se o banco for novo)
  - `bundle exec rake branding:sync_config` (para aplicar logos/nome no banco)

## 5. Dicas

- **SECRET_KEY_BASE:** nunca use o mesmo em dev e prod; gere um novo para produção.
- **Logos/config:** após trocar arquivos em `public/brand-assets` ou alterar `config/installation_config.yml`, rode `rake branding:sync_config` e reinicie a app (e limpe cache Redis se usar).
- **.dockerignore:** o projeto já tem `.dockerignore`; evita copiar `node_modules`, `log`, `.env`, etc. para a imagem.
- Se o build falhar por memória, tente aumentar memória do Docker ou rodar em uma máquina com mais RAM (o assets:precompile consome bastante).
