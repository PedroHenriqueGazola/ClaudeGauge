## Novidades

- 👥 **Várias contas / organizações:** conecte mais de uma conta Claude (ex.: duas orgs no mesmo e-mail). A aba **Uso** mostra as duas empilhadas — cada org com seus limites de 5h e semanal — e um toque escolhe qual vai pra **barra de menu**. Adicione/troque/remova em *Configurações → Conta*.
- 🔑 **Clareza de login:** quando a sessão expira ou não há conta conectada, o app agora mostra um **banner de reconexão** claro (em vez de dados velhos com "desatualizado").
- 🛠️ **Correção:** o macOS não repede mais a senha do Keychain a cada atualização (o token é gravado preservando a permissão).

No Linux, a bandeja segue a conta ativa.

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
