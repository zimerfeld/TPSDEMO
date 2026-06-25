extends Node
## Global error handler: shows a popup with the error message and Retry / Close buttons.
## Usage: CrashHandler.show_error("mensagem", optional_retry_callable)

func show_error(message: String, retry_callback: Callable = Callable()) -> void:
	if not is_inside_tree():
		push_error("CrashHandler.show_error() called before entering tree: " + message)
		return

	# Mesmo visual padrão das demais janelas (FloatingWindow: tema do jogo, × padrão, modal). COM retry
	# = confirmação (Tentar Novamente / Fechar Jogo); SEM retry = aviso de um botão (Fechar Jogo). Em
	# ambos, fechar pelo × ou ESC encerra o jogo (não dá para seguir num estado quebrado).
	var root := get_tree().root
	if retry_callback.is_valid():
		var dlg := FloatingDialog.confirm(root, "Erro / Error", message, "Tentar Novamente", "Fechar Jogo")
		dlg.confirmed.connect(func(): retry_callback.call())
		dlg.canceled.connect(func(): get_tree().quit())
	else:
		var dlg := FloatingDialog.alert(root, "Erro / Error", message, "Fechar Jogo")
		dlg.confirmed.connect(func(): get_tree().quit())
		dlg.canceled.connect(func(): get_tree().quit())
