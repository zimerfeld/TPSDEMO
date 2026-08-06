# dual-window.ps1 - abre DUAS instancias do ZIMARO lado a lado (metade da tela cada):
#   - janela da ESQUERDA: sobe como SERVIDOR e hospeda uma sala (autohost)
#   - janela da DIREITA : espera o servidor subir e ENTRA na sala em execucao (autojoin)
#
# A resolucao e detectada da area UTIL do monitor (desconta a barra de tarefas) e dividida ao meio.
# O fluxo dentro do jogo e conduzido pelo autoload Autopilot (autoload/autopilot.gd), que le os
# argumentos de usuario da linha de comando (tudo que vem depois de `--`).
#
# Uso (PowerShell):
#   pwsh -File scripts/dual-window.ps1
#   pwsh -File scripts/dual-window.ps1 -Port 4383 -Level 2 -Delay 8
#   pwsh -File scripts/dual-window.ps1 -Level 2 -Template aerea   # sala com o aliado bot (escolta)
#   pwsh -File scripts/dual-window.ps1 -Editor       # roda pelo binario do Godot (sem .exe exportado)
#   pwsh -File scripts/dual-window.ps1 -Monitor 1    # usa o 2o monitor (indice base 0)
#   pwsh -File scripts/dual-window.ps1 -Preview 0    # sem a pausa de conferencia (sobe direto)

param(
	[int]$Port = 4383,
	[string]$Address = "127.0.0.1",
	[string]$Level = "1",
	# Template de personagens ativado na sala: id exato ou um trecho do nome (sem acento/espaco e
	# mais simples de passar). "none" limpa. Vazio = mantem o que ja estiver ativo no level.
	[string]$Template = "",
	[double]$Delay = 6,
	[int]$Retries = 15,
	[int]$Monitor = 0,
	[string]$Exe = "",
	# Segundos de pausa (com contagem regressiva) entre imprimir os parametros e lancar as janelas -
	# tempo para conferir a geometria e as linhas de comando antes de a tela ser tomada pelo jogo.
	[int]$Preview = 6,
	[switch]$Editor,
	[switch]$NoKill
)

$ErrorActionPreference = "Stop"
$proj = Split-Path -Parent $PSScriptRoot

# ---------------------------------------------------------------- geometria da tela
# Torna o processo DPI-aware ANTES de ler a area util: sem isso, em telas com escala (125%/150%) o
# Windows devolve coordenadas virtuais e as janelas nasceriam menores que a metade real da tela.
Add-Type -Namespace Zimaro -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -ErrorAction SilentlyContinue
try { [Zimaro.Dpi]::SetProcessDPIAware() | Out-Null } catch {}
Add-Type -AssemblyName System.Windows.Forms

$screens = [System.Windows.Forms.Screen]::AllScreens
if ($Monitor -lt 0 -or $Monitor -ge $screens.Count) {
	Write-Host "Monitor $Monitor nao existe (ha $($screens.Count)). Usando o primario."
	$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
} else {
	$area = $screens[$Monitor].WorkingArea
}

$halfW = [int][math]::Floor($area.Width / 2)
$leftRect = "{0},{1},{2},{3}" -f $area.X, $area.Y, $halfW, $area.Height
$rightRect = "{0},{1},{2},{3}" -f ($area.X + $halfW), $area.Y, ($area.Width - $halfW), $area.Height
$screenName = if ($Monitor -lt 0 -or $Monitor -ge $screens.Count) { "primario" } else { "indice $Monitor" }

# ---------------------------------------------------------------- executavel a lancar
# Preferencia: o .exe exportado (build/windows/ZIMARO.exe). Sem ele (ou com -Editor), roda o projeto
# pelo binario do Godot com --path, que nao exige export.
$godotArgs = @()
if ($Exe -ne "") {
	$target = $Exe
} elseif (-not $Editor -and (Test-Path (Join-Path $proj "build\windows\ZIMARO.exe"))) {
	$target = Join-Path $proj "build\windows\ZIMARO.exe"
} else {
	$target = "C:\GODOT\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64.exe"
	if (-not (Test-Path $target)) {
		$found = Get-ChildItem "C:\GODOT", "C:\Godot" -Recurse -Filter "Godot_v4.6.2*win64.exe" -ErrorAction SilentlyContinue |
			Where-Object { $_.Name -notlike "*console*" } | Select-Object -First 1
		if ($found) { $target = $found.FullName } else { throw "Nem o .exe exportado nem o Godot 4.6.2 foram encontrados." }
	}
	$godotArgs = @("--path", $proj)
}

# ---------------------------------------------------------------- conferencia dos parametros
# Monta as duas linhas de comando ANTES de qualquer coisa e imprime tudo, com uma pausa de
# conferencia (-Preview segundos): assim da tempo de ler a geometria e os argumentos antes de as
# duas janelas tomarem a tela. -Preview 0 pula a pausa.
$hostArgs = $godotArgs + @("--", "autohost", "port=$Port", "level=$Level", "win=$leftRect", "player=HOST")
if ($Template -ne "") { $hostArgs += "template=$Template" }   # so o host cria a sala
$joinArgs = $godotArgs + @("--", "autojoin", "port=$Port", "address=$Address", "delay=$Delay",
	"retries=$Retries", "win=$rightRect", "player=CLIENTE")

Write-Host ""
Write-Host "======================= ZIMARO - DUAS JANELAS LADO A LADO ======================="
Write-Host ("Monitor ($screenName)".PadRight(27) + ": area util $($area.Width)x$($area.Height) em ($($area.X),$($area.Y))")
Write-Host "Executavel                 : $target"
Write-Host "Porta / Endereco           : $Port / $Address"
Write-Host "Level da sala              : $Level"
Write-Host "Template de personagens    : $(if ($Template -ne '') { $Template } else { '(mantem o ativo)' })"
Write-Host "Espera do cliente          : $Delay s + ate $Retries tentativas de 2 em 2 s"
Write-Host "Geometria (x,y,largura,altura)"
Write-Host "  SERVIDOR (esquerda)      : $leftRect"
Write-Host "  CLIENTE  (direita)       : $rightRect"
Write-Host "Linhas de comando"
Write-Host "  $(Split-Path -Leaf $target) $($hostArgs -join ' ')"
Write-Host "  $(Split-Path -Leaf $target) $($joinArgs -join ' ')"
Write-Host "================================================================================"

if ($Preview -gt 0) {
	for ($s = $Preview; $s -gt 0; $s--) {
		Write-Host -NoNewline "`rLancando em $s s...  (Ctrl+C cancela) "
		Start-Sleep -Seconds 1
	}
	Write-Host "`r                                          "
}

# ---------------------------------------------------------------- instancias antigas
# Duas instancias competem pela MESMA porta: uma sobra de execucao anterior faria o autohost falhar
# com "porta em uso". Encerra so os processos do MESMO executavel (nao toca em nada mais).
if (-not $NoKill) {
	Get-Process -ErrorAction SilentlyContinue | Where-Object {
		try { $_.Path -eq $target } catch { $false }
	} | ForEach-Object {
		Write-Host "Encerrando instancia anterior (PID $($_.Id))..."
		try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {}
	}
	Start-Sleep -Milliseconds 600
}

# ---------------------------------------------------------------- lancamento
Write-Host "Subindo o SERVIDOR (hospeda uma sala no Level $Level, porta $Port)..."
$hostProc = Start-Process -FilePath $target -ArgumentList $hostArgs -PassThru
Write-Host "  PID $($hostProc.Id)"

Write-Host "Subindo o CLIENTE (conecta em ${Address}:$Port apos $Delay s, com ate $Retries tentativas)..."
$joinProc = Start-Process -FilePath $target -ArgumentList $joinArgs -PassThru
Write-Host "  PID $($joinProc.Id)"

Write-Host ""
Write-Host "Pronto. A janela da esquerda hospeda a sala; a da direita entra nela sozinha."
Write-Host "Para encerrar as duas: Stop-Process -Id $($hostProc.Id),$($joinProc.Id)"
