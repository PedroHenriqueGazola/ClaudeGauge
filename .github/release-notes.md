## Novidades

- 🐧 **Suporte a Linux!** O ClaudeGauge agora roda como ícone de bandeja no Linux (GTK + Ayatana AppIndicator): os mesmos limites de uso, notificações de threshold, login OAuth próprio (`claudegauge login`), abrir-no-login e o submenu de **Gastos**. Obrigado ao [@CloudyWSA](https://github.com/CloudyWSA) pelo port (#3).
- 💸 **Gastos no Linux:** o submenu "Gastos" mostra o custo estimado dos últimos 7 dias por modelo e por projeto, direto na bandeja.
- 🧱 Por dentro: a lógica portável (auth, API, uso, gastos) virou um módulo `ClaudeGaugeCore` compartilhado entre macOS e Linux.

No macOS nada muda em relação ao v0.3.0 (aba **Uso** + aba **Gastos** com filtro de período 24h/7d/30d).

## Instalar (macOS)

1. Baixe o `ClaudeGauge.zip` abaixo, descompacte e mova **ClaudeGauge.app** para `/Aplicativos`.
2. Primeira abertura: **botão direito no app → Abrir** (ou *Ajustes → Privacidade e Segurança → Abrir Assim Mesmo*). O app não é notarizado (projeto gratuito).
3. Se aparecer "nenhuma conta conectada", abra o popover → **Entrar com Claude / Configurações** → seção **Conta** → **Entrar com Claude** → autorize no navegador e cole o código.

Para receber as notificações, autorize o ClaudeGauge em *Ajustes do Sistema → Notificações* (o app também pede na primeira execução).

Requer macOS 14+ e uma conta Claude (Pro / Max / Team).

## Instalar (Linux)

O binário do Linux é compilado da fonte (precisa de Swift 5.9+ e das libs de sistema):

```bash
sudo apt-get install libayatana-appindicator3-dev libnotify-dev
git clone https://github.com/PedroHenriqueGazola/ClaudeGauge.git
cd ClaudeGauge
./scripts/install-linux.sh
claudegauge
```

Login próprio (opcional, pra quem não usa o Claude Code): `claudegauge login`. **GNOME puro** precisa da extensão [AppIndicator Support](https://extensions.gnome.org/extension/615/appindicator-support/); KDE/XFCE/Cinnamon funcionam de fábrica.
