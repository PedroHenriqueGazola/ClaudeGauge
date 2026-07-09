## Novidades

- 🐧 **Binário do Linux pronto pra baixar:** agora tem o `claudegauge-linux-x86_64.tar.gz` aqui no release — não precisa mais compilar da fonte. O binário traz a stdlib do Swift embutida (só precisa das libs de sistema). Instalação: baixe, `tar -xzf`, `./install.sh`.
- 📖 README novo, cobrindo tudo: abas **Uso** / **Gastos**, sessões do Claude Code, notificações e o suporte a Linux.

Continua tudo do v0.4.0: **suporte a Linux** (app de bandeja), **Gastos** por modelo e projeto (macOS com filtro 24h/7d/30d; Linux com janela de 7 dias na bandeja), e as abas **Uso** / **Gastos** no macOS.

## Instalar (macOS)

1. Baixe o `ClaudeGauge.zip` abaixo, descompacte e mova **ClaudeGauge.app** para `/Aplicativos`.
2. Primeira abertura: **botão direito no app → Abrir** (ou *Ajustes → Privacidade e Segurança → Abrir Assim Mesmo*). O app não é notarizado (projeto gratuito).
3. Se aparecer "nenhuma conta conectada", abra o popover → **Entrar com Claude / Configurações** → seção **Conta** → **Entrar com Claude** → autorize no navegador e cole o código.

Para receber as notificações, autorize o ClaudeGauge em *Ajustes do Sistema → Notificações* (o app também pede na primeira execução).

Requer macOS 14+ e uma conta Claude (Pro / Max / Team).

## Instalar (Linux)

```bash
sudo apt-get install libayatana-appindicator3-dev libnotify-dev
tar -xzf claudegauge-linux-x86_64.tar.gz
cd claudegauge-linux-x86_64
./install.sh
claudegauge
```

Login próprio (opcional, sem Claude Code): `claudegauge login`. **GNOME puro** precisa da extensão [AppIndicator Support](https://extensions.gnome.org/extension/615/appindicator-support/); KDE/XFCE/Cinnamon funcionam de fábrica.
