extends Node
## Global error handler: mostra um popup com a mensagem de erro. É NÃO-DESTRUTIVO — fechar (× / ESC /
## botão "Voltar") apenas FECHA a janela e devolve o foco à cena que a chamou; NUNCA encerra o jogo (um
## erro de porta/conexão/validação é recuperável — o jogador ajusta e tenta de novo). Com retry_callback,
## adiciona "Tentar Novamente" que re-executa a ação; sem ele, é um aviso de um botão só.
## Usage: CrashHandler.show_error("mensagem", optional_retry_callable)

func show_error(message: String, retry_callback: Callable = Callable()) -> void:
	if not is_inside_tree():
		push_error("CrashHandler.show_error() called before entering tree: " + message)
		return

	# Mesmo visual padrão das demais janelas (FloatingWindow: tema do jogo, × padrão, modal). O
	# FloatingWindow já fecha e restaura o foco anterior no × / ESC / botão — então basta NÃO ligar
	# nenhuma ação de saída: "Voltar" (e ×/ESC) só dispensam a janela. COM retry, o botão OK
	# ("Tentar Novamente") re-executa a ação e fecha; SEM retry, é um aviso de um botão ("Voltar").
	var root := get_tree().root
	if retry_callback.is_valid():
		var dlg := FloatingDialog.confirm(root, "Erro / Error", message, "Tentar Novamente", "Voltar")
		dlg.confirmed.connect(func() -> void: retry_callback.call())
	else:
		FloatingDialog.alert(root, "Erro / Error", message, "Voltar")
