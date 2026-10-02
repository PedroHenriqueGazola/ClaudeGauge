## Novidades

- 🛠️ **Correção:** a notificação "precisa de você" não rouba mais o foco da janela em que você está — o ClaudeGauge recebe o aviso em segundo plano.

Quem usa o aviso "precisa de você" só precisa trocar o app; o hook se ajusta sozinho ao abrir.

## Instalar (macOS)

1. Baixe o `ClaudeGauge.zip` abaixo, descompacte e mova **ClaudeGauge.app** para `/Aplicativos`.
2. Primeira abertura: **botão direito no app → Abrir** (ou *Ajustes → Privacidade e Segurança → Abrir Assim Mesmo*). O app não é notarizado (projeto gratuito).
3. Se aparecer "nenhuma conta conectada", abra o popover → **Configurações → Conta → Entrar com Claude** → autorize no navegador e cole o código. Pra uma segunda org, use **Adicionar outra conta**.

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
