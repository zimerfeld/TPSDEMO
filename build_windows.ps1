# build_windows.ps1 — exporta o ZIMARO para um .exe Windows (PCK embutido) e
# (re)cria o atalho com ícone no Desktop. Uso:
#   pwsh -File build_windows.ps1            # builda só se algo mudou desde o último .exe
#   pwsh -File build_windows.ps1 -Force     # builda sempre
#
# O modo "skip se nada mudou" deixa este script barato como hook de Stop (ver
# .claude/settings.json): em turnos sem mudança de arquivo, ele sai na hora.
#
# Pré-requisitos: Godot 4.6.2 + export templates 4.6.2 instalados. O ícone (build/icon.ico)
# é gerado só na 1ª vez (rasteriza icon.svg via Godot headless + Pillow); depois é reusado.

param([switch]$Force)

$ErrorActionPreference = "Stop"
$proj = $PSScriptRoot
$exeOut = Join-Path $proj "build\windows\ZIMARO.exe"
$ico = Join-Path $proj "build\icon.ico"

# (Re)cria o atalho ZIMARO.lnk no Desktop apontando para o .exe, com o ícone se existir.
function Set-ZimaroShortcut {
	param([string]$exe, [string]$icoPath)
	$desktop = [Environment]::GetFolderPath("Desktop")
	$lnk = Join-Path $desktop "ZIMARO.lnk"
	$ws = New-Object -ComObject WScript.Shell
	$sc = $ws.CreateShortcut($lnk)
	$sc.TargetPath = $exe
	$sc.WorkingDirectory = Split-Path $exe
	if (Test-Path $icoPath) { $sc.IconLocation = "$icoPath,0" }
	$sc.Description = "ZIMARO"
	$sc.Save()
	return $lnk
}

# Data de modificação mais recente entre os ARQUIVOS-FONTE do projeto (ignora caches e o que
# não entra no .exe: .godot/, build/, .git/, OBSIDIAN/, e os próprios .md/.ps1 de tooling).
function Get-NewestSourceTime {
	param([string]$root)
	$exclude = @('.godot', 'build', '.git', '.claude', 'OBSIDIAN')
	$newest = $null
	Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
		$rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
		$top = ($rel -split '[\\/]', 2)[0]
		if ($exclude -contains $top) { return }
		if ($_.Extension -in '.md', '.ps1') { return }
		if ($_.Name -in '.gitignore', '.gitattributes') { return }
		if ($null -eq $newest -or $_.LastWriteTime -gt $newest) { $newest = $_.LastWriteTime }
	}
	return $newest
}

# Encerra qualquer instância JÁ RODANDO do .exe que vamos sobrescrever (a janela aberta trava o
# arquivo e o export falha com "Failed to rename temporary file ... ZIMARO.tmp"). Casa pelo CAMINHO
# do executável (não só pelo nome), então não toca em processos não relacionados. Também remove um
# .tmp órfão de um export anterior interrompido, que dá o mesmo erro de rename.
function Stop-RunningZimaro {
	param([string]$exe)
	$killed = $false
	Get-Process -ErrorAction SilentlyContinue | Where-Object {
		try { $_.Path -eq $exe } catch { $false }
	} | ForEach-Object {
		Write-Host "Encerrando instância em execução do ZIMARO (PID $($_.Id))..."
		try { Stop-Process -Id $_.Id -Force -ErrorAction Stop; $killed = $true } catch {}
	}
	# Dá um tempo para o Windows liberar o lock do arquivo antes de exportar.
	if ($killed) { Start-Sleep -Milliseconds 800 }
	$tmp = [System.IO.Path]::ChangeExtension($exe, ".tmp")
	if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

# Localiza o executável do Godot 4.6.2 (caminho padrão; cai para busca se mudar).
$godot = "C:\GODOT\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
if (-not (Test-Path $godot)) {
	$found = Get-ChildItem "C:\GODOT", "C:\Godot" -Recurse -Filter "Godot_v4.6.2*win64.exe" -ErrorAction SilentlyContinue |
		Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
	if ($found) { $godot = $found.FullName } else { throw "Godot 4.6.2 não encontrado." }
}

New-Item -ItemType Directory -Force (Join-Path $proj "build\windows") | Out-Null

# 0) Skip se o .exe já está mais novo que todos os fontes (a não ser com -Force).
if (-not $Force -and (Test-Path $exeOut)) {
	$newest = Get-NewestSourceTime $proj
	$exeTime = (Get-Item $exeOut).LastWriteTime
	if ($newest -and $exeTime -ge $newest) {
		Write-Host "Sem mudanças desde o último build ($($exeTime.ToString('HH:mm:ss'))) — pulando. Use -Force para forçar."
		Set-ZimaroShortcut $exeOut $ico | Out-Null
		exit 0
	}
}

# 1) Ícone .ico (só se faltar). Rasteriza icon.svg via Godot headless e converte com Pillow.
if (-not (Test-Path $ico)) {
	Write-Host "Gerando build/icon.ico..."
	$render = Join-Path $proj "_render_icon_tmp.gd"
	@'
extends SceneTree
func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	var tex := load("res://icon.svg") as Texture2D
	var img := tex.get_image()
	if img.is_compressed(): img.decompress()
	img.save_png("res://build/icon_256.png")
	quit(0)
'@ | Set-Content -Encoding UTF8 $render
	& $godot --headless --path $proj --script "res://_render_icon_tmp.gd"
	Remove-Item $render -Force
	$png = Join-Path $proj "build\icon_256.png"
	py -3 -c "from PIL import Image; Image.open(r'$png').convert('RGBA').save(r'$ico', format='ICO', sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])"
}

# 2) Exporta o .exe (release, PCK embutido). Antes, encerra a instância aberta (se houver) para
# não travar o arquivo de saída.
Stop-RunningZimaro $exeOut
Write-Host "Exportando $exeOut ..."
& $godot --headless --path $proj --export-release "Windows Desktop" $exeOut
if (-not (Test-Path $exeOut)) { throw "Export falhou: $exeOut não foi criado." }

# 3) (Re)cria o atalho no Desktop com o ícone.
$lnk = Set-ZimaroShortcut $exeOut $ico

$mb = [math]::Round((Get-Item $exeOut).Length / 1MB, 1)
Write-Host "OK — $exeOut ($mb MB) e atalho em $lnk"
