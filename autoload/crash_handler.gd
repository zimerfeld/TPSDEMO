extends Node
## Global error handler: shows a popup with the error message and Retry / Close buttons.
## Usage: CrashHandler.show_error("mensagem", optional_retry_callable)

func show_error(message: String, retry_callback: Callable = Callable()) -> void:
	if not is_inside_tree():
		push_error("CrashHandler.show_error() called before entering tree: " + message)
		return

	var dlg := ConfirmationDialog.new()
	dlg.title = "Erro / Error"
	dlg.dialog_text = message
	dlg.min_size = Vector2i(520, 180)

	if retry_callback.is_valid():
		dlg.get_ok_button().text = "Tentar Novamente"
		dlg.get_cancel_button().text = "Fechar Jogo"
		dlg.confirmed.connect(func():
			dlg.queue_free()
			retry_callback.call()
		)
		dlg.canceled.connect(func(): get_tree().quit())
	else:
		dlg.get_ok_button().text = "Fechar Jogo"
		dlg.get_cancel_button().hide()
		dlg.confirmed.connect(func(): get_tree().quit())

	get_tree().root.add_child(dlg)
	dlg.popup_centered()
