# Kindle Dashboard — Guia de Implementação

Dashboard local para Kindle 8ª geração (e-ink, 800×600 px), rodando como container Docker em Ubuntu Server. Atualiza a cada 5 minutos durante o horário (08h–22h); fora desse período exibe um slideshow de imagens.

---

## Sumário

1. [Visão geral da arquitetura](#1-visão-geral-da-arquitetura)
2. [Pré-requisitos no servidor](#2-pré-requisitos-no-servidor)
3. [Transferindo os arquivos do Windows para o servidor](#3-transferindo-os-arquivos-do-windows-para-o-servidor)
4. [Obtendo a chave da OpenWeatherMap](#4-obtendo-a-chave-da-openweathermap)
5. [Configurando o projeto no servidor](#5-configurando-o-projeto-no-servidor)
6. [Subindo o container Docker](#6-subindo-o-container-docker)
7. [Configurando o Kindle (KOReader)](#7-configurando-o-kindle-koreader)
8. [Variáveis de ambiente — referência completa](#8-variáveis-de-ambiente--referência-completa)
9. [Integrando o clima da casa](#9-integrando-o-clima-da-casa)
10. [Personalização de feeds RSS](#10-personalização-de-feeds-rss)
11. [Galeria de imagens](#11-galeria-de-imagens)
12. [Manutenção e comandos úteis](#12-manutenção-e-comandos-úteis)
13. [Solução de problemas](#13-solução-de-problemas)

---

## 1. Visão geral da arquitetura

```
Kindle (roda dashboard.sh via cron do KOReader)
        │  wget PNG  (rede Wi-Fi local)
        ▼
Ubuntu Server — porta 3000
        │
  [Docker: kindle-dashboard]
        ├── GET /screenshot         → Puppeteer tira print do dashboard (PNG 800×600)
        ├── GET /api/weather        → OpenWeatherMap API
        ├── GET /api/home-climate   → container de sensores (opcional)
        ├── GET /api/containers     → /var/run/docker.sock (host)
        ├── GET /api/news           → feeds RSS (G1, UOL…)
        └── GET /api/gallery        → lista de URLs de imagens (.env)

Kindle exibe o PNG com eips (framebuffer nativo do e-ink, sem abrir app)
```

O container gera o dashboard em HTML internamente, tira um screenshot com Puppeteer/Chromium e entrega um PNG pronto. O Kindle só precisa baixar e exibir — sem navegador, sem JavaScript rodando no dispositivo.

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

## 6. Configurando o Kindle

O Kindle exibe o dashboard como um **PNG estático** gerado pelo servidor. O script `dashboard.sh` roda no Kindle a cada 5 minutos, baixa o PNG e exibe com `eips` — a ferramenta nativa que escreve direto no framebuffer do e-ink, sem abrir nenhum app.

### 6.1 Pré-requisitos no Kindle

- Jailbreak instalado
- KOReader instalado
- Kindle conectado ao Wi-Fi da mesma rede do servidor
- SSH habilitado (veja como ativar abaixo)

### 6.2 Ativar SSH no Kindle via KOReader

O SSH no KOReader precisa ser iniciado manualmente antes de cada sessão:

1. Abra o KOReader
2. Menu (ícone de engrenagem) → **SSH Server** → **Start**
3. Anote o IP exibido na tela (ex: `192.168.1.50`)
4. A porta padrão é `22`, senha padrão é `mario`

> Para que o SSH suba automaticamente ao ligar o Kindle, vá em KOReader → SSH Server → **Start on boot**.

### 6.3 Conectar via SSH pelo PC

No PowerShell (Windows) ou terminal (Linux/Mac):

```bash
ssh root@IP_DO_KINDLE
# senha: mario
```

Se conectar, o terminal do Kindle abre. Pode prosseguir.

### 6.4 Transferir o script para o Kindle

O arquivo `kindle/dashboard.sh` está na pasta do projeto. Antes de enviar, edite o IP do servidor:

**No Windows (PowerShell):**
```powershell
# Edite o IP na linha SERVER_IP do arquivo dashboard.sh
notepad kindle\dashboard.sh
```

Altere esta linha:
```sh
SERVER_IP="192.168.1.100"   # << coloque o IP do seu Ubuntu Server
```

Depois envie via SCP:

```powershell
# Windows
scp kindle\dashboard.sh root@IP_DO_KINDLE:/mnt/us/dashboard/dashboard.sh
```

```bash
# Linux/Mac
scp kindle/dashboard.sh root@IP_DO_KINDLE:/mnt/us/dashboard/dashboard.sh
```

### 6.5 Dar permissão de execução ao script

No SSH do Kindle:

```sh
chmod +x /mnt/us/dashboard/dashboard.sh

# Teste manual — deve baixar o PNG e exibir na tela:
/mnt/us/dashboard/dashboard.sh
```

Se a tela mostrar o dashboard, está funcionando.

### 6.6 Configurar o cron no KOReader

O KOReader tem um agendador de tarefas embutido. Para configurar:

1. No KOReader: Menu → **Configurações** → **Device settings** → **Autostart**
   - Ou: Menu → **Tools** → **More tools** → **Scheduler** (depende da versão)
2. Adicione uma tarefa com o comando:
   ```
   /mnt/us/dashboard/dashboard.sh
   ```
3. Defina o intervalo: **5 minutos**

**Alternativa — cron nativo do Kindle:**

No SSH do Kindle, edite o crontab:

```sh
# Verificar se o cron está disponível
which crontab || which crond

# Editar
crontab -e
```

Adicione a linha:

```cron
*/5 * * * * /mnt/us/dashboard/dashboard.sh >> /mnt/us/dashboard/cron.log 2>&1
```

Salve e saia (`Ctrl+O`, `Enter`, `Ctrl+X` se for nano).

### 6.7 Manter a tela do Kindle sempre ligada

No Kindle (menu nativo):
- Configurações → **Exibição** → **Tempo limite da tela** → **Nunca**

No KOReader:
- Menu → **Energia** → desabilite o sleep automático

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

## 12. Manutenção e comandos úteis

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

# Testar geração do PNG manualmente
curl -o teste.png http://localhost:3000/screenshot
# Forçar novo screenshot (ignora cache)
curl -o teste.png "http://localhost:3000/screenshot?force=1"
```

---

## 13. Solução de problemas

### `/screenshot` retorna erro 500
- O Chromium pode não estar instalado corretamente na imagem
- Faça rebuild: `docker compose up -d --build`
- Veja os logs: `docker compose logs -f kindle-dashboard`
- Confirme que `CHROMIUM_PATH=/usr/bin/chromium-browser` está correto dentro do container:
  ```bash
  docker exec kindle-dashboard which chromium-browser
  ```

### `eips: command not found` no Kindle
- O `eips` é nativo de todo Kindle com jailbreak. Se não estiver disponível, verifique se o jailbreak foi aplicado corretamente
- Caminho alternativo: `/usr/sbin/eips`
  ```sh
  # Edite o dashboard.sh e substitua eips por:
  /usr/sbin/eips
  ```

### SSH recusado no Kindle
- O servidor SSH precisa ser iniciado manualmente no KOReader antes de cada sessão
- KOReader → SSH Server → **Start**
- Para subir automaticamente: KOReader → SSH Server → **Start on boot**

### wget falha no Kindle
- Confirme que o Kindle e o servidor estão na mesma rede Wi-Fi
- Teste no SSH do Kindle:
  ```sh
  wget -O /tmp/test.png http://IP_DO_SERVIDOR:3000/screenshot
  ```
- Verifique o firewall do servidor: `sudo ufw allow 3000`

### "Erro ao obter clima externo"
- Verifique se `OWM_API_KEY` está correto no `.env`
- Chaves novas da OpenWeatherMap levam até 10 min para ativar
- Teste direto: `curl "https://api.openweathermap.org/data/2.5/weather?q=SaoPaulo,BR&appid=SUA_CHAVE&units=metric"`

### "Erro ao listar containers"
- O socket do Docker deve estar montado corretamente
- Verifique: `docker compose ps` e confirme o volume `/var/run/docker.sock`

### Imagens da galeria não aparecem no PNG
- Confirme que as URLs estão acessíveis a partir do servidor (não só do seu PC)
- Teste: `curl -I URL_DA_IMAGEM` no servidor
- Algumas URLs têm proteção contra hotlinking — hospede as imagens localmente se necessário

### Ver o log do script no Kindle
```sh
# No SSH do Kindle:
cat /mnt/us/dashboard/dashboard.log
```

---

*Documentação gerada para o projeto kindle-dashboard v1.0*
