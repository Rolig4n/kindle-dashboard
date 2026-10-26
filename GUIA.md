# Kindle Dashboard — Guia de Implementação

Dashboard local para Kindle 8ª geração (e-ink, 800×600 px), rodando como container Docker em Ubuntu Server. Atualiza a cada 5 minutos durante o horário comercial (08h–17h); fora desse período exibe um slideshow de imagens.

---

## Sumário

1. [Visão geral da arquitetura](#1-visão-geral-da-arquitetura)
2. [Pré-requisitos no servidor](#2-pré-requisitos-no-servidor)
3. [Obtendo a chave da OpenWeatherMap](#3-obtendo-a-chave-da-openweathermap)
4. [Clonando e configurando o projeto](#4-clonando-e-configurando-o-projeto)
5. [Subindo o container Docker](#5-subindo-o-container-docker)
6. [Configurando o Kindle (KOReader)](#6-configurando-o-kindle-koreader)
7. [Variáveis de ambiente — referência completa](#7-variáveis-de-ambiente--referência-completa)
8. [Integrando o clima da casa](#8-integrando-o-clima-da-casa)
9. [Personalização de feeds RSS](#9-personalização-de-feeds-rss)
10. [Galeria de imagens](#10-galeria-de-imagens)
11. [Manutenção e comandos úteis](#11-manutenção-e-comandos-úteis)
12. [Solução de problemas](#12-solução-de-problemas)

---

## 1. Visão geral da arquitetura

```
Kindle (KOReader / navegador interno)
        │  HTTP  (rede Wi-Fi local)
        ▼
Ubuntu Server — porta 3000
        │
  [Docker: kindle-dashboard]
        ├── GET /api/weather        → OpenWeatherMap API
        ├── GET /api/home-climate   → container de sensores (opcional)
        ├── GET /api/containers     → /var/run/docker.sock (host)
        ├── GET /api/news           → feeds RSS (G1, UOL…)
        └── GET /api/gallery        → lista de URLs de imagens (.env)
```

O container **não precisa de banco de dados**. Todo o estado é efêmero; o frontend em HTML puro faz as requisições diretamente para o backend a cada 5 minutos.

---

## 2. Pré-requisitos no servidor

```bash
# Verificar se Docker está instalado
docker --version

# Verificar se Docker Compose está instalado
docker compose version

# Se não estiver instalado, instalar Docker + Compose:
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
```

> Após `usermod`, feche e reabra o terminal para o grupo ter efeito.

---

## 3. Obtendo a chave da OpenWeatherMap

1. Acesse [https://openweathermap.org/api](https://openweathermap.org/api)
2. Crie uma conta gratuita
3. Vá em **API keys** no painel do usuário
4. Copie a chave gerada (pode demorar até 10 minutos para ativar)
5. O plano gratuito permite **60 chamadas/minuto** — mais que suficiente

---

## 4. Clonando e configurando o projeto

### 4.1 Copiar os arquivos para o servidor

Se você ainda não tem Git configurado, transfira a pasta do projeto via `scp` ou `rsync`:

```bash
# Do seu computador local para o servidor:
scp -r kindle-dashboard/ usuario@IP_DO_SERVIDOR:/home/usuario/
```

Ou, se tiver Git:

```bash
git clone <url-do-repositório> ~/kindle-dashboard
cd ~/kindle-dashboard
```

### 4.2 Criar o arquivo `.env`

```bash
cd ~/kindle-dashboard
cp .env.example .env
nano .env
```

Preencha os campos obrigatórios:

```env
OWM_API_KEY=SUA_CHAVE_AQUI      # chave da OpenWeatherMap
OWM_CITY=Sua Cidade,BR          # ex: "Campinas,BR" ou "São Paulo,BR"
```

Salve com `Ctrl+O`, saia com `Ctrl+X`.

---

## 5. Subindo o container Docker

```bash
cd ~/kindle-dashboard

# Build e subida em background
docker compose up -d --build

# Verificar se está rodando
docker compose ps

# Ver logs em tempo real
docker compose logs -f
```

### 5.1 Testar no próprio servidor

```bash
curl http://localhost:3000/api/health
# Resposta esperada: {"ok":true,"ts":"..."}

curl http://localhost:3000/api/weather
# Deve retornar JSON com temperatura, descrição etc.
```

### 5.2 Descobrir o IP do servidor na rede local

```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
# Exemplo de saída: inet 192.168.1.100/24
```

Anote esse IP. O dashboard estará acessível em:

```
http://192.168.1.100:3000
```

---

## 6. Configurando o Kindle (KOReader)

O Kindle precisa estar **com jailbreak** e com o **KOReader instalado** (o que você já tem).

### 6.1 Conectar o Kindle ao Wi-Fi da casa

No Kindle:
- Menu → **Configurações** → **Wi-Fi** → conecte à sua rede doméstica

### 6.2 Abrir o navegador do KOReader

O KOReader tem um navegador embutido. Para acessá-lo:

1. Abra o KOReader
2. Menu superior → ícone de engrenagem (Ferramentas) → **Navegador**
   - Em algumas versões: Menu → **More tools** → **Web browser**
3. Na barra de endereço, digite:
   ```
   http://192.168.1.100:3000
   ```
   (substitua pelo IP do seu servidor)

### 6.3 Fazer o Kindle abrir o dashboard automaticamente

Para que o dashboard abra sozinho quando o Kindle ligar (modo quiosque), você pode usar o plugin **KOReader Screensaver** ou configurar o navegador como página inicial:

1. No KOReader, vá em: Menu → **Configurações do navegador**
2. Defina a **Home page** / **Página inicial** como `http://192.168.1.100:3000`

### 6.4 Manter a tela sempre ligada

No Kindle:
- Menu → **Configurações** → **Exibição** → **Tempo limite da tela** → Defina para **Nunca** ou o maior valor disponível

No KOReader:
- Menu → **Energia** → desative o sleep automático enquanto o navegador estiver aberto

### 6.5 Modo tela cheia no KOReader

Para esconder as barras do navegador e usar os 800×600 px inteiros:

- Toque na barra de endereço → ícone de tela cheia (⛶), ou
- Menu → **Fullscreen** / **Tela cheia**

> **Dica:** O dashboard foi desenhado exatamente para 800×600 px (resolução do Kindle Paperwhite 8ª gen). Não é necessário zoom.

---

## 7. Variáveis de ambiente — referência completa

| Variável | Obrigatória | Padrão | Descrição |
|---|---|---|---|
| `PORT` | não | `3000` | Porta exposta pelo container |
| `TZ` | não | `America/Sao_Paulo` | Fuso horário do servidor |
| `OWM_API_KEY` | **sim** | — | Chave da OpenWeatherMap |
| `OWM_CITY` | não | `Sao Paulo,BR` | Cidade para o clima externo |
| `OWM_UNITS` | não | `metric` | `metric` (°C) ou `imperial` (°F) |
| `HOME_CLIMATE_URL` | não | vazio | URL do endpoint de clima interno |
| `RSS_FEEDS` | não | G1 + UOL | URLs de feeds RSS separadas por vírgula |
| `RSS_MAX_ITEMS` | não | `20` | Máximo de notícias no carrossel |
| `GALLERY_URLS` | não | vazio | URLs de imagens para o slideshow noturno |

---

## 8. Integrando o clima da casa

Quando você tiver o container de sensores configurado (temperatura e umidade interna), basta que ele exponha um endpoint HTTP com este formato de resposta:

```json
{
  "temperature": 23.5,
  "humidity": 61
}
```

Depois, adicione no `.env`:

```env
HOME_CLIMATE_URL=http://nome-do-container:PORTA/endpoint
```

E reinicie o dashboard:

```bash
docker compose restart kindle-dashboard
```

> Se o container de sensores estiver na mesma Docker network, use o nome do serviço como host. Se estiver em outra rede, use o IP local do servidor + porta.

---

## 9. Personalização de feeds RSS

Edite `RSS_FEEDS` no `.env` com feeds separados por vírgula:

```env
RSS_FEEDS=https://g1.globo.com/rss/g1/,https://feeds.feedburner.com/uolnoticias,https://www.tecmundo.com.br/rss
```

Feeds RSS brasileiros úteis:

| Portal | URL |
|---|---|
| G1 | `https://g1.globo.com/rss/g1/` |
| UOL Notícias | `https://feeds.feedburner.com/uolnoticias` |
| Tecmundo | `https://www.tecmundo.com.br/rss` |
| Folha de S.Paulo | `https://feeds.folha.uol.com.br/folha/brasil/rss091.xml` |
| Clima Tempo | `https://www.climatempo.com.br/rss/noticia/categoria/2/clima` |

---

## 10. Galeria de imagens

Fora do horário comercial (17h–8h), o dashboard exibe um slideshow das imagens definidas em `GALLERY_URLS`. As imagens são exibidas em filtro escala de cinza automaticamente pelo CSS.

```env
GALLERY_URLS=https://exemplo.com/foto1.jpg,https://exemplo.com/foto2.jpg
```

**Dicas para boas imagens no Kindle e-ink:**
- Prefira imagens em preto e branco ou com alto contraste
- Resolução próxima de 800×600 px (ou maior, pois o CSS ajusta)
- Evite imagens com muitos detalhes finos — o e-ink tem limitação de escala de cinza

---

## 11. Manutenção e comandos úteis

```bash
# Ver status dos containers
docker compose ps

# Ver logs do dashboard
docker compose logs -f kindle-dashboard

# Reiniciar após alterar o .env
docker compose restart kindle-dashboard

# Rebuild após alterar código
docker compose up -d --build

# Parar tudo
docker compose down

# Ver uso de recursos
docker stats kindle-dashboard
```

### Atualizar o projeto

```bash
cd ~/kindle-dashboard
# (copie os novos arquivos ou faça git pull)
docker compose up -d --build
```

---

## 12. Solução de problemas

### "Erro ao obter clima externo"
- Verifique se `OWM_API_KEY` está correto no `.env`
- Chaves novas da OpenWeatherMap levam até 10 min para ativar
- Teste: `curl "https://api.openweathermap.org/data/2.5/weather?q=SaoPaulo,BR&appid=SUA_CHAVE&units=metric"`

### "Erro ao listar containers"
- O socket do Docker deve estar montado corretamente
- Verifique: `docker compose ps` e confirme que o volume `/var/run/docker.sock` está mapeado
- O usuário que roda o Docker deve ter permissão no socket

### Kindle não acessa o dashboard
- Confirme que o Kindle e o servidor estão na mesma rede Wi-Fi
- Confirme o IP do servidor: `ip addr show`
- Teste no navegador do seu celular antes de tentar no Kindle
- Verifique o firewall do servidor: `sudo ufw status`
  - Se necessário: `sudo ufw allow 3000`

### Dashboard aparece com zoom incorreto no Kindle
- O KOReader pode aplicar zoom automático. Procure a opção "Zoom" no menu do navegador e defina como **100%** ou **Fit width**
- O `<meta name="viewport" content="width=800">` garante que o layout use exatamente 800 px

### Imagens da galeria não aparecem
- Confirme que as URLs estão acessíveis (abra no navegador do celular)
- Algumas URLs podem ter proteção contra hotlinking — nesse caso, hospede as imagens você mesmo

---

*Documentação gerada para o projeto kindle-dashboard v1.0*
